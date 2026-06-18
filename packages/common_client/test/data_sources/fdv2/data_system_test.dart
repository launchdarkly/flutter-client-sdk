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
      cachedFlagsReader: (_) async => null,
    );

LDContext _context() => LDContextBuilder().kind('user', 'bob').build();

void main() {
  test('an empty data system config overrides no modes', () {
    expect(const DataSystemConfig().connectionModes, isEmpty);
  });

  test('buildFactories exposes streaming, polling, background, and offline',
      () {
    final factories = makeDataSystem().buildFactories();

    expect(
        factories.keys,
        containsAll(<FDv2ConnectionMode>[
          const FDv2Streaming(),
          const FDv2Polling(),
          const FDv2Background(),
          const FDv2Offline(),
        ]));
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

  test('an override is selected over the built-in for that mode', () {
    // The data system's job here is resolution: the overridden mode uses
    // the override definition, others keep their built-in. Translating a
    // definition's entries into concrete sources (e.g. that the polling
    // definition yields a polling source) is covered by entry_factories.
    final dataSystem = makeDataSystem(
        config: const DataSystemConfig(connectionModes: {
      ConnectionModeId.streaming: BuiltInModes.polling,
    }));

    expect(dataSystem.resolvedDefinition(ConnectionModeId.streaming),
        same(BuiltInModes.polling),
        reason: 'the override replaces the built-in streaming definition');
    expect(dataSystem.resolvedDefinition(ConnectionModeId.polling),
        same(BuiltInModes.polling),
        reason: 'an un-overridden mode keeps its built-in');
    expect(dataSystem.resolvedDefinition(ConnectionModeId.offline),
        same(BuiltInModes.offline));
  });

  test('the override map is keyed only by built-in modes', () {
    // ConnectionModeId is a sealed type whose only nameable values are the
    // built-in modes, so a custom/arbitrary mode name cannot be expressed
    // as a key. Providing an override for a built-in resolves; the others
    // keep their built-in definitions.
    const config = DataSystemConfig(connectionModes: {
      ConnectionModeId.polling: BuiltInModes.streaming,
    });
    final factories = makeDataSystem(config: config).buildFactories();
    expect(factories.keys, hasLength(4));
  });
}
