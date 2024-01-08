import 'dart:async';

import 'package:http/http.dart' as http;

import 'error_utils.dart';
import 'http_consts.dart';
import 'state_backoff.dart';
import 'state_connected.dart';
import 'state_idle.dart';
import 'state_value_object.dart';

/// This is the active state while we are sending the connection request to the
/// server and waiting for the response that confirms we are successful.
class StateConnecting {
  static const lastEventIdHeader = 'Last-Event-ID';

  // Runs the state with an instance of a real http client.
  static Future run(StateValues svo) async {
    // record transition to this state for testing/logging
    svo.transitionSink.add(StateConnecting);

    final client = svo.clientFactory();

    // transition away from this state when we get connected, fail to connect,
    // or we no longer desire to be connected.
    final transition = await Future.any([
      _tryGetConnected(svo, client),
      _monitorConnectionNoLongerDesired(svo, client)
    ]);
    transition();
  }

  /// This future will complete when we have failed to connect or have succeeded
  /// to connect.  The returned function will run the next state.
  static Future<Function> _tryGetConnected(
      StateValues svo, http.Client client) async {
    final request = http.Request('GET', svo.uri);
    request.headers.addAll(svo.headers);

    // special behavior of the SSE spec is to connect with an Id if we have one
    // to facillitate session resumption.
    if (svo.lastId.isNotEmpty) {
      request.headers.addAll({
        lastEventIdHeader: svo.lastId,
      });
    }

    try {
      final response = await client.send(request).timeout(svo.connectTimeout);

      // anything besides OK is bad, but some may be recoverable with a retry.
      if (response.statusCode != HttpStatusCodes.okStatus) {
        if (!ErrorUtils.isHttpStatusCodeRecoverable(response.statusCode)) {
          // looks like the error wasn't recoverable, go to idle and wait
          // for something to change
          return () => StateIdle.run(svo,
              errorCause: http.ClientException(
                  'Got unrecoverable status code ${response.statusCode}'));
        }

        // the error is recoverable, backoff then we'll try again
        return () => StateBackoff.run(svo);
      }

      final isEventStream = response.headers.entries.any((e) =>
          e.key.toLowerCase() == HttpHeaders.contentTypeHeader &&
          e.value.toLowerCase().contains(MimeTypes.textEventStream));
      if (!isEventStream) {
        // non event-stream content types are considered recoverable since it may be a service issue.
        return () => StateBackoff.run(svo);
      }

      return () => StateConnected.run(svo, client, response.stream);
    } on TimeoutException {
      // didn't connect in a timely manner, so backoff then we'll try again
      client.close;
      return () => StateBackoff.run(svo);
    } catch (err) {
      client.close();
      if (!ErrorUtils.isConnectionErrorRecoverable(err)) {
        // go to idle relaying the error that caused us to go idle.
        return () => StateIdle.run(svo, errorCause: err);
      }

      // we err on the side of caution and say that errors are recoverable.  The worst
      // thing that happens is we retry wastefully.  The alternative of assuming
      // errors are NOT recoverable is far worse!
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
}
