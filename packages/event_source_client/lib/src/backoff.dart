import 'dart:math' as math;

/// The backoff follows an exponential backoff scheme with 50% jitter starting at
/// [_initialReconnectDelay] and capping at [_maxDelay].  If [_resetInterval]
/// has elapsed with no need for the backoff
/// state, the backoff is reset to [_initialReconnectDelay].
final class Backoff {
  static const int _resetInterval = 60000; // 1 minute
  static const int _maxDelay = 30000; // 30 seconds
  final int _initialReconnectDelay; // 1 sec
  int _connectionAttempt = 0;

  final math.Random _random;

  // If we assume the initial reconnect delay is 1 millisecond (the smallest it can be),
  // then the max exponent before we exceed the _maxDelay will be int(log2(_maxDelay)) + 1.  Another way
  // to think about this is it is the number of bits used by _maxDelay.  No point in using larger
  // exponents because the result won't fit in that number of bits.  This is a nice way to handle the
  // exponential overflow, because it doesn't require us to consider the bit size of the int type on
  // this platform.
  //
  // To do log2(), we use the log change of base formula, note that ~/ is division returning an integer.
  static final int _maxExponent = (math.log(_maxDelay) ~/ math.log(2)) + 1;

  Backoff(this._random, {int initialReconnectDelay = 1000})
      : _initialReconnectDelay = initialReconnectDelay;

  int getRetryDelay(int? activeSince) {
    final currentTime = DateTime.now().millisecondsSinceEpoch;
    if (activeSince != null) {
      if (currentTime - activeSince >= _resetInterval) {
        _connectionAttempt = 0;
      }
    }
    _connectionAttempt++;

    final delayUpperBound = _calculateDelayUpperBound(_connectionAttempt);
    final delayLowerBound = delayUpperBound ~/ 2; // integer division

    // randomly pick between the bounds
    return _getRandomInRange(delayLowerBound, delayUpperBound);
  }

  /// Calculates the upper bound for how long this backoff should wait in millis.
  /// [attemptCount] must be greater than or equal to 1.
  int _calculateDelayUpperBound(int attemptCount) {
    // clamp the exponent to avoid any overflow shenanigans
    final int exponent = math.min(attemptCount - 1, _maxExponent);
    // calculate the delay
    final int unclampedDelay =
        _initialReconnectDelay * (math.pow(2, exponent).toInt());
    // clamp the delay to _maxDelay
    return math.min(unclampedDelay, _maxDelay);
  }

  int _getRandomInRange(int min, int max) => min + _random.nextInt(max - min);
}
