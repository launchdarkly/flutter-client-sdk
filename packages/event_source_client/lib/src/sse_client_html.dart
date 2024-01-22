import 'dart:async';
import 'dart:html' as html;

import '../launchdarkly_event_source_client.dart';

import 'message_event.dart' as ld_message_event;

/// An [SSEClient] that uses the [html.EventSource] available on most browsers for web platform support.
class HtmlSseClient implements SSEClient {
  /// The underlying eventsource
  html.EventSource? _eventSource;

  /// This controller is for the events going to the subscribers of this client.
  late final StreamController<ld_message_event.MessageEvent>
      _messageEventsController;

  /// Creates an instance of an SSEClient that will connect in the future
  /// to the [uri] provided.
  HtmlSseClient(Uri uri, Set<String> eventTypes) {
    _messageEventsController =
        StreamController<ld_message_event.MessageEvent>.broadcast(
      onListen: () {
        // this is triggered when first listener subscribes
        _eventSource = html.EventSource(uri.toString());
        for (var eventType in eventTypes) {
          _eventSource?.addEventListener(eventType, _handleMessageEvent);
        }
      },
      onCancel: () {
        // this is triggered when last listener unsubscribes
        _eventSource?.close();
        _eventSource = null;
      },
    );
  }

  void _handleMessageEvent(html.Event event) {
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
}

SSEClient getSSEClient(
        Uri uri,
        Set<String> eventTypes,
        Map<String, String> headers,
        Duration connectTimeout,
        Duration readTimeout) =>
    // dropping unsupported configuration options
    HtmlSseClient(uri, eventTypes);
