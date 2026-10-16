import 'package:http/http.dart' as http;

import 'state_backoff.dart';
import 'state_idle.dart';
import 'state_value_object.dart';

/// This is the final state after a failure when automatic reconnect is off.
/// The client reports the failure, and then does nothing until it is closed.
class StateStopped {
  static void run(StateValues svo, Object error) {
    // record transition to this state for testing/logging
    svo.transitionSink.add(StateStopped);
    svo.logger.info('Transitioned to StateStopped due to error: $error');
    svo.reportError(error);
  }
}

/// Closes [client] and moves the state machine on after a connection
/// failure. Every path reports [error].
///
/// With automatic reconnect off, the client stops. Otherwise it backs off
/// and tries again when [retry] is true, and goes idle when [retry] is
/// false.
void handleFailure(StateValues svo, http.Client client, Object error,
    {bool retry = true}) {
  client.close();
  if (!svo.autoReconnect) {
    StateStopped.run(svo, error);
    return;
  }
  if (!retry) {
    StateIdle.run(svo, errorCause: error);
    return;
  }
  svo.reportError(error);
  StateBackoff.run(svo);
}
