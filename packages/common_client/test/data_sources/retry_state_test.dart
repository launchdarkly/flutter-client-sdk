import 'dart:math' as math;

import 'package:launchdarkly_common_client/src/data_sources/retry_state.dart';
import 'package:test/test.dart';

final class MockRandom implements math.Random {
  double ratio;

  MockRandom({this.ratio = 1});

  @override
  bool nextBool() {
    throw UnimplementedError();
  }

  @override
  double nextDouble() {
    throw UnimplementedError();
  }

  @override
  int nextInt(int max) {
    return (max * ratio).toInt();
  }
}

void main() {
  const interval = Duration(seconds: 30);

  test('normal failures wait the poll interval and do not lengthen a backoff',
      () {
    final retry = PollingRetryState(interval, random: MockRandom());

    for (var i = 0; i < 3; i++) {
      // Record a normal failure.
      retry.recordFailure(unexpected: false);
      // The wait does not grow.
      expect(retry.nextDelay(), interval);
    }
    // Record an unexpected failure.
    retry.recordFailure(unexpected: true);
    // The backoff starts at 5 minutes, as if no failures came before it.
    expect(retry.nextDelay(), const Duration(minutes: 5));
  });

  test('an unexpected failure starts a backoff that doubles up to an hour', () {
    final retry = PollingRetryState(interval, random: MockRandom());

    // Record an unexpected failure, then normal failures.
    retry.recordFailure(unexpected: true);
    final delays = [retry.nextDelay()];
    for (var i = 0; i < 5; i++) {
      retry.recordFailure(unexpected: false);
      delays.add(retry.nextDelay());
    }
    // The wait starts at 5 minutes and doubles up to 1 hour.
    expect(delays, const [
      Duration(minutes: 5),
      Duration(minutes: 10),
      Duration(minutes: 20),
      Duration(minutes: 40),
      Duration(hours: 1),
      Duration(hours: 1),
    ]);
  });

  test('the backoff stays at an hour after many failures', () {
    final retry = PollingRetryState(interval, random: MockRandom());

    // Record more failures than an integer exponent can hold.
    for (var i = 0; i < 100; i++) {
      retry.recordFailure(unexpected: true);
    }
    // The wait is still the cap.
    expect(retry.nextDelay(), const Duration(hours: 1));
  });

  test('jitter removes up to half of the delay', () {
    final retry = PollingRetryState(interval, random: MockRandom(ratio: 0));

    // Record an unexpected failure.
    retry.recordFailure(unexpected: true);
    // With the most jitter, the wait is half of 5 minutes.
    expect(retry.nextDelay(), const Duration(seconds: 150));
  });

  test('jitter does not make the wait less than the poll interval', () {
    const longInterval = Duration(minutes: 4);
    final retry = PollingRetryState(longInterval, random: MockRandom(ratio: 0));

    // Record an unexpected failure.
    retry.recordFailure(unexpected: true);
    // Half of 5 minutes is below the interval, so the wait is the interval.
    expect(retry.nextDelay(), longInterval);
  });

  test('a poll interval above 5 minutes starts the backoff', () {
    final retry =
        PollingRetryState(const Duration(minutes: 10), random: MockRandom());

    // Record four unexpected failures.
    final delays = <Duration>[];
    for (var i = 0; i < 4; i++) {
      retry.recordFailure(unexpected: true);
      delays.add(retry.nextDelay());
    }
    // The backoff starts at the poll interval instead of 5 minutes.
    expect(delays, const [
      Duration(minutes: 10),
      Duration(minutes: 20),
      Duration(minutes: 40),
      Duration(hours: 1),
    ]);
  });

  test('a single success waits the poll interval and keeps the backoff', () {
    final retry = PollingRetryState(interval, random: MockRandom());
    retry.recordFailure(unexpected: true);

    // Alternate successes and normal failures.
    final delays = <Duration>[];
    for (var i = 0; i < 2; i++) {
      retry.recordSuccess();
      delays.add(retry.nextDelay());
      retry.recordFailure(unexpected: false);
      delays.add(retry.nextDelay());
    }
    // A success waits the poll interval, and a failure resumes the backoff.
    expect(delays, const [
      interval,
      Duration(minutes: 10),
      interval,
      Duration(minutes: 20),
    ]);
  });

  test('two successes in a row clear the backoff', () {
    final retry = PollingRetryState(interval, random: MockRandom());
    retry.recordFailure(unexpected: true);

    // Record two successes, then a normal failure.
    retry.recordSuccess();
    retry.recordSuccess();
    retry.recordFailure(unexpected: false);
    // The failure waits the poll interval.
    expect(retry.nextDelay(), interval);
  });

  group('streaming', () {
    test('normal failures double from 1 second up to 30 seconds', () {
      final retry = StreamingRetryState(random: MockRandom());

      // Record seven normal failures.
      final delays = <Duration>[];
      for (var i = 0; i < 7; i++) {
        retry.recordFailure(unexpected: false);
        delays.add(retry.nextDelay());
      }
      // The wait doubles from 1 second and stops at 30 seconds.
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

    test('an unexpected failure starts the longer backoff at 5 minutes', () {
      final retry = StreamingRetryState(random: MockRandom());
      retry.recordFailure(unexpected: false);

      // Record an unexpected failure, then normal failures.
      retry.recordFailure(unexpected: true);
      final delays = [retry.nextDelay()];
      for (var i = 0; i < 5; i++) {
        retry.recordFailure(unexpected: false);
        delays.add(retry.nextDelay());
      }
      // The wait starts at 5 minutes and doubles up to 1 hour.
      expect(delays, const [
        Duration(minutes: 5),
        Duration(minutes: 10),
        Duration(minutes: 20),
        Duration(minutes: 40),
        Duration(hours: 1),
        Duration(hours: 1),
      ]);
    });

    test('jitter removes up to half of the delay', () {
      final retry = StreamingRetryState(random: MockRandom(ratio: 0));

      // Record a normal failure.
      retry.recordFailure(unexpected: false);
      // With the most jitter, the wait is half of 1 second.
      expect(retry.nextDelay(), const Duration(milliseconds: 500));
    });

    test('60 seconds from the first message clears the backoff', () {
      var now = DateTime(1);
      final retry = StreamingRetryState(random: MockRandom(), now: () => now);
      retry.recordFailure(unexpected: true);

      // Receive the first message.
      retry.recordMessage();
      // Receive another message 30 seconds later.
      now = now.add(const Duration(seconds: 30));
      retry.recordMessage();
      // Fail 60 seconds after the first message.
      now = now.add(const Duration(seconds: 30));
      retry.recordFailure(unexpected: false);
      // The backoff is clear, so the wait is the first normal wait.
      expect(retry.nextDelay(), const Duration(seconds: 1));
    });

    test('a connection that fails within 60 seconds keeps the backoff', () {
      var now = DateTime(1);
      final retry = StreamingRetryState(random: MockRandom(), now: () => now);
      retry.recordFailure(unexpected: true);

      // Receive a message.
      retry.recordMessage();
      // Fail 59 seconds later.
      now = now.add(const Duration(seconds: 59));
      retry.recordFailure(unexpected: false);
      // The longer backoff continues.
      expect(retry.nextDelay(), const Duration(minutes: 10));
    });
  });
}
