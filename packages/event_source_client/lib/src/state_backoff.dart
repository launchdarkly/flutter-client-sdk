import 'dart:math' as math;

import 'state_connecting.dart';
import 'state_idle.dart';
import 'state_value_object.dart';

/// This is the active state after a recoverable error has occurred and we are waiting
/// to attempt to reconnect to the server.  The backoff state follows an exponential
/// backoff scheme with 50% jitter starting at [_initialReconnectDelay] and capping
/// at [_maxDelay].  If [_resetInterval] has elapsed with no need for the backoff
/// state, the backoff is reset to [_initialReconnectDelay].
class StateBackoff {
  static const int _resetInterval = 60000; // 1 minute
  static const int _maxDelay = 30000; // 30 seconds
  static const int _initialReconnectDelay = 1000; // 1 second

  // If we assume the initial reconnect delay is 1 millisecond (the smallest it can be),
  // then the max exponent before we exceed the _maxDelay will be int(log2(_maxDelay)) + 1.  Another way
  // to think about this is it is the number of bits used by _maxDelay.  No point in using larger
  // exponents because the result won't fit in that number of bits.  This is a nice way to handle the
  // exponential overflow, because it doesn't require us to consider the bit size of the int type on
  // this platform.
  //
  // To do log2(), we use the log change of base formula, note that ~/ is division returning an integer.
  static final int _maxExponent = (math.log(_maxDelay) ~/ math.log(2)) + 1;

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
    final currentTime = DateTime.now().millisecondsSinceEpoch;
    // reset connection attempt count if enough time has passed
    final activeSince = svo.activeSince;
    if (activeSince != null) {
      if (currentTime - activeSince > _resetInterval) {
        svo.connectionAttemptCount = 0;
      }
    }
    svo.connectionAttemptCount++;
    final delayUpperBound =
        calculateDelayUpperBound(svo.connectionAttemptCount);
    final delayLowerBound = delayUpperBound ~/ 2; // integer division

    // randomly pick between the bounds
    final delayWithJitter =
        getRandomInRange(svo.random, delayLowerBound, delayUpperBound);

    await Future.delayed(Duration(milliseconds: delayWithJitter));
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

  /// Generates a positive random integer uniformly distributed on the range
  /// from [min], inclusive, to [max], exclusive.
  static int getRandomInRange(math.Random random, int min, int max) =>
      min + random.nextInt(max - min);

  /// Calculates the upper bound for how long this backoff should wait in millis.
  /// [attemptCount] must be greater than or equal to 1.
  static int calculateDelayUpperBound(int attemptCount) {
    // clamp the exponent to avoid any overflow shenanigans
    final int exponent = math.min(attemptCount - 1, _maxExponent);
    // calculate the delay
    final int unclampedDelay =
        _initialReconnectDelay * (math.pow(2, exponent).toInt());
    // clamp the delay to _maxDelay
    return math.min(unclampedDelay, _maxDelay);
  }
}
