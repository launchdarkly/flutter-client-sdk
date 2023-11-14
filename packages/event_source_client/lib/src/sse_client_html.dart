import 'dart:async';
import 'dart:html' as html;

import 'package:launchdarkly_event_source_client/sse_client.dart';

import 'message_event.dart' as LDMessageEvent;

/// An [SSEClient] that uses the [html.EventSource] available on most browsers for web platform support.
class HtmlSseClient implements SSEClient {
  /// The underlying eventsource
  html.EventSource? _eventSource;

  /// This controller is for the events going to the subscribers of this client.
  late final StreamController<LDMessageEvent.MessageEvent>
      _messageEventsController;

  /// Creates an instance of an SSEClient that will connect in the future
  /// to the [uri] provided.
  HtmlSseClient(Uri uri, Set<String> eventTypes) {
    _messageEventsController =
        StreamController<LDMessageEvent.MessageEvent>.broadcast(
      onListen: () {
        // this is triggered when first listener subscribes
        _eventSource = html.EventSource(uri.toString());
        eventTypes.forEach((eventType) {
          _eventSource?.addEventListener(eventType, _handleMessageEvent);
        });
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
    final ldMessageEvent = LDMessageEvent.MessageEvent(
        messageEvent.type, messageEvent.data, messageEvent.lastEventId);
    _messageEventsController.sink.add(ldMessageEvent);
  }

  /// Subscribe to this [stream] to receive events and sometimes errors.  The first
  /// subscribe triggers the connection, so expect a network delay initially.
  Stream<LDMessageEvent.MessageEvent> get stream =>
      _messageEventsController.stream;

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
