import 'dart:async';
import 'dart:math' as math;

import 'package:http/http.dart' as http;

import '../launchdarkly_event_source_client.dart';
import 'events.dart' show isMessageEvent;
import 'state_idle.dart';
import 'state_value_object.dart';

/// An [SSEClient] that uses the [http.Client] for platform support.
///
///  The following cases will be considered unrecoverable and the [SSEClient] will report
///  an error on the [stream].
/// - HTTP Status Codes other than 200, 400, 408, 429, 500 - 599 will cause an error
/// - Cases in which a redirect loop is detected or a redirect is malformed.
class HttpSseClient implements SSEClient {
  static const defaultConnectTimeout = Duration(seconds: 30);
  static const defaultReadTimeout = Duration(minutes: 5);

  /// This controller is for the events going to the subscribers of this client.
  late final StreamController<Event> _messageEventsController;
  late final EventSourceLogger _logger;

  /// This controller is for controlling the internal state machine when subscribers
  /// subscribe / unsubscribe.
  final StreamController<bool> _connectionDesiredStateController =
      StreamController<bool>.broadcast();

  final StreamController<void> _resetRequest =
      StreamController<void>.broadcast();

  /// Creates an instance of an SSEClient that will connect in the future
  /// to the [uri].
  HttpSseClient(
      Uri uri,
      Set<String> eventTypes,
      Map<String, String> headers,
      Duration connectTimeout,
      Duration readTimeout,
      String? body,
      String httpMethod,
      EventSourceLogger? logger)
      : this.internal(
            uri,
            eventTypes,
            headers,
            connectTimeout,
            readTimeout,
            _NoOpSink(),
            () => http.Client(),
            math.Random(),
            body,
            httpMethod,
            logger);

  /// An internal constructor for injecting necessary dependencies for testing.
  HttpSseClient.internal(
      Uri uri,
      Set<String> eventTypes,
      Map<String, String> headers,
      Duration connectTimeout,
      Duration readTimeout,
      Sink<dynamic> transitionSink,
      ClientFactory clientFactory,
      math.Random random,
      String? body,
      String httpMethod,
      EventSourceLogger? logger) {
    _logger = logger ?? NoOpLogger();
    _messageEventsController = StreamController<Event>.broadcast(
      // this is triggered when first listener subscribes
      onListen: () => _connectionDesiredStateController.add(true),
      // this is triggered when last listener unsubscribes
      onCancel: () => _connectionDesiredStateController.add(false),
    );

    StateIdle.run(StateValues(
        uri,
        eventTypes,
        headers,
        connectTimeout,
        readTimeout,
        _connectionDesiredStateController.stream,
        _messageEventsController,
        transitionSink,
        clientFactory,
        random,
        body,
        httpMethod,
        _resetRequest.stream,
        logger ?? NoOpLogger()));
  }

  /// Subscribe to this [stream] to receive events and sometimes errors.  The first
  /// subscribe triggers the connection, so expect a network delay initially.
  @override
  Stream<Event> get stream => _messageEventsController.stream;

  @override
  Future close() async {
    _logger.debug('Closing SSE client permanently.');
    _messageEventsController.close();
    _connectionDesiredStateController.close();
    _resetRequest.close();
  }

  @override
  void restart() {
    _logger.debug('Restarting SSE client.');
    if (_resetRequest.hasListener) {
      _resetRequest.sink.add(null);
    }
  }
}

/// No op sink.  Exists to accommodate unit testing.
class _NoOpSink implements Sink<dynamic> {
  @override
  void add(data) {}

  @override
  void close() {}
}

SSEClient getSSEClient(
        Uri uri,
        Set<String> eventTypes,
        Map<String, String> headers,
        Duration connectTimeout,
        Duration readTimeout,
        String? body,
        String method,
        EventSourceLogger? logger) =>
    HttpSseClient(uri, eventTypes, headers, connectTimeout, readTimeout, body,
        method, logger);
