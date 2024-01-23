import 'package:launchdarkly_common_client/launchdarkly_common_client.dart';
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
  group('given an offline client', () {
    late LDCommonClient client;

    setUp(() {
      client = LDCommonClient(
          TestConfig('', AutoEnvAttributes.disabled, offline: true),
          CommonPlatform(),
          LDContextBuilder().kind('user', 'bob').build(),
          DiagnosticSdkData(name: '', version: ''));
    });

    test('client can start successfully', () async {
      expect(await client.start(), true);
    });

    test('client reports initialized after start', () async {
      await client.start();
      expect(client.initialized, isTrue);
    });

    test('client is not initialized before start', () {
      expect(client.initialized, isFalse);
    });

    test('can get default variations', () async {
      await client.start();
      expect(client.boolVariation('flagA', false), false);
      expect(client.stringVariation('flagB', 'default'), 'default');
      expect(client.intVariation('flagC', 3), 3);
      expect(client.doubleVariation('flag4', 3.14), closeTo(3.14, 0.01));
    });

    test('can get default detailed variations', () async {
      await client.start();
      expect(client.boolVariationDetail('flagA', false).value, false);
      expect(client.boolVariationDetail('flagA', false).reason,
          LDEvaluationReason.flagNotFound());

      expect(client.stringVariationDetail('flagB', 'default').value, 'default');
      expect(client.intVariationDetail('flagC', 3).value, 3);
      expect(client.doubleVariationDetail('flag4', 3.14).value,
          closeTo(3.14, 0.01));
    });

    test('variation calls without calling start do not crash', () {
      expect(client.boolVariation('flagA', false), false);
      expect(client.stringVariation('flagB', 'default'), 'default');
      expect(client.intVariation('flagC', 3), 3);
      expect(client.doubleVariation('flag4', 3.14), closeTo(3.14, 0.01));
      expect(client.boolVariationDetail('flagA', false).value, false);
      expect(client.boolVariationDetail('flagA', false).reason,
          LDEvaluationReason.flagNotFound());
      expect(client.stringVariationDetail('flagB', 'default').value, 'default');
      expect(client.intVariationDetail('flagC', 3).value, 3);
      expect(client.doubleVariationDetail('flag4', 3.14).value,
          closeTo(3.14, 0.01));
    });

    test('can get offline status', () {
      expect(client.offline, isTrue);
    });

    test('identify completes', () async {
      await client.start();
      expect(
          await client
              .identify(LDContextBuilder().kind('user', 'sally').build()),
          isA<IdentifyComplete>());
    });

    test('identify produces an error if start is not complete', () async {
      expect(
          await client
              .identify(LDContextBuilder().kind('user', 'sally').build()),
          isA<IdentifyError>());
    });

    test('multiple identify calls may be shed', () async {
      client.start();
      final future1 =
          client.identify(LDContextBuilder().kind('user', 'sally').build());
      final future2 =
          client.identify(LDContextBuilder().kind('user', 'nancy').build());
      expect(await future1, isA<IdentifySuperseded>());
      expect(await future2, isA<IdentifyComplete>());
    });

    test('can close', () async {
      // Should complete without error and not timeout.
      await client.close();
    });

    test('can flush', () async {
      // Should complete without error and not timeout.
      await client.flush();
    });

    test('allFlags has no flags', () async {
      await client.start();
      expect(client.allFlags(), isEmpty);
    });

    test('can call track', () {
      // No exceptions.
      client.track('name', data: LDValue.ofString('data'), metricValue: 17);
    });

    test('can set network availability', () {
      // No exceptions.
      client.setNetworkAvailability(false);
      client.setNetworkAvailability(true);
    });

    test('can set mode', () {
      // No exceptions.
      client.setMode(ConnectionMode.offline);
      client.setMode(ConnectionMode.streaming);
      client.setMode(ConnectionMode.polling);
    });

    test('can set event sending on/off', () {
      // No exceptions.
      client.setEventSendingEnabled(true);
      client.setEventSendingEnabled(false, flush: true);
      client.setEventSendingEnabled(false);
    });

    test('can call flush', () async {
      // No exceptions and completes without timeout.
      await client.flush();
    });
  });
}
