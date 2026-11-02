import 'dart:async';
import 'dart:collection';
import 'dart:convert';
import 'package:http/http.dart' as http;

import 'events.dart';
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
    svo.logger.debug('Transitioned to StateConnected');
    svo.eventSink.add(OpenEvent(
        headers: svo.connectHeaders != null
            ? UnmodifiableMapView(svo.connectHeaders!)
            : null));

    // Completes when the connection must end. Closing the client does not end
    // an open response body on every platform. The browser client aborts only
    // requests that wait for response headers. So the response stream is also
    // cancelled explicitly.
    final stopReading = Completer<void>();

    // wait for either the stream to terminate or desired connection change to transition
    final transition = await Future.any([
      _processStream(svo, stream, stopReading.future),
      _monitorConnectionNoLongerDesired(svo, client, stopReading),
      _monitorReset(svo, client, stopReading),
    ]);
    transition();
  }

  // The future will complete when the connection has been lost or the stream completed.
  // The returned closure will be ignored by the Future.any(...) call near the top of
  // this class if the source of connection loss was a deliberate connection close.  All
  // other errors at this point are considered recoverable.  That may not be the case
  // but the Connecting state will figure that out during the next attempt.
  static Future<Function> _processStream(StateValues svo,
      Stream<List<int>> stream, Future<void> stopReading) async {
    var recordedActiveSince = false;
    final sseParser = StatefulSSEParser();
    final events = StreamIterator(stream
        .timeout(svo.readTimeout)
        .transform(utf8.decoder)
        .transform(
            StreamTransformer.fromHandlers(handleData: sseParser.parse)));
    final stopped = stopReading.then((_) => false);
    try {
      while (await Future.any([events.moveNext(), stopped])) {
        final event = events.current;
        // record active since timestamp when we have first communication
        if (!recordedActiveSince) {
          svo.activeSince = DateTime.now().millisecondsSinceEpoch;
          recordedActiveSince = true;
        }

        // Implementation note: Currently only message events are supported
        // by the parser, but we could potentially extend that to support
        // emitting comment events.
        switch (event) {
          case MessageEvent():
            // hold on to most recent id if there is one so we can use it for session resumption
            svo.lastId = event.id ?? svo.lastId;

            // only emit events that have event types the sse client was configured to use
            if (svo.eventTypes.contains(event.type)) {
              svo.eventSink.add(event);
            }
          default:
            break;
        }
      }

      return () {
        svo.logger.info('Connection closed, will retry with backoff.');
        StateBackoff.run(svo);
      };
    } on TimeoutException {
      return () {
        svo.logger.info(
            'Connection TimeoutException occurred, will retry with backoff.');
        StateBackoff.run(svo);
      };
    } catch (error) {
      return () {
        svo.logger.info(
            'Connection error occurred, will retry with backoff. Error was: $error');
        StateBackoff.run(svo);
      };
    } finally {
      // Releases the response. It ends the connection when the reading
      // stopped before the stream ended.
      await events.cancel();
    }
  }

  /// This future will complete when we no longer desire to be connected.  The
  /// returned function will run the next state.
  static Future<Function> _monitorConnectionNoLongerDesired(
      StateValues svo, http.Client client, Completer<void> stopReading) async {
    try {
      await svo.connectionDesired.where((desired) => !desired).first;
    } catch (err) {
      // error indicates control stream has terminated, so we want to cleanup
    }

    return () {
      stopReading.complete();
      client.close();
      svo.logger.debug('Connection no longer required.');
      StateIdle.run(svo);
    };
  }

  static Future<Function> _monitorReset(
      StateValues svo, http.Client client, Completer<void> stopReading) async {
    try {
      await svo.resetRequest.first;
    } catch (err) {
      // error indicates control stream has terminated, so we want to cleanup
    }
    return () {
      stopReading.complete();
      client.close();
      StateBackoff.run(svo);
    };
  }
}
