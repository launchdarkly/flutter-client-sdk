import 'dart:async';
import 'package:http/http.dart' as http;
import 'dart:math' as math;

import 'backoff.dart';
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
  // Non-transient configuration data
  final Uri uri;
  final Set<String> eventTypes;
  final Map<String, String> headers;
  final Duration connectTimeout;
  final Duration readTimeout;
  final String? body;
  final String httpMethod;

  // Non-transient internally provided
  final Stream<bool> connectionDesired;

  // This is a broadcast stream, and the request is only posted if there are
  // listeners, so it is an ephemeral trigger.
  final Stream<void> resetRequest;
  final EventSink<MessageEvent> eventSink;
  final Sink<dynamic> transitionSink; // for testing transitions
  final ClientFactory clientFactory;
  final math.Random random;

  final Backoff backoff;

  // Transient data

  /// The timestamp when the last active connection was established.
  int? activeSince; // millis since epoch
  /// The most recently received event ID from the server.  Used for resumption.
  String lastId = '';

  /// Creates a [_StateValues] instance.  Used by the state machine.
  StateValues(
      this.uri,
      this.eventTypes,
      this.headers,
      this.connectTimeout,
      this.readTimeout,
      this.connectionDesired,
      this.eventSink,
      this.transitionSink,
      this.clientFactory,
      this.random,
      this.body,
      this.httpMethod,
      this.resetRequest)
      : backoff = Backoff(random);
}
