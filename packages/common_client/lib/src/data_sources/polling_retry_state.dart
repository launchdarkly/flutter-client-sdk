import 'dart:math' as math;

const _extendedInitialDelay = Duration(minutes: 5);
const _extendedMaxDelay = Duration(hours: 1);
// The consecutive successful polls that clear the backoff.
const _resetThreshold = 2;

Duration _max(Duration a, Duration b) => a > b ? a : b;

Duration _min(Duration a, Duration b) => a < b ? a : b;

/// Computes the wait before the polling data source polls again.
final class PollingRetryState {
  /// The wait after a successful poll, and the shortest wait after a failure.
  final Duration _pollInterval;

  // The bounds of the longer backoff. Neither is less than the poll interval.
  final Duration _initialDelay;
  final Duration _maxDelay;

  final math.Random _random;

  bool _inExtendedRegime = false;
  int _attempts = 0;
  int _consecutiveSuccesses = 0;

  PollingRetryState(this._pollInterval, {math.Random? random})
      : _initialDelay = _max(_extendedInitialDelay, _pollInterval),
        _maxDelay = _max(_extendedMaxDelay, _pollInterval),
        _random = random ?? math.Random();

  /// Records a failed poll. An [unexpected] failure starts the longer backoff.
  void recordFailure({required bool unexpected}) {
    _consecutiveSuccesses = 0;
    if (unexpected && !_inExtendedRegime) {
      _inExtendedRegime = true;
      _attempts = 0;
    }
    _attempts++;
  }

  /// Records a successful poll. Enough successes in a row clear the backoff.
  void recordSuccess() {
    _consecutiveSuccesses++;
    if (_consecutiveSuccesses < _resetThreshold) {
      return;
    }
    _inExtendedRegime = false;
    _attempts = 0;
  }

  /// Returns the wait before the next poll.
  Duration nextDelay() {
    // Only an unresolved unexpected failure waits longer than the poll interval.
    if (!_inExtendedRegime || _consecutiveSuccesses > 0) {
      return _pollInterval;
    }
    // The cap is reached long before 2^10, and a larger exponent can overflow.
    final exponent = math.min(_attempts - 1, 10);
    final delay = _min(_initialDelay * (1 << exponent), _maxDelay);
    // Wait between half of the delay and all of it.
    final half = delay.inMilliseconds ~/ 2;
    final wait = Duration(
        milliseconds: half + _random.nextInt(delay.inMilliseconds - half));
    // A failing source must not poll more often than a healthy one.
    return _max(_pollInterval, wait);
  }
}
