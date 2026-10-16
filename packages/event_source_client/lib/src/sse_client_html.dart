import 'dart:async';
import 'dart:js_interop';
import 'package:web/web.dart' as web;
import 'dart:math' as math;

import '../launchdarkly_event_source_client.dart';

import 'backoff.dart';
import 'events.dart' as ld_message_event;

/// An [SSEClient] that uses the [web.EventSource] available on most browsers for web platform support.
///
/// The native `EventSource` API does not expose HTTP status codes or
/// response headers, so this implementation reports every failure as an
/// [SseTransportError]. With automatic reconnect on, every failure is
/// retried with backoff indefinitely. With automatic reconnect off, the
/// client closes the browser `EventSource` after the first failure and
/// does not reconnect.
class HtmlSseClient implements SSEClient {
  /// The underlying eventsource
  web.EventSource? _eventSource;

  /// This controller is for the events going to the subscribers of this client.
  late final StreamController<ld_message_event.Event> _messageEventsController;

  late final EventSourceLogger _logger;

  Backoff _backoff = Backoff(math.Random());

  final Uri _uri;
  final Uri Function()? _uriProvider;
  final Set<String> _eventTypes;
  final bool _autoReconnect;

  int? _activeSince;
  Timer? _retryTimer;

  /// Creates an instance of an SSEClient that will connect in the future.
  ///
  /// Every connection attempt -- the first connect and each reconnect --
  /// constructs a fresh `EventSource` from the [uriProvider] result when
  /// a provider is given. The fixed [uri] is used only when no provider
  /// is given.
  HtmlSseClient(Uri uri, Set<String> eventTypes, EventSourceLogger? logger,
      {Uri Function()? uriProvider, bool autoReconnect = true})
      : _uri = uri,
        _uriProvider = uriProvider,
        _eventTypes = eventTypes,
        _autoReconnect = autoReconnect {
    _logger = logger ?? NoOpLogger();
    _messageEventsController =
        StreamController<ld_message_event.Event>.broadcast(
      onListen: () {
        // this is triggered when first listener subscribes

        // Reset the backoff data whenever the client consumer
        // a new connection.
        _backoff = Backoff(math.Random());
        _setupConnection();
      },
      onCancel: () {
        // this is triggered when last listener unsubscribes
        _retryTimer?.cancel();
        _closeConnection();
      },
    );
  }

  void _closeConnection() {
    _eventSource?.close();
    _eventSource = null;
  }

  void _setupConnection() {
    final connectUri = _uriProvider?.call() ?? _uri;
    _eventSource = web.EventSource(connectUri.toString());

    for (var eventType in _eventTypes) {
      _eventSource?.addEventListener(eventType, _handleMessageEvent.toJS);
    }
    _eventSource?.addEventListener('error', _handleError.toJS);
    _eventSource?.addEventListener('open', _handleOpen.toJS);
  }

  void _handleError(web.Event event) {
    if (_messageEventsController.isClosed) {
      return;
    }
    // The browser event source errors are opaque, so every failure is a
    // transport failure.
    _messageEventsController.sink
        .addError(const SseTransportError('EventSource error'));
    if (!_autoReconnect) {
      // Close the browser EventSource so that it does not reconnect by
      // itself.
      _closeConnection();
      return;
    }
    _reconnect();
  }

  void _handleOpen(web.Event event) {
    // The browser event source doesn't have header support.
    _messageEventsController.sink.add(OpenEvent());
  }

  void _handleMessageEvent(web.Event event) {
    _activeSince = DateTime.now().millisecondsSinceEpoch;
    final messageEvent = event as web.MessageEvent;
    if (messageEvent.data != null && messageEvent.data.typeofEquals('string')) {
      final ldMessageEvent = ld_message_event.MessageEvent(messageEvent.type,
          (messageEvent.data as JSString).toDart, messageEvent.lastEventId);
      _messageEventsController.sink.add(ldMessageEvent);
    }
  }

  /// Subscribe to this [stream] to receive events and sometimes errors.  The first
  /// subscribe triggers the connection, so expect a network delay initially.
  @override
  Stream<ld_message_event.Event> get stream => _messageEventsController.stream;

  @override
  Future close() async {
    _logger.debug('Closing SSE client permanently.');
    _messageEventsController.close();
  }

  @override
  void restart() {
    if (!_autoReconnect) {
      _logger.debug('Ignoring restart, automatic reconnect is off.');
      return;
    }
    _reconnect();
  }

  void _reconnect() {
    _closeConnection();
    final delay = _backoff.getRetryDelay(_activeSince);
    _activeSince = null;

    // Another retry could be in progress, in which case we just allow it to
    // continue.
    // For instance a manual restart overlapping with an error.
    _retryTimer ??= Timer(Duration(milliseconds: delay), () {
      _retryTimer = null;
      _setupConnection();
    });
  }

  @override
  bool hasCapability(SSECapability capability) {
    // The browser native `EventSource` cannot send custom request
    // headers, only supports `GET`, and silently discards a request
    // body. None of the FDv2-relevant capabilities are supported here.
    return false;
  }
}

SSEClient getSSEClient(
        Uri uri,
        Set<String> eventTypes,
        Map<String, String> headers,
        Duration connectTimeout,
        Duration readTimeout,
        String? body,
        String method,
        EventSourceLogger? logger,
        Uri Function()? uriProvider,
        bool autoReconnect) =>
    // dropping unsupported configuration options
    HtmlSseClient(uri, eventTypes, logger,
        uriProvider: uriProvider, autoReconnect: autoReconnect);
