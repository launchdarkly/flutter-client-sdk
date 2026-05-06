import 'dart:async';
import 'dart:convert';

import 'package:launchdarkly_dart_common/launchdarkly_dart_common.dart';
import 'package:launchdarkly_event_source_client/launchdarkly_event_source_client.dart';

import 'flag_eval_mapper.dart';
import 'protocol_handler.dart';
import 'protocol_types.dart';
import 'source.dart';
import 'source_result.dart';

/// Long-lived streaming data source over SSE.
///
/// Wraps an [SSEClient] with FDv2 protocol semantics. Each named SSE
/// event is parsed as JSON, wrapped in an [FDv2Event], and fed to a
/// fresh [FDv2ProtocolHandler]. The first emitted [ProtocolAction]
/// per event is translated into an [FDv2SourceResult]:
///
/// - [ActionPayload] --> [ChangeSetResult] with `persist: true`.
/// - [ActionGoodbye] --> goodbye [StatusResult]; the SSE connection is
///   closed.
/// - [ActionServerError] / [ActionError] --> interrupted
///   [StatusResult]; the SSE client's built-in retry handles the
///   reconnect.
/// - [ActionNone] --> no emission (waiting for more events).
///
/// Legacy `ping` events are routed to the injected [PingHandler] (which
/// performs a one-shot poll) and the result is forwarded to the
/// stream. This is the streaming-to-polling bridge for older servers
/// that pre-date FDv2.
///
/// The `x-ld-fd-fallback` header on the initial connection's response
/// is detected and produces a terminal-error result with
/// `fdv1Fallback: true`. The connection is closed.
///
/// Lifecycle: a single-subscription stream. [results] starts the SSE
/// connection on subscribe; cancelling the subscription tears it down
/// without emitting a shutdown. [close] both stops the source and
/// emits a shutdown [StatusResult] before closing the stream. Both
/// paths funnel through a `Completer<void> _stoppedSignal` so async
/// callbacks short-circuit safely.
final class FDv2StreamingBase {
  final SSEClient _sseClient;
  final PingHandler _pingHandler;
  final DateTime Function() _now;
  final LDLogger _logger;

  late final StreamController<FDv2SourceResult> _controller;
  final Completer<void> _stoppedSignal = Completer<void>();
  StreamSubscription<Event>? _sseSubscription;
  FDv2ProtocolHandler? _handler;
  String? _environmentId;

  FDv2StreamingBase({
    required SSEClient sseClient,
    required PingHandler pingHandler,
    required LDLogger logger,
    DateTime Function()? now,
  })  : _sseClient = sseClient,
        _pingHandler = pingHandler,
        _logger = logger.subLogger('FDv2StreamingBase'),
        _now = now ?? DateTime.now {
    _controller = StreamController<FDv2SourceResult>(
      onListen: _onListen,
      onCancel: _onCancel,
    );
  }

  /// Single-subscription stream of results. The SSE connection is
  /// established lazily on the first [Stream.listen] call.
  Stream<FDv2SourceResult> get results => _controller.stream;

  /// Stops the source, emits a shutdown [StatusResult], and closes the
  /// stream. Idempotent.
  void close() {
    if (_stoppedSignal.isCompleted) return;
    _stoppedSignal.complete();
    _tearDownConnection();
    _controller
        .add(FDv2SourceResults.shutdown(message: 'Streaming source closed'));
    _controller.close();
  }

  void _onListen() {
    // Build the protocol handler fresh for each connection so a
    // partial transfer from a previous connection cannot bleed into
    // the new one.
    _handler = FDv2ProtocolHandler(
      objProcessors: {flagEvalKind: processFlagEval},
      logger: _logger,
    );
    _sseSubscription = _sseClient.stream.listen(
      _handleEvent,
      onError: _handleSseError,
    );
  }

  Future<void> _onCancel() async {
    if (_stoppedSignal.isCompleted) return;
    _stoppedSignal.complete();
    _tearDownConnection();
    // No shutdown emission -- the subscriber asked us to stop.
  }

  void _tearDownConnection() {
    _sseSubscription?.cancel();
    _sseSubscription = null;
    // Best-effort close. The SSE client may already be closed if it
    // emitted an error; that's fine -- the operation is documented as
    // safe in any state.
    _sseClient.close();
  }

  void _handleEvent(Event event) {
    if (_stoppedSignal.isCompleted) return;
    switch (event) {
      case OpenEvent open:
        _handleOpen(open);
      case MessageEvent message:
        _handleMessage(message);
    }
  }

  void _handleOpen(OpenEvent event) {
    final headers = event.headers;
    if (headers == null) return;

    final envId = headers['x-ld-envid'];
    if (envId != null) {
      _environmentId = envId;
    }

    final fallback = headers['x-ld-fd-fallback']?.toLowerCase() == 'true';
    if (fallback) {
      _emit(FDv2SourceResults.terminalError(
        message: 'Server requested FDv1 fallback',
        fdv1Fallback: true,
      ));
      // Server told us to fall back; don't keep the connection open.
      _tearDownConnection();
      _controller.close();
    }
  }

  Future<void> _handleMessage(MessageEvent event) async {
    if (event.type == 'ping') {
      // Legacy bridge: older servers may still send `ping` instead of
      // FDv2 events. Defer to the injected handler for a one-shot poll.
      await _handlePing();
      return;
    }

    final Map<String, dynamic> data;
    try {
      final decoded = jsonDecode(event.data);
      if (decoded is! Map<String, dynamic>) {
        _logger.warn('Ignoring SSE event with non-object data: '
            'event=${event.type}');
        _emit(FDv2SourceResults.interrupted(
            message: 'Streaming event payload was not a JSON object'));
        return;
      }
      data = decoded;
    } catch (err) {
      _logger
          .warn('Failed to parse SSE event data as JSON (${err.runtimeType})');
      _emit(FDv2SourceResults.interrupted(
          message: 'Streaming event payload was not valid JSON'));
      return;
    }

    final action =
        _handler!.processEvent(FDv2Event(event: event.type, data: data));
    if (_stoppedSignal.isCompleted) return;

    switch (action) {
      case ActionPayload(:final payload):
        _emit(ChangeSetResult(
          payload: payload,
          environmentId: _environmentId,
          freshness: _now(),
          persist: true,
        ));
      case ActionGoodbye(:final reason):
        _emit(FDv2SourceResults.goodbyeResult(message: reason));
        // Server told us to disconnect; close instead of letting the
        // SSE client retry into a closed channel.
        _tearDownConnection();
        _controller.close();
      case ActionServerError(:final reason):
        _emit(FDv2SourceResults.interrupted(message: reason));
      case ActionError(:final message):
        _emit(FDv2SourceResults.interrupted(message: message));
      case ActionNone():
        // No emission; continue accumulating events until the handler
        // reaches a terminal action.
        break;
    }
  }

  Future<void> _handlePing() async {
    final FDv2SourceResult result;
    try {
      result = await _pingHandler();
    } catch (err) {
      _logger.warn('Ping handler threw unexpectedly: ${err.runtimeType}');
      _emit(FDv2SourceResults.interrupted(
          message: 'Ping handler raised error unexpectedly'));
      return;
    }
    if (_stoppedSignal.isCompleted) return;
    _emit(result);
  }

  void _handleSseError(Object err, StackTrace stack) {
    if (_stoppedSignal.isCompleted) return;
    // The SSE client's built-in backoff handles reconnection. Surface
    // the disruption as interrupted; the orchestrator decides whether
    // to fall through to a different source after enough time.
    _logger.warn('SSE error (${err.runtimeType}); will retry');
    _logger.debug('SSE error detail: $err\n$stack');
    _emit(FDv2SourceResults.interrupted(message: 'Streaming connection error'));
  }

  void _emit(FDv2SourceResult result) {
    if (_stoppedSignal.isCompleted) return;
    if (_controller.isClosed) return;
    _controller.add(result);
  }
}
