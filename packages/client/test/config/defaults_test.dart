import 'package:launchdarkly_dart_client/src/config/defaults/io_config.dart'
    as io_config;
import 'package:launchdarkly_dart_client/src/config/defaults/js_config.dart'
    as js_config;
import 'package:test/test.dart';

void main() {
  test('it correctly generates paths for io platforms', () {
    final paths = io_config.DefaultPollingPaths();
    final pollingReport =
        paths.pollingReportPath('sdk-key', 'this-is-a-context');
    final pollingGet = paths.pollingGetPath('sdk-key', 'this-is-a-context');

    expect(pollingReport, '/msdk/evalx/context');
    expect(pollingGet, '/msdk/evalx/contexts/this-is-a-context');
  });

  test('it correctly generates paths for web platforms', () {
    final paths = js_config.DefaultPollingPaths();
    final pollingReport =
        paths.pollingReportPath('sdk-key', 'this-is-a-context');
    final pollingGet = paths.pollingGetPath('sdk-key', 'this-is-a-context');

    expect(pollingReport, '/sdk/evalx/sdk-key/context');
    expect(pollingGet, '/sdk/evalx/sdk-key/contexts/this-is-a-context');
  });
}
