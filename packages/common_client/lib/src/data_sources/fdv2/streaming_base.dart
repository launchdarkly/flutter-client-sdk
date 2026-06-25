import 'dart:async';
import 'dart:convert';

import 'package:http/http.dart' as http;
import 'package:launchdarkly_dart_common/launchdarkly_dart_common.dart';
import 'package:launchdarkly_event_source_client/launchdarkly_event_source_client.dart';

import 'fallback_directive.dart';
import 'flag_eval_mapper.dart';
import 'payload.dart';
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
/// - [ActionPayload] --> translated into a [ChangeSet] and emitted as a
///   [ChangeSetResult] with `persist: true`. A payload whose flag-eval
///   objects cannot be parsed is surfaced as an interrupted
///   [StatusResult] instead, the same as any other transient data error.
/// - [ActionGoodbye] --> goodbye [StatusResult]; the SSE connection is
///   closed.
/// - [ActionServerError] / [ActionError] --> interrupted
///   [StatusResult]; the SSE client's built-in retry handles the
///   reconnect.
/// - [ActionNone] --> no emission (waiting for more events).
///
/// Legacy `ping` events are routed to the injected [PingHandler] (which
/// performs a one-shot poll) and the result is forwarded to the stream.
///
/// The FDv1 fallback directive is detected from three places: the
/// `x-ld-fd-fallback` header on a successful connection's response, the
/// same header on any error response ([SseHttpError], recoverable or not),
/// and a `goodbye` event's `protocolFallbackTTL` (the in-band signal for
/// transports that cannot read response headers). On a successful
/// connection the directive is emitted with the basis change set so the
/// payload is applied before the SDK falls back; otherwise it produces a
/// terminal-error result. Either way the result carries `fdv1Fallback:
/// true` and the fallback TTL.
///
/// Lifecycle: a single-subscription stream. [results] starts the SSE
/// connection on subscribe. [close] stops the source, emits a shutdown
/// [StatusResult], and closes the stream. Both paths funnel through a
/// `Completer<void> _stoppedSignal` so async callbacks short-circuit
/// safely.
///
/// `SSEClient.restart` is intentionally not surfaced here. The
/// orchestrator drives connection lifecycle by tearing down a
/// streaming source and constructing a fresh one, not by reconnecting
/// an existing one.
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
  bool _pingInFlight = false;
  bool _pingPending = false;

  /// Set when a successful connection's response carried the FDv1 fallback
  /// directive. The directive is emitted with the next change set, so the
  /// basis delivered alongside it is applied before the SDK falls back (a
  /// successful stream that says "fall back" still hands over its current
  /// data first). Cleared once emitted.
  FallbackDirective? _pendingDirective;

  FDv2StreamingBase({
    required SSEClient sseClient,
    required PingHandler pingHandler,
    required LDLogger logger,
    String? defaultEnvironmentId,
    DateTime Function()? now,
  })  : _sseClient = sseClient,
        _pingHandler = pingHandler,
        _environmentId = defaultEnvironmentId,
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
    _terminate(
        finalResult:
            FDv2SourceResults.shutdown(message: 'Streaming source closed'));
  }

  /// Terminal-path helper used by [close] and by the in-stream
  /// terminal paths (goodbye event, fdv1-fallback header). Completes
  /// [_stoppedSignal] *first* so any subsequent [close] call -- e.g.
  /// from inside an `onData` listener reacting to the [finalResult]
  /// we are about to emit -- short-circuits at its guard instead of
  /// racing into a closed controller. Idempotent.
  void _terminate({FDv2SourceResult? finalResult}) {
    if (_stoppedSignal.isCompleted) return;
    _stoppedSignal.complete();
    _tearDownConnection();
    if (!_controller.isClosed) {
      if (finalResult != null) {
        _controller.add(finalResult);
      }
      _controller.close();
    }
  }

  void _onListen() {
    _resetHandler();
    _sseSubscription = _sseClient.stream.listen(
      _handleEvent,
      onError: _handleSseError,
    );
  }

  /// Builds a fresh [FDv2ProtocolHandler]. Called on initial connect
  /// and on every subsequent [OpenEvent] (SSE auto-reconnect), so a
  /// partial transfer from the previous connection cannot bleed into
  /// the new one. Also called after a mid-event throw inside
  /// `processEvent` so any half-accumulated state is discarded.
  void _resetHandler() {
    _handler = FDv2ProtocolHandler(
      objProcessors: {flagEvalKind: processFlagEval},
      logger: _logger,
    );
  }

  Future<void> _onCancel() async {
    if (_stoppedSignal.isCompleted) return;
    _stoppedSignal.complete();
    _tearDownConnection();
    // No shutdown emission -- the subscriber asked us to stop. Close
    // the controller so its internal state is released; we keep no
    // subscribers and will never emit again.
    if (!_controller.isClosed) {
      _controller.close();
    }
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
        unawaited(_handleMessage(message));
    }
  }

  void _handleOpen(OpenEvent event) {
    // Every OpenEvent represents a (re)established connection. Rebuild
    // the protocol handler so a partial transfer from the prior
    // connection cannot bleed into this one -- the SDK must defend
    // against this regardless of whether the server respects the
    // protocol's "re-send server-intent on resume" semantic.
    _resetHandler();

    final headers = event.headers;
    if (headers == null) return;

    final envId = headers['x-ld-envid'];
    if (envId != null) {
      _environmentId = envId;
    }

    // A successful connection that directs fallback still delivers its
    // current basis first. Defer the directive so it is emitted with the
    // next change set: the payload is applied, then the SDK falls back.
    // Terminating here would drop the basis the server just sent.
    _pendingDirective = readFallbackDirective(headers);
  }

  Future<void> _handleMessage(MessageEvent event) async {
    if (event.type == 'ping') {
      // Legacy bridge: older servers may still send `ping` instead of
      // FDv2 events. Defer to the injected handler for a one-shot poll.
      await _handlePing();
      return;
    }

    // Capture freshness as close to message arrival as possible, before
    // any parse/dispatch work, so the timestamp reflects when the SDK
    // saw the update -- not when it finished processing it.
    final freshness = _now();

    final ProtocolAction action;
    try {
      final decoded = jsonDecode(event.data);
      if (decoded is! Map<String, dynamic>) {
        _logger.warn('Ignoring SSE event with non-object data: '
            'event=${event.type}');
        _emit(FDv2SourceResults.interrupted(
            message: 'Streaming event payload was not a JSON object'));
        return;
      }
      // Wrap the protocol-handler dispatch in the same try/catch as the
      // jsonDecode: the structural casts inside the per-event fromJson
      // factories (e.g. PayloadIntent, PutObjectEvent) throw TypeError
      // on shape mismatch and would otherwise become unhandled async
      // exceptions.
      action =
          _handler!.processEvent(FDv2Event(event: event.type, data: decoded));
    } catch (err) {
      _logger.warn('Failed to parse or process SSE event (${err.runtimeType})');
      // Reset the handler -- a mid-event throw can leave it with stale
      // _tempUpdates from the partially-processed payload.
      _resetHandler();
      _emit(FDv2SourceResults.interrupted(
          message: 'Streaming event payload was malformed'));
      return;
    }

    if (_stoppedSignal.isCompleted) return;

    switch (action) {
      case ActionPayload(:final payload):
        final ChangeSet changeSet;
        try {
          changeSet = translatePayload(payload);
        } catch (err) {
          // A protocol-valid payload whose flag-eval objects cannot be
          // parsed. Treat it like any other transient data error:
          // discard the partial state and surface interrupted, which
          // arms the orchestrator's fallback timer. The SSE connection
          // stays up and the server's next payload is processed by the
          // fresh handler.
          _logger.warn(
              'Streaming payload contained invalid flag data (${err.runtimeType})');
          _resetHandler();
          _emit(FDv2SourceResults.interrupted(
              message: 'Streaming payload contained invalid flag data'));
          return;
        }
        _emit(ChangeSetResult(
          changeSet: changeSet,
          environmentId: _environmentId,
          freshness: freshness,
          persist: true,
          // A directive seen on this connection's response is emitted with
          // the basis so it is applied before the orchestrator falls back.
          fdv1Fallback: _pendingDirective != null,
          fdv1FallbackTtl: _pendingDirective?.ttl,
        ));
        _pendingDirective = null;
      case ActionGoodbye(:final reason, :final protocolFallbackTtl):
        // Server told us to disconnect; route through the terminal
        // helper so a close() from the listener's onData -- a natural
        // reaction to a goodbye -- doesn't race with our own close.
        //
        // A goodbye can carry a fallback directive: in-band via its
        // protocol-fallback TTL, or from this connection's
        // x-ld-fd-fallback header (pending from open, if no payload has
        // consumed it yet). The orchestrator's goodbye path recycles
        // without consulting the directive, so surface it as a terminal
        // fallback result -- otherwise a header-only directive followed by
        // a goodbye would loop on reconnect instead of falling back.
        final hasDirective =
            protocolFallbackTtl != null || _pendingDirective != null;
        _terminate(
            finalResult: hasDirective
                ? FDv2SourceResults.terminalError(
                    message: 'Server requested FDv1 fallback (goodbye)',
                    fdv1Fallback: true,
                    fdv1FallbackTtl:
                        protocolFallbackTtl ?? _pendingDirective?.ttl,
                  )
                : FDv2SourceResults.goodbyeResult(message: reason));
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
    // The FDv2 ping semantic is "go re-poll". Two competing concerns:
    //
    // 1. Concurrent polls race on emit-order and amplify load on the
    //    polling endpoint, so only one poll may be in flight at a time.
    // 2. Simply dropping pings that arrive during an in-flight poll
    //    can leave the SDK on a stale snapshot: if server state changed
    //    between when the in-flight poll captured it and when the
    //    dropped ping arrived, no further poll fires and the change is
    //    never seen.
    //
    // Coalesce: pings that arrive while a poll is running set a
    // `_pingPending` flag. When the in-flight poll returns we drain the
    // flag with one more poll, capturing whatever the latest state is.
    // Multiple pings during the same in-flight window collapse to a
    // single follow-up.
    if (_pingInFlight) {
      _pingPending = true;
      return;
    }
    _pingInFlight = true;
    try {
      do {
        _pingPending = false;
        final FDv2SourceResult result;
        try {
          result = await _pingHandler();
        } catch (err) {
          _logger.warn('Ping handler threw unexpectedly: ${err.runtimeType}');
          if (_stoppedSignal.isCompleted) return;
          _emit(FDv2SourceResults.interrupted(
              message: 'Ping handler raised error unexpectedly'));
          return;
        }
        if (_stoppedSignal.isCompleted) return;
        _emit(result);
      } while (_pingPending && !_stoppedSignal.isCompleted);
    } finally {
      _pingInFlight = false;
    }
  }

  void _handleSseError(Object err, StackTrace stack) {
    if (_stoppedSignal.isCompleted) return;

    if (err is SseHttpError) {
      final message = 'Streaming request failed with status ${err.statusCode}';

      // A fallback directive on the response takes precedence over the
      // status: tear down this connection (which stops any retry the
      // client scheduled) and route to the fallback tier.
      if (readFallbackDirective(err.headers) case final directive?) {
        _logger.warn('$message; server requested FDv1 fallback');
        _terminate(
            finalResult: FDv2SourceResults.terminalError(
          message: message,
          statusCode: err.statusCode,
          fdv1Fallback: true,
          fdv1FallbackTtl: directive.ttl,
        ));
        return;
      }

      if (err.recoverable) {
        // The client retries on its own (and logs the error); surface the
        // disruption as interrupted and stay connected to it.
        _emit(FDv2SourceResults.interrupted(
            message: message, statusCode: err.statusCode));
        return;
      }

      // Not recoverable and no directive: the client has stopped, so this
      // source cannot recover. Surface a terminal error so the orchestrator
      // moves on.
      _logger.warn('$message; giving up');
      _terminate(
          finalResult: FDv2SourceResults.terminalError(
        message: message,
        statusCode: err.statusCode,
      ));
      return;
    }

    // A transport-level error (no HTTP status). The SSE client's built-in
    // backoff handles reconnection; surface the disruption as interrupted.
    //
    // Don't log the raw exception. http.ClientException's toString
    // formats as 'ClientException: <msg>, uri=<full-url>', and in GET
    // mode the URL embeds the base64-encoded context. Only the
    // category and a synthetic stack header go to the log.
    _logger.warn('SSE error (${err.runtimeType}); will retry');
    _logger.debug('SSE error stack:\n$stack');
    _emit(FDv2SourceResults.interrupted(message: _describeError(err)));
  }

  /// Categorizes an exception surfaced on the SSE stream into a fixed
  /// sanitized message. Mirrors the polling base's helper so neither
  /// surface (the public StatusResult.message nor the warn log) ever
  /// echoes a raw http.ClientException -- whose toString carries the
  /// full request URL.
  String _describeError(Object err) {
    if (err is TimeoutException) {
      return 'Streaming request timed out';
    }
    if (err is http.ClientException) {
      return 'Network error during streaming request';
    }
    final type = err.runtimeType.toString();
    if (type.contains('Tls') || type.contains('Handshake')) {
      return 'TLS error during streaming request';
    }
    return 'Streaming connection error';
  }

  void _emit(FDv2SourceResult result) {
    if (_stoppedSignal.isCompleted) return;
    if (_controller.isClosed) return;
    _controller.add(result);
  }
}
