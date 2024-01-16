import 'package:launchdarkly_dart_client/ld_client.dart';
import 'package:test/test.dart';

final class TestConfig extends LDCommonConfig {
  TestConfig(super.sdkCredential, super.autoEnvAttributes,
      {super.applicationInfo,
      super.httpProperties,
      super.serviceEndpoints,
      super.events,
      super.persistence,
      super.offline,
      super.logger,
      super.dataSourceConfig});
}

void main() {
  test('it has valid defaults', () {
    final config = TestConfig('', AutoEnvAttributes.enabled);
    // Top level config.
    expect(config.offline, false);
    expect(config.applicationInfo, isNull);
    expect(config.allAttributesPrivate, isFalse);
    expect(config.globalPrivateAttributes, isEmpty);

    // Data source config.
    expect(config.dataSourceConfig.evaluationReasons, isFalse);
    expect(config.dataSourceConfig.useReport, isFalse);
    expect(config.dataSourceConfig.initialConnectionMode,
        ConnectionMode.streaming);
    expect(
        config.dataSourceConfig.polling.pollingInterval, Duration(minutes: 5));

    // Logging
    expect(config.logger.logTag, 'LaunchDarkly');
    expect(config.logger.level, LDLogLevel.info);

    // Persistence
    expect(config.persistence.maxCachedContexts, 5);

    // Endpoints
    expect(config.serviceEndpoints.defaultPolling,
        'https://clientsdk.launchdarkly.com');
    expect(config.serviceEndpoints.defaultEvents,
        'https://mobile.launchdarkly.com');
    expect(config.serviceEndpoints.defaultEvents,
        'https://mobile.launchdarkly.com');

    // Http properties
    expect(config.httpProperties.readTimeout, Duration(seconds: 10));
    expect(config.httpProperties.connectTimeout, Duration(seconds: 10));
    expect(config.httpProperties.writeTimeout, Duration(seconds: 10));

    expect(config.httpProperties.baseHeaders, isEmpty);
  });

  test('can set credential', () {
    final config = TestConfig('credential', AutoEnvAttributes.enabled);
    expect(config.sdkCredential, 'credential');
  });

  test('can set AutoEnvAttributes', () {
    final config = TestConfig('credential', AutoEnvAttributes.enabled);
    expect(config.autoEnvAttributes, AutoEnvAttributes.enabled);

    final config2 = TestConfig('credential', AutoEnvAttributes.disabled);
    expect(config2.autoEnvAttributes, AutoEnvAttributes.disabled);
  });

  test('can set offline', () {
    final config = TestConfig('', AutoEnvAttributes.disabled, offline: true);
    expect(config.offline, true);
  });
}
