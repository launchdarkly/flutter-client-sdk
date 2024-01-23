import 'package:launchdarkly_common_client/launchdarkly_common_client.dart';
import 'package:test/test.dart';

void main() {
  group('given different options', () {
    final vectors = [
      [false, Duration(seconds: 2), 1000, Duration(minutes: 6), false],
      [true, Duration(seconds: 10), 1000, Duration(minutes: 50), true],
    ];

    for (var testParams in vectors) {
      test('can create basic events config: $testParams', () {
        final [
          disabled,
          flushInterval,
          eventCapacity,
          diagnosticRecordingInterval,
          diagnosticOptOut
        ] = testParams;
        final config = EventsConfig(
            disabled: disabled as bool,
            flushInterval: flushInterval as Duration,
            eventCapacity: eventCapacity as int,
            diagnosticOptOut: diagnosticOptOut as bool,
            diagnosticRecordingInterval:
                diagnosticRecordingInterval as Duration);

        expect(config.disabled, disabled);
        expect(config.diagnosticRecordingInterval, diagnosticRecordingInterval);
        expect(config.flushInterval, flushInterval);
        expect(config.diagnosticOptOut, diagnosticOptOut);
        expect(config.eventCapacity, eventCapacity);
      });
    }
  });

  test('it enforced minimum diagnostic recording interval', () {
    final config =
        EventsConfig(diagnosticRecordingInterval: Duration(seconds: 5));

    expect(config.diagnosticRecordingInterval, Duration(minutes: 5));
  });

  test('it enforces 0 as min event capacity', () {
    final config = EventsConfig(eventCapacity: -1);

    expect(config.eventCapacity, 0);
  });

  test('zero or negative flush interval uses default', () {
    final config = EventsConfig(flushInterval: Duration(seconds: -1));

    expect(config.flushInterval, Duration(seconds: 30));

    final config2 = EventsConfig(flushInterval: Duration(seconds: 0));

    expect(config2.flushInterval, Duration(seconds: 30));
  });

  test('it has correct defaults', () {
    final config = EventsConfig();

    expect(config.disabled, false);
    expect(config.diagnosticRecordingInterval, Duration(minutes: 15));
    expect(config.flushInterval, Duration(seconds: 30));
    expect(config.diagnosticOptOut, false);
    expect(config.eventCapacity, 100);
  });
}
