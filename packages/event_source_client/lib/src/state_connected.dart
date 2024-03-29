import 'dart:async';
import 'dart:convert';
import 'package:http/http.dart' as http;

import 'state_backoff.dart';
import 'state_idle.dart';
import 'state_value_object.dart';
import 'stateful_sse_parser.dart';

// This is the activate state while we are connected to the server and have
// received a event on the stream within the previous [readTimeout] duration
// of time.
class StateConnected {
  static Future run(
      StateValues svo, http.Client client, Stream<List<int>> stream) async {
    // record transition to this state for testing/logging
    svo.transitionSink.add(StateConnected);

    // wait for either the stream to terminate or desired connection change to transition
    final transition = await Future.any([
      _processStream(svo, stream),
      _monitorConnectionNoLongerDesired(svo, client),
      _monitorReset(svo, client),
    ]);
    transition();
  }

  // The future will complete when the connection has been lost or the stream completed.
  // The returned closure will be ignored by the Future.any(...) call near the top of
  // this class if the source of connection loss was a deliberate connection close.  All
  // other errors at this point are considered recoverable.  That may not be the case
  // but the Connecting state will figure that out during the next attempt.
  static Future<Function> _processStream(
      StateValues svo, Stream<List<int>> stream) async {
    var recordedActiveSince = false;
    final sseParser = StatefulSSEParser();
    try {
      await for (final event in stream
          .timeout(svo.readTimeout)
          .transform(utf8.decoder)
          .transform(
              StreamTransformer.fromHandlers(handleData: sseParser.parse))) {
        // record active since timestamp when we have first communication
        if (!recordedActiveSince) {
          svo.activeSince = DateTime.now().millisecondsSinceEpoch;
          recordedActiveSince = true;
        }

        // hold on to most recent id if there is one so we can use it for session resumption
        svo.lastId = event.id ?? svo.lastId;

        // only emit events that have event types the sse client was configured to use
        if (svo.eventTypes.contains(event.type)) {
          svo.eventSink.add(event);
        }
      }

      return () => StateBackoff.run(svo);
    } on TimeoutException {
      return () => StateBackoff.run(svo);
    } catch (error) {
      return () => StateBackoff.run(svo);
    }
  }

  /// This future will complete when we no longer desire to be connected.  The
  /// returned function will run the next state.
  static Future<Function> _monitorConnectionNoLongerDesired(
      StateValues svo, http.Client client) async {
    try {
      await svo.connectionDesired.where((desired) => !desired).first;
    } catch (err) {
      // error indicates control stream has terminated, so we want to cleanup
    }

    return () {
      client.close();
      StateIdle.run(svo);
    };
  }

  static Future<Function> _monitorReset(
      StateValues svo, http.Client client) async {
    try {
      await svo.resetRequest.first;
    } catch (err) {
      // error indicates control stream has terminated, so we want to cleanup
    }
    return () {
      client.close();
      StateBackoff.run(svo);
    };
  }
}
