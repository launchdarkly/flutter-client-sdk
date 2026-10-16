import 'state_connecting.dart';
import 'state_value_object.dart';

/// This is the active state when there is no desire to be connected
/// and also the active state after a failure that the client does not retry.
class StateIdle {
  static Future run(StateValues svo, {Object? errorCause}) async {
    // record transition to this state for testing/logging
    svo.transitionSink.add(StateIdle);

    // failures that the client does not retry are reported to subscribers.
    if (errorCause != null) {
      svo.logger.info('Transitioned to StateIdle due to error: $errorCause');
      svo.reportError(errorCause);
    } else {
      svo.logger.debug('Transitioned to StateIdle');
    }

    try {
      // transition away from this state when we desire to be connected
      await svo.connectionDesired.where((desired) => desired == true).first;
      StateConnecting.run(svo);
    } catch (err) {
      // indicates desire to cleanup state machine
    }
  }
}
