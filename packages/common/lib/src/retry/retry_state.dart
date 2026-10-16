import 'dart:math' as math;

/// The classification of a failure. It controls how long a long-running
/// component waits before it tries again.
enum FailureKind {
  /// A failure that is likely to clear quickly. Examples are a 5xx status,
  /// a network error, a timeout and a bad payload.
  normal,

  /// A failure that is not likely to clear quickly. Examples are a 401 or a
  /// 403 status.
  unexpected,
}

const _streamingInitialDelay = Duration(seconds: 1);
const _streamingCeiling = Duration(seconds: 30);
const _minimumExtendedInitialDelay = Duration(minutes: 5);
const _minimumExtendedCeiling = Duration(hours: 1);
const _streamingResetThreshold = Duration(seconds: 60);
const _pollingResetThreshold = 2;

// Every ceiling is much less than 2^16 times its initial delay, so the cap
// does not change a result. It keeps the product small enough to not
// overflow, also on the web where integers are doubles.
const _maxExponent = 16;

Duration Function() _monotonicClock() {
  final stopwatch = Stopwatch()..start();
  return () => stopwatch.elapsed;
}

Duration _max(Duration a, Duration b) => a > b ? a : b;

/// Computes the wait before a long-running component tries again after a
/// failure.
///
/// The wait uses exponential backoff with jitter. A normal failure backs
/// off from the normal initial delay up to the normal ceiling. An
/// unexpected failure moves the state to the extended regime, which backs
/// off from the extended initial delay up to the extended ceiling. The
/// state stays in the extended regime until a reset.
///
/// This class is not thread safe.
final class RetryState {
  final Duration _normalInitialDelay;
  final Duration _normalCeiling;
  final Duration _extendedInitialDelay;
  final Duration _extendedCeiling;

  /// No wait is shorter than this.
  final Duration _minimumWait;

  /// The duration of healthy operation that resets the state, if the reset
  /// uses a duration.
  final Duration? _healthyResetThreshold;

  /// The number of consecutive successes that resets the state, if the
  /// reset uses a count.
  final int? _successResetThreshold;

  final math.Random _random;
  final Duration Function() _clock;

  int _attempts = 0;
  bool _extended = false;
  Duration? _healthySince;
  int _consecutiveSuccesses = 0;

  /// The retry state for a streaming data source.
  ///
  /// The normal regime backs off from 1 second up to 30 seconds. The
  /// extended regime backs off from 5 minutes up to 1 hour. The state resets
  /// when a failure comes after 60 seconds of healthy operation.
  ///
  /// The [clock] must be monotonic. The [random] and [clock] parameters are
  /// for tests.
  RetryState.streaming({math.Random? random, Duration Function()? clock})
      : _normalInitialDelay = _streamingInitialDelay,
        _normalCeiling = _streamingCeiling,
        _extendedInitialDelay = _minimumExtendedInitialDelay,
        _extendedCeiling = _minimumExtendedCeiling,
        _minimumWait = Duration.zero,
        _healthyResetThreshold = _streamingResetThreshold,
        _successResetThreshold = null,
        _random = random ?? math.Random(),
        _clock = clock ?? _monotonicClock();

  /// The retry state for a polling data source.
  ///
  /// A normal failure waits the [pollInterval]. The extended regime backs
  /// off from 5 minutes up to 1 hour, but these values are never less than
  /// the [pollInterval]. No wait is shorter than the [pollInterval]. The
  /// state resets after 2 successful polls in a row.
  ///
  /// The [random] parameter is for tests.
  RetryState.polling(Duration pollInterval, {math.Random? random})
      : _normalInitialDelay = pollInterval,
        _normalCeiling = pollInterval,
        _extendedInitialDelay =
            _max(_minimumExtendedInitialDelay, pollInterval),
        _extendedCeiling = _max(_minimumExtendedCeiling, pollInterval),
        _minimumWait = pollInterval,
        _healthyResetThreshold = null,
        _successResetThreshold = _pollingResetThreshold,
        _random = random ?? math.Random(),
        _clock = _monotonicClock();

  /// Records healthy operation.
  ///
  /// For streaming, call this for each payload. The first call after a
  /// failure starts the healthy period. For polling, call this for each
  /// successful poll.
  void recordSuccess() {
    if (_healthyResetThreshold != null) {
      _healthySince ??= _clock();
    }
    if (_successResetThreshold case final threshold?) {
      _consecutiveSuccesses++;
      if (_consecutiveSuccesses >= threshold) {
        _reset();
      }
    }
  }

  /// Records a failure of the given [kind] and returns the wait before the
  /// next attempt.
  Duration recordFailure(FailureKind kind) {
    if ((_healthyResetThreshold, _healthySince)
        case (final threshold?, final healthySince?)
        when _clock() - healthySince >= threshold) {
      _reset();
    }
    _healthySince = null;
    _consecutiveSuccesses = 0;

    switch (kind) {
      case FailureKind.unexpected when !_extended:
        // Start the extended regime at its initial delay.
        _extended = true;
        _attempts = 1;
      case FailureKind.unexpected:
      case FailureKind.normal:
        _attempts++;
    }
    return _nextDelay();
  }

  void _reset() {
    _attempts = 0;
    _extended = false;
    _consecutiveSuccesses = 0;
  }

  Duration _nextDelay() {
    final initial = _extended ? _extendedInitialDelay : _normalInitialDelay;
    final ceiling = _extended ? _extendedCeiling : _normalCeiling;
    final exponent = math.min(_attempts - 1, _maxExponent);
    final base = initial * math.pow(2, exponent);
    final clamped = base > ceiling ? ceiling : base;
    final jitter = clamped * (_random.nextDouble() / 2);
    return _max(_minimumWait, clamped - jitter);
  }
}
