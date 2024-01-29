import 'dart:math' as math;

import 'package:launchdarkly_event_source_client/src/backoff.dart';
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
  test('it starts with the delay at initial', () {
    final mockRandom = MockRandom();
    final backoff = Backoff(mockRandom);
    expect(backoff.getRetryDelay(null), 1000);
  });

  test('delay doubles consecutive failures', () {
    final mockRandom = MockRandom();
    final backoff = Backoff(mockRandom);

    expect(backoff.getRetryDelay(null), 1000);
    expect(backoff.getRetryDelay(null), 2000);
  });

  test('the backoff respects the max', () {
    final mockRandom = MockRandom();
    final backoff = Backoff(mockRandom);
    expect(backoff.getRetryDelay(null), 1000);
    expect(backoff.getRetryDelay(null), 2000);
    expect(backoff.getRetryDelay(null), 4000);
    expect(backoff.getRetryDelay(null), 8000);
    expect(backoff.getRetryDelay(null), 16000);
    expect(backoff.getRetryDelay(null), 30000);
  });

  test('it jitters the backoff value', () {
    // The random value will always be be 0. So we expect half delays.
    final mockRandom = MockRandom(ratio: 0);
    final backoff = Backoff(mockRandom);

    expect(backoff.getRetryDelay(null), 500);
    expect(backoff.getRetryDelay(null), 1000);
    expect(backoff.getRetryDelay(null), 2000);
    expect(backoff.getRetryDelay(null), 4000);
    expect(backoff.getRetryDelay(null), 8000);
    expect(backoff.getRetryDelay(null), 15000);

    // Expect 3/4 delay
    final mockRandom2 = MockRandom(ratio: 0.5);
    final backoff2 = Backoff(mockRandom2);

    expect(backoff2.getRetryDelay(null), 750);
    expect(backoff2.getRetryDelay(null), 1500);
    expect(backoff2.getRetryDelay(null), 3000);
    expect(backoff2.getRetryDelay(null), 6000);
    expect(backoff2.getRetryDelay(null), 12000);
    expect(backoff2.getRetryDelay(null), 22500);
  });

  test('resets after 60 seconds of active connection', () {
    final mockRandom = MockRandom();
    final backoff = Backoff(mockRandom);

    // Calculate a couple backoff to get away from 0.
    expect(backoff.getRetryDelay(null), 1000);

    // Only active 30 seconds, not enough to reset.
    final activeSince30s = DateTime.now().subtract(Duration(seconds: 30));
    expect(backoff.getRetryDelay(activeSince30s.millisecondsSinceEpoch), 2000);

    final activeSince60s = DateTime.now().subtract(Duration(seconds: 60));
    expect(backoff.getRetryDelay(activeSince60s.millisecondsSinceEpoch), 1000);
  });

  test('handles max exponent correctly', () {
    final mockRandom = MockRandom();
    final backoff = Backoff(mockRandom);
    for (var attempt = 0; attempt < 1000; attempt++) {
      expect(backoff.getRetryDelay(null), lessThanOrEqualTo(30000));
    }
  });

  test('handles initial delay greater than max delay', () {
    final mockRandom = MockRandom();
    final backoff = Backoff(mockRandom, initialReconnectDelay: 100000);
    expect(backoff.getRetryDelay(null), 30000);
  });

  test('handles initial equal to max', () {
    final mockRandom = MockRandom();
    final backoff = Backoff(mockRandom, initialReconnectDelay: 30000);
    expect(backoff.getRetryDelay(null), 30000);
  });
}
