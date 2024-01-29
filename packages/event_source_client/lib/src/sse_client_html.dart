import 'dart:async';
import 'dart:html' as html;
import 'dart:math' as math;

import '../launchdarkly_event_source_client.dart';

import 'backoff.dart';
import 'message_event.dart' as ld_message_event;

/// An [SSEClient] that uses the [html.EventSource] available on most browsers for web platform support.
class HtmlSseClient implements SSEClient {
  /// The underlying eventsource
  html.EventSource? _eventSource;

  /// This controller is for the events going to the subscribers of this client.
  late final StreamController<ld_message_event.MessageEvent>
      _messageEventsController;

  Backoff _backoff = Backoff(math.Random());

  final Uri _uri;
  final Set<String> _eventTypes;

  int? _activeSince;
  Timer? _retryTimer;

  /// Creates an instance of an SSEClient that will connect in the future
  /// to the [uri] provided.
  HtmlSseClient(Uri uri, Set<String> eventTypes)
      : _uri = uri,
        _eventTypes = eventTypes {
    _messageEventsController =
        StreamController<ld_message_event.MessageEvent>.broadcast(
      onListen: () {
        // this is triggered when first listener subscribes
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
    // this is triggered when first listener subscribes
    _eventSource = html.EventSource(_uri.toString());
    // Reset the backoff data whenever the client consumer
    // a new connection.
    _backoff = Backoff(math.Random());
    for (var eventType in _eventTypes) {
      _eventSource?.addEventListener(eventType, _handleMessageEvent);
    }
    _eventSource?.addEventListener('error', _handleError);
  }

  void _handleError(html.Event event) {
    // The browser event source errors are reasonably opaque, if we could
    // determine the type of condition, then this is where we would
    // determine if this was a temporary or permanent failure.
    restart();
  }

  void _handleMessageEvent(html.Event event) {
    _activeSince = DateTime.now().millisecondsSinceEpoch;
    final messageEvent = event as html.MessageEvent;
    final ldMessageEvent = ld_message_event.MessageEvent(
        messageEvent.type, messageEvent.data, messageEvent.lastEventId);
    _messageEventsController.sink.add(ldMessageEvent);
  }

  /// Subscribe to this [stream] to receive events and sometimes errors.  The first
  /// subscribe triggers the connection, so expect a network delay initially.
  @override
  Stream<ld_message_event.MessageEvent> get stream =>
      _messageEventsController.stream;

  @override
  Future close() => _messageEventsController.close();

  @override
  void restart() {
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
}

SSEClient getSSEClient(
        Uri uri,
        Set<String> eventTypes,
        Map<String, String> headers,
        Duration connectTimeout,
        Duration readTimeout,
        String? body,
        String method) =>
    // dropping unsupported configuration options
    HtmlSseClient(uri, eventTypes);
