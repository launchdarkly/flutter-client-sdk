import 'state_connecting.dart';
import 'state_value_object.dart';

/// This is the active state when there is no desire to be connected
/// and also the active state when we have encountered an unrecoverable error.
class StateIdle {
  static Future run(StateValues svo, {Object? errorCause}) async {
    // record transition to this state for testing/logging
    svo.transitionSink.add(StateIdle);

    // unrecoverable errors are reported to subscribers of the client.
    if (errorCause != null) {
      svo.eventSink.addError(errorCause);
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
