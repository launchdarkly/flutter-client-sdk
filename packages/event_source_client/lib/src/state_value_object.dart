import 'dart:async';
import 'package:http/http.dart' as http;
import 'dart:math' as math;

import 'message_event.dart';

typedef ClientFactory = http.Client Function();

/// This class holds non-transient and transient data to be carried from
/// state to state while the state machine operates.
///
/// Non-transient data includes configuration values provided
/// by the consumer's code base as well as objects provided internally to
/// hook the state machine up to the SSEClient class.  Transient data
/// includes values that are altered while the state machine operates
/// to carry out its duties.
class StateValues {
  // Non-transient configruation data
  final Uri uri;
  final Set<String> eventTypes;
  final Map<String, String> headers;
  final Duration connectTimeout;
  final Duration readTimeout;

  // Non-transient internally provided
  final Stream<bool> connectionDesired;
  final EventSink<MessageEvent> eventSink;
  final Sink<dynamic> transitionSink; // for testing transitions
  final ClientFactory clientFactory;
  final math.Random random;

  // Transient data
  /// Tracks which attempt to connect the client is at.
  int connectionAttemptCount = 0;

  /// The timestamp when the last active connection was established.
  int? activeSince; // millis since epoch
  /// The most recently received event ID from the server.  Used for resumption.
  String lastId = '';

  /// Creates a [_StateValues] instance.  Used by the state machine.
  StateValues(
      Uri uri,
      Set<String> eventTypes,
      Map<String, String> headers,
      Duration connectTimeout,
      Duration readTimeout,
      Stream<bool> connectionDesired,
      EventSink<MessageEvent> eventSink,
      Sink<dynamic> transitionSink,
      ClientFactory clientFactory,
      math.Random random)
      : uri = uri,
        eventTypes = eventTypes,
        headers = headers,
        connectTimeout = connectTimeout,
        readTimeout = readTimeout,
        connectionDesired = connectionDesired,
        eventSink = eventSink,
        transitionSink = transitionSink,
        clientFactory = clientFactory,
        random = random;
}
