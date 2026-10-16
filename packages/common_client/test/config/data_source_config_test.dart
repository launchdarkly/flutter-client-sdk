import 'package:launchdarkly_common_client/src/config/data_source_config.dart';
import 'package:test/test.dart';

void main() {
  group('given different options', () {
    final vectors = [
      [10, false, false, '1'],
      [11, false, true, '2'],
      [12, true, false, '3']
    ];

    for (var testParams in vectors) {
      test('can create basic polling config: $testParams', () {
        final [pollingInterval, withReasons, useReport, credential] =
            testParams;
        final config = PollingDataSourceConfig(
            pollingInterval: Duration(minutes: pollingInterval as int),
            withReasons: withReasons as bool,
            useReport: useReport as bool);
        expect(config.pollingInterval.inMinutes, pollingInterval);
        expect(config.useReport, useReport);
        expect(config.withReasons, withReasons);

        // This will be the io platform defaults.
        expect(config.pollingGetPath(credential as String, 'this-is-a-context'),
            '/msdk/evalx/contexts/this-is-a-context');
        expect(config.pollingReportPath(credential, 'this-is-a-context'),
            '/msdk/evalx/context');
      });
    }
  });

  group('the polling interval minimum', () {
    test('a public config uses the minimum for a shorter interval', () {
      final config =
          PollingDataSourceConfig(pollingInterval: const Duration(seconds: 1));
      expect(config.pollingInterval, const Duration(minutes: 5));
    });

    test('the test hook removes the minimum when asserts are enabled', () {
      var assertsEnabled = false;
      assert(assertsEnabled = true);
      expect(assertsEnabled, isTrue,
          reason: 'the hook has an effect only when asserts are enabled');

      PollingDataSourceConfig.ignorePollingMinimum = true;
      addTearDown(() => PollingDataSourceConfig.ignorePollingMinimum = false);

      final config =
          PollingDataSourceConfig(pollingInterval: const Duration(seconds: 1));
      expect(config.pollingInterval, const Duration(seconds: 1));
    });

    for (final interval in [Duration.zero, const Duration(seconds: -1)]) {
      test('the test hook uses the default for an interval of $interval', () {
        PollingDataSourceConfig.ignorePollingMinimum = true;
        addTearDown(() => PollingDataSourceConfig.ignorePollingMinimum = false);

        expect(
            PollingDataSourceConfig(pollingInterval: interval).pollingInterval,
            const Duration(minutes: 5));
      });
    }

    test('the test hook keeps the default when no interval is given', () {
      PollingDataSourceConfig.ignorePollingMinimum = true;
      addTearDown(() => PollingDataSourceConfig.ignorePollingMinimum = false);

      expect(PollingDataSourceConfig().pollingInterval,
          const Duration(minutes: 5));
    });
  });
}
