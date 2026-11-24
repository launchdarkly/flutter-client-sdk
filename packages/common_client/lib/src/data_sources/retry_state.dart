import 'dart:math' as math;

const _streamingInitialDelay = Duration(seconds: 1);
const _streamingMaxDelay = Duration(seconds: 30);
const _extendedInitialDelay = Duration(minutes: 5);
const _extendedMaxDelay = Duration(hours: 1);
// The consecutive successful polls that clear the backoff.
const _pollingResetThreshold = 2;
// The healthy streaming time that clears the backoff.
const _streamingResetThreshold = Duration(seconds: 60);

Duration _max(Duration a, Duration b) => a > b ? a : b;

Duration _min(Duration a, Duration b) => a < b ? a : b;

/// Returns the delay for the given attempt, less a random jitter of up to half.
Duration _jitteredBackoff(Duration initialDelay, Duration maxDelay,
    int attempts, math.Random random) {
  // The cap is reached long before 2^10, and a larger exponent can overflow.
  final exponent = math.min(attempts - 1, 10);
  final delay = _min(initialDelay * (1 << exponent), maxDelay);
  // Wait between half of the delay and all of it.
  final half = delay.inMilliseconds ~/ 2;
  return Duration(
      milliseconds: half + random.nextInt(delay.inMilliseconds - half));
}

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
    if (_consecutiveSuccesses < _pollingResetThreshold) {
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
    // A failing source must not poll more often than a healthy one.
    return _max(_pollInterval,
        _jitteredBackoff(_initialDelay, _maxDelay, _attempts, _random));
  }
}

/// Computes the wait before the streaming data source reconnects.
final class StreamingRetryState {
  final math.Random _random;
  final DateTime Function() _now;

  bool _inExtendedRegime = false;
  int _attempts = 0;
  DateTime? _healthySince;

  StreamingRetryState({math.Random? random, DateTime Function()? now})
      : _random = random ?? math.Random(),
        _now = now ?? DateTime.now;

  /// Records a message. A connection's first message starts the healthy period.
  void recordMessage() {
    _healthySince ??= _now();
  }

  /// Records a failure. An [unexpected] failure starts the longer backoff.
  void recordFailure({required bool unexpected}) {
    if (_healthySince case final since?
        when _now().difference(since) >= _streamingResetThreshold) {
      _inExtendedRegime = false;
      _attempts = 0;
    }
    _healthySince = null;
    if (unexpected && !_inExtendedRegime) {
      _inExtendedRegime = true;
      _attempts = 0;
    }
    _attempts++;
  }

  /// Returns the wait before the next connection.
  Duration nextDelay() => _inExtendedRegime
      ? _jitteredBackoff(
          _extendedInitialDelay, _extendedMaxDelay, _attempts, _random)
      : _jitteredBackoff(
          _streamingInitialDelay, _streamingMaxDelay, _attempts, _random);
}
