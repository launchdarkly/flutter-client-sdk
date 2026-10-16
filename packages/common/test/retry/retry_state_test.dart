import 'dart:math' as math;

import 'package:launchdarkly_dart_common/launchdarkly_dart_common.dart';
import 'package:test/test.dart';

/// A random source that always returns the same fraction.
final class _FixedRandom implements math.Random {
  final double fraction;

  _FixedRandom(this.fraction);

  @override
  double nextDouble() => fraction;

  @override
  bool nextBool() => fraction >= 0.5;

  @override
  int nextInt(int max) => (fraction * max).floor();
}

/// A monotonic clock that tests move by hand.
final class _ManualClock {
  Duration now = Duration.zero;

  Duration call() => now;
}

void main() {
  group('streaming', () {
    RetryState noJitter([_ManualClock? clock]) => RetryState.streaming(
        random: _FixedRandom(0), clock: (clock ?? _ManualClock()).call);

    test('normal failures double from 1 second up to 30 seconds', () {
      final state = noJitter();
      final delays = [
        for (var i = 0; i < 7; i++) state.recordFailure(FailureKind.normal)
      ];
      expect(delays, const [
        Duration(seconds: 1),
        Duration(seconds: 2),
        Duration(seconds: 4),
        Duration(seconds: 8),
        Duration(seconds: 16),
        Duration(seconds: 30),
        Duration(seconds: 30),
      ]);
    });

    test('unexpected failures double from 5 minutes up to 1 hour', () {
      final state = noJitter();
      final delays = [
        for (var i = 0; i < 6; i++) state.recordFailure(FailureKind.unexpected)
      ];
      expect(delays, const [
        Duration(minutes: 5),
        Duration(minutes: 10),
        Duration(minutes: 20),
        Duration(minutes: 40),
        Duration(hours: 1),
        Duration(hours: 1),
      ]);
    });

    test('an unexpected failure after normal failures starts at 5 minutes', () {
      final state = noJitter();
      state.recordFailure(FailureKind.normal);
      state.recordFailure(FailureKind.normal);
      state.recordFailure(FailureKind.normal);
      expect(state.recordFailure(FailureKind.unexpected),
          const Duration(minutes: 5));
    });

    test('a normal failure does not leave the extended regime', () {
      final state = noJitter();
      state.recordFailure(FailureKind.unexpected);
      expect(
          state.recordFailure(FailureKind.normal), const Duration(minutes: 10));
      expect(
          state.recordFailure(FailureKind.normal), const Duration(minutes: 20));
    });

    test('60 seconds of healthy operation resets the state', () {
      final clock = _ManualClock();
      final state = noJitter(clock);
      state.recordFailure(FailureKind.unexpected);
      state.recordFailure(FailureKind.unexpected);

      state.recordSuccess();
      clock.now += const Duration(seconds: 60);

      expect(
          state.recordFailure(FailureKind.normal), const Duration(seconds: 1));
    });

    test('less than 60 seconds of healthy operation keeps the state', () {
      final clock = _ManualClock();
      final state = noJitter(clock);
      state.recordFailure(FailureKind.unexpected);

      state.recordSuccess();
      clock.now += const Duration(seconds: 59);

      expect(
          state.recordFailure(FailureKind.normal), const Duration(minutes: 10));
    });

    test('healthy time is measured from the first success after a failure', () {
      final clock = _ManualClock();
      final state = noJitter(clock);
      state.recordFailure(FailureKind.unexpected);

      state.recordSuccess();
      clock.now += const Duration(seconds: 50);
      state.recordSuccess();
      clock.now += const Duration(seconds: 10);

      expect(
          state.recordFailure(FailureKind.normal), const Duration(seconds: 1));
    });

    test('a failure restarts the healthy measurement', () {
      final clock = _ManualClock();
      final state = noJitter(clock);
      state.recordFailure(FailureKind.unexpected);

      state.recordSuccess();
      clock.now += const Duration(seconds: 30);
      state.recordFailure(FailureKind.normal);
      clock.now += const Duration(seconds: 40);

      expect(
          state.recordFailure(FailureKind.normal), const Duration(minutes: 20));
    });

    test('many failures stay at the ceiling', () {
      final state = noJitter();
      Duration delay = Duration.zero;
      for (var i = 0; i < 10000; i++) {
        delay = state.recordFailure(FailureKind.unexpected);
      }
      expect(delay, const Duration(hours: 1));
    });

    test('the jitter removes up to half of the delay', () {
      final state = RetryState.streaming(random: _FixedRandom(0.999999));
      state.recordFailure(FailureKind.normal);
      state.recordFailure(FailureKind.normal);
      final delay = state.recordFailure(FailureKind.normal);
      expect(delay, greaterThanOrEqualTo(const Duration(seconds: 2)));
      expect(delay, lessThan(const Duration(milliseconds: 2010)));
    });

    test('the jitter stays in range with a real random source', () {
      final state = RetryState.streaming(random: math.Random(1));
      // The first four delays are below the ceiling.
      for (var i = 0; i < 4; i++) {
        state.recordFailure(FailureKind.unexpected);
      }
      for (var i = 0; i < 200; i++) {
        final delay = state.recordFailure(FailureKind.unexpected);
        expect(delay, greaterThanOrEqualTo(const Duration(minutes: 30)));
        expect(delay, lessThanOrEqualTo(const Duration(hours: 1)));
      }
    });
  });

  group('polling', () {
    const interval = Duration(seconds: 30);

    test('a normal failure waits the poll interval', () {
      final state =
          RetryState.polling(interval, random: _FixedRandom(0.999999));
      for (var i = 0; i < 5; i++) {
        expect(state.recordFailure(FailureKind.normal), interval);
      }
    });

    test('unexpected failures double from 5 minutes up to 1 hour', () {
      final state = RetryState.polling(interval, random: _FixedRandom(0));
      final delays = [
        for (var i = 0; i < 6; i++) state.recordFailure(FailureKind.unexpected)
      ];
      expect(delays, const [
        Duration(minutes: 5),
        Duration(minutes: 10),
        Duration(minutes: 20),
        Duration(minutes: 40),
        Duration(hours: 1),
        Duration(hours: 1),
      ]);
    });

    test('a poll interval above the extended values raises them', () {
      const longInterval = Duration(hours: 2);
      final state = RetryState.polling(longInterval, random: _FixedRandom(0));
      expect(state.recordFailure(FailureKind.unexpected), longInterval);
      expect(state.recordFailure(FailureKind.unexpected), longInterval);
    });

    test('no wait is shorter than the poll interval', () {
      const longInterval = Duration(minutes: 8);
      final state =
          RetryState.polling(longInterval, random: _FixedRandom(0.999999));
      // The base delay is 8 minutes and the jitter can remove up to half.
      expect(state.recordFailure(FailureKind.unexpected), longInterval);
    });

    test('two successful polls in a row reset the state', () {
      final state = RetryState.polling(interval, random: _FixedRandom(0));
      state.recordFailure(FailureKind.unexpected);
      state.recordSuccess();
      state.recordSuccess();
      expect(state.recordFailure(FailureKind.normal), interval);
    });

    test('one successful poll does not reset the state', () {
      final state = RetryState.polling(interval, random: _FixedRandom(0));
      state.recordFailure(FailureKind.unexpected);
      state.recordSuccess();
      expect(
          state.recordFailure(FailureKind.normal), const Duration(minutes: 10));
    });

    test('a failure between successes restarts the count', () {
      final state = RetryState.polling(interval, random: _FixedRandom(0));
      state.recordFailure(FailureKind.unexpected);
      state.recordSuccess();
      state.recordFailure(FailureKind.normal);
      state.recordSuccess();
      expect(
          state.recordFailure(FailureKind.normal), const Duration(minutes: 20));
    });
  });
}
