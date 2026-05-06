import 'package:launchdarkly_common_client/src/data_sources/fdv2/calculate_poll_delay.dart';
import 'package:test/test.dart';

void main() {
  final t0 = DateTime.utc(2026, 1, 1, 12, 0, 0);
  const interval = Duration(seconds: 30);

  test('null freshness returns the full interval', () {
    expect(
      calculatePollDelay(now: t0, interval: interval, freshness: null),
      equals(interval),
    );
  });

  test('freshness equal to now returns the full interval', () {
    expect(
      calculatePollDelay(now: t0, interval: interval, freshness: t0),
      equals(interval),
    );
  });

  test('freshness within the interval returns the time remaining', () {
    expect(
      calculatePollDelay(
        now: t0,
        interval: interval,
        freshness: t0.subtract(const Duration(seconds: 10)),
      ),
      equals(const Duration(seconds: 20)),
    );
  });

  test('freshness exactly one interval ago returns zero', () {
    expect(
      calculatePollDelay(
        now: t0,
        interval: interval,
        freshness: t0.subtract(interval),
      ),
      equals(Duration.zero),
    );
  });

  test('freshness older than the interval returns zero', () {
    expect(
      calculatePollDelay(
        now: t0,
        interval: interval,
        freshness: t0.subtract(const Duration(minutes: 5)),
      ),
      equals(Duration.zero),
    );
  });

  test('freshness in the future is clamped to the full interval', () {
    expect(
      calculatePollDelay(
        now: t0,
        interval: interval,
        freshness: t0.add(const Duration(minutes: 5)),
      ),
      equals(interval),
    );
  });
}
