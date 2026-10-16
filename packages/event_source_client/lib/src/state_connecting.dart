import 'dart:async';

import 'package:http/http.dart' as http;

import 'error_utils.dart';
import 'errors.dart';
import 'http_consts.dart';
import 'state_connected.dart';
import 'state_idle.dart';
import 'state_stopped.dart';
import 'state_value_object.dart';

/// This is the active state while we are sending the connection request to the
/// server and waiting for the response that confirms we are successful.
class StateConnecting {
  static const lastEventIdHeader = 'Last-Event-ID';

  // Runs the state with an instance of a real http client.
  static Future run(StateValues svo) async {
    // record transition to this state for testing/logging
    svo.transitionSink.add(StateConnecting);
    svo.logger.debug('Transitioned to StateConnecting.');

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
    final request = http.Request(svo.httpMethod, svo.connectUri);
    request.headers.addAll(svo.headers);
    if (svo.body != null) {
      request.body = svo.body!;
    }

    // special behavior of the SSE spec is to connect with an Id if we have one
    // to facilitate session resumption.
    if (svo.lastId.isNotEmpty) {
      request.headers.addAll({
        lastEventIdHeader: svo.lastId,
      });
    }

    try {
      svo.logger.debug('Sending HTTP request to ${request.url}');
      final response = await client.send(request).timeout(svo.connectTimeout);

      // anything besides OK is bad, but some may be recoverable with a retry.
      if (response.statusCode != HttpStatusCodes.okStatus) {
        svo.logger.info(
            'HTTP connection error occurred with status code ${response.statusCode}');
        // Report every error response with its status and headers (which
        // may carry a service directive). The recoverable flag tells the
        // consumer whether we will retry on our own.
        final recoverable = svo.autoReconnect &&
            ErrorUtils.isHttpStatusCodeRecoverable(response.statusCode);
        final error = SseHttpError(response.statusCode, response.headers,
            recoverable: recoverable);
        return () => handleFailure(svo, client, error, retry: recoverable);
      }

      final isEventStream = response.headers.entries.any((e) =>
          e.key.toLowerCase() == HttpHeaders.contentTypeHeader &&
          e.value.toLowerCase().contains(MimeTypes.textEventStream));
      if (!isEventStream) {
        // non event-stream content types are considered recoverable since it may be a service issue.
        // The content type comes from the server, so it is not logged.
        return () {
          svo.logger.info('Connection received non-event-stream content type.');
          handleFailure(svo, client, const SseContentTypeError());
        };
      }

      svo.connectHeaders = response.headers;

      return () => StateConnected.run(svo, client, response.stream);
    } on TimeoutException {
      return () {
        svo.logger.info('Connection TimeoutException occurred.');
        handleFailure(
            svo, client, const SseTimeoutError(SseTimeoutPhase.connect));
      };
    } catch (err) {
      // we err on the side of caution and say that errors are recoverable.  The worst
      // thing that happens is we retry wastefully.  The alternative of assuming
      // errors are NOT recoverable is far worse!
      return () => handleFailure(svo, client, SseTransportError(err),
          retry: ErrorUtils.isConnectionErrorRecoverable(err));
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
