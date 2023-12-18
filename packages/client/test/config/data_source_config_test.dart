import 'package:launchdarkly_dart_client/src/config/data_source_config.dart';
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
        expect(
            config.pollingReportPath(credential, 'this-is-a-context'),
            '/msdk/evalx/contexts');
      });
    }
  });
}
