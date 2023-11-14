import 'package:launchdarkly_event_source_client/src/state_backoff.dart';
import 'package:test/test.dart';

void main() {
  test('Test calculateDelayUpperBound', () async {
    // input is attempt count, output is max delay
    final cases = {
      1: 1000,
      2: 2000,
      3: 4000,
      4: 8000,
      5: 16000,
      6: 30000, // max delay
      7: 30000 // max delay
    };

    cases.forEach((input, expected) =>
        expect(StateBackoff.calculateDelayUpperBound(input), expected));
  });
}
