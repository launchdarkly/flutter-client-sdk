import 'state_connecting.dart';
import 'state_idle.dart';
import 'state_value_object.dart';

/// This is the active state after a recoverable error has occurred and we are waiting
/// to attempt to reconnect to the server.
class StateBackoff {
  static Future run(StateValues svo) async {
    // record transition to this state for testing/logging
    svo.transitionSink.add(StateBackoff);

    // wait for either backoff or desired connection change to transition
    final transition = await Future.any(
        [_waitForBackoff(svo), _monitorConnectionNoLongerDesired(svo)]);
    transition();
  }

  /// This future will complete when the required backoff duration has elapsed.  This function
  /// should only be called once per connection attempt as it does increment the attempt counter
  /// of the shared state of the state machine.
  static Future<Function> _waitForBackoff(StateValues svo) async {
    final retryDelay = svo.backoff.getRetryDelay(svo.activeSince);

    await Future.delayed(Duration(milliseconds: retryDelay));
    return () {
      StateConnecting.run(svo);
    };
  }

  /// This future will complete when we no longer desire to be connected.  The
  /// returned function will run the next state.
  static Future<Function> _monitorConnectionNoLongerDesired(
      StateValues svo) async {
    try {
      await svo.connectionDesired.where((desired) => !desired).first;
    } catch (err) {
      // error indicates control stream has terminated, so we want to cleanup
    }

    return () {
      StateIdle.run(svo);
    };
  }
}
