import 'package:launchdarkly_common_client/src/config/data_system_config.dart';
import 'package:launchdarkly_common_client/src/config/service_endpoints.dart';
import 'package:launchdarkly_common_client/src/data_sources/data_source.dart';
import 'package:launchdarkly_common_client/src/data_sources/data_source_status_manager.dart';
import 'package:launchdarkly_common_client/src/data_sources/fdv2/built_in_modes.dart';
import 'package:launchdarkly_common_client/src/data_sources/fdv2/data_system.dart';
import 'package:launchdarkly_common_client/src/fdv2_connection_mode.dart';
import 'package:launchdarkly_dart_common/launchdarkly_dart_common.dart'
    hide ServiceEndpoints;
import 'package:test/test.dart';

FDv2DataSystem makeDataSystem(
        {DataSystemConfig config = const DataSystemConfig()}) =>
    FDv2DataSystem(
      config: config,
      credential: 'the-credential',
      logger: LDLogger(level: LDLogLevel.none),
      httpProperties: HttpProperties(),
      serviceEndpoints: ServiceEndpoints(),
      withReasons: false,
      defaultPollingInterval: const Duration(seconds: 300),
      statusManager: DataSourceStatusManager(),
    );

LDContext _context() => LDContextBuilder().kind('user', 'bob').build();

void main() {
  test('an empty data system config carries no custom modes', () {
    expect(const DataSystemConfig().customConnectionModes, isEmpty);
  });

  test('buildFactories exposes streaming, polling, and background', () {
    final factories = makeDataSystem().buildFactories();

    expect(
        factories.keys,
        containsAll(<FDv2ConnectionMode>[
          const FDv2Streaming(),
          const FDv2Polling(),
          const FDv2Background(),
        ]));
    expect(factories.containsKey(const FDv2Offline()), isFalse,
        reason: 'offline has no data source; the manager handles it directly');
  });

  test('a factory builds a data source, fresh on each call', () {
    final factory = makeDataSystem().buildFactories()[const FDv2Streaming()]!;
    final context = _context();

    final first = factory(context);
    final second = factory(context);

    expect(first, isA<DataSource>());
    expect(identical(first, second), isFalse,
        reason: 'a fresh orchestrator is created per connection');

    first.stop();
    second.stop();
  });

  test('a custom connection mode replaces the built-in definition', () {
    // Override streaming with the polling definition; the streaming
    // factory should still build a usable data source from it.
    final factory = makeDataSystem(
            config: const DataSystemConfig(
                customConnectionModes: {'streaming': BuiltInModes.polling}))
        .buildFactories()[const FDv2Streaming()]!;

    final source = factory(_context());
    expect(source, isA<DataSource>());
    source.stop();
  });
}
