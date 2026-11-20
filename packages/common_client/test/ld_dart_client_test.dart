import 'dart:async';
import 'dart:convert';

import 'package:crypto/crypto.dart';
import 'package:launchdarkly_common_client/launchdarkly_common_client.dart';
import 'package:launchdarkly_common_client/src/data_sources/data_source.dart';
import 'package:launchdarkly_dart_common/launchdarkly_dart_common.dart'
    show ConcreteEnvReporter;
import 'package:test/test.dart';

import 'mock_eventprocessor.dart';
import 'mock_persistence.dart';

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

final class TestDataSource implements DataSource {
  static const defaultPayload = '{"flagA":{'
      '"version":11,'
      '"flagVersion":1,'
      '"value":"datasource",'
      '"variation":0,'
      '"reason":{"kind":"OFF"}'
      '}}';

  final StreamController<DataSourceEvent> _eventController = StreamController();

  /// The data of the put event that this data source sends when it starts.
  final String payload;

  TestDataSource({this.payload = defaultPayload});

  @override
  Stream<DataSourceEvent> get events => _eventController.stream;

  @override
  void restart() {}

  @override
  void start() {
    Timer(Duration(milliseconds: 10), () {
      _eventController.sink.add(DataEvent('put', payload));
    });
  }

  @override
  void stop() {
    _eventController.close();
  }
}

/// A data source that never sends events.
final class SilentDataSource implements DataSource {
  final StreamController<DataSourceEvent> _eventController = StreamController();

  @override
  Stream<DataSourceEvent> get events => _eventController.stream;

  @override
  void restart() {}

  @override
  void start() {}

  @override
  void stop() {
    _eventController.close();
  }
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

    test('can set resolved FDv2 mode', () {
      // No exceptions.
      client.setResolvedMode(const ResolvedOffline(OfflineSetOffline()));
      client.setResolvedMode(const ResolvedStreaming());
      client.setResolvedMode(const ResolvedPolling());
      client.setResolvedMode(const ResolvedBackground());
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

  group('given a mock data source', () {
    late LDCommonClient client;
    late MockPersistence mockPersistence;
    final sdkKey = 'the-sdk-key';
    final sdkKeyPersistence =
        'LaunchDarkly_${sha256.convert(utf8.encode(sdkKey))}';

    setUp(() {
      mockPersistence = MockPersistence();
      client = LDCommonClient(
          TestConfig(sdkKey, AutoEnvAttributes.disabled),
          CommonPlatform(persistence: mockPersistence),
          LDContextBuilder().kind('user', 'bob').build(),
          DiagnosticSdkData(name: '', version: ''), dataSourceFactories:
              (LDCommonConfig config, LDLogger logger,
                  HttpProperties properties) {
        return {
          ConnectionMode.streaming: (LDContext context) {
            return TestDataSource();
          },
          ConnectionMode.polling: (LDContext context) {
            return TestDataSource();
          },
        };
      });
    });

    test('identify can resolve cached values', () async {
      final contextPersistenceKey =
          sha256.convert(utf8.encode('joe')).toString();
      mockPersistence.storage[sdkKeyPersistence] = {
        contextPersistenceKey: '{"flagA":{'
            '"version":1,'
            '"value":"storage",'
            '"variation":0,'
            '"reason":{"kind":"OFF"}'
            '}}'
      };
      // We are going to ignore the items for the first context.
      await client.start();

      await client.identify(LDContextBuilder().kind('user', 'joe').build());
      final res = client.stringVariation('flagA', 'default');
      expect(res, 'storage');
    });

    test('identify can resolve non-cached values', () async {
      final contextPersistenceKey =
          sha256.convert(utf8.encode('joe')).toString();
      mockPersistence.storage[sdkKeyPersistence] = {
        contextPersistenceKey: '{"flagA":{'
            '"version":1,'
            '"value":"storage",'
            '"variation":0,'
            '"reason":{"kind":"OFF"}'
            '}}'
      };
      // We are going to ignore the items for the first context.
      await client.start();

      await client.identify(LDContextBuilder().kind('user', 'joe').build(),
          waitForNetworkResults: true);
      final res = client.stringVariation('flagA', 'default');
      expect(res, 'datasource');
    });

    test('start can resolve cached values', () async {
      final contextPersistenceKey =
          sha256.convert(utf8.encode('bob')).toString();
      mockPersistence.storage[sdkKeyPersistence] = {
        contextPersistenceKey: '{"flagA":{'
            '"version":1,'
            '"value":"storage",'
            '"variation":0,'
            '"reason":{"kind":"OFF"}'
            '}}'
      };

      await client.start();
      final res = client.stringVariation('flagA', 'default');
      expect(res, 'storage');
    });

    test('start can resolve non-cached values', () async {
      final contextPersistenceKey =
          sha256.convert(utf8.encode('bob')).toString();
      mockPersistence.storage[sdkKeyPersistence] = {
        contextPersistenceKey: '{"flagA":{'
            '"version":1,'
            '"value":"storage",'
            '"variation":0,'
            '"reason":{"kind":"OFF"}'
            '}}'
      };

      await client.start(waitForNetworkResults: true);
      final res = client.stringVariation('flagA', 'default');
      expect(res, 'datasource');
    });
  });

  group('given a data source that sends data only for bob', () {
    late LDCommonClient client;

    setUp(() {
      client = LDCommonClient(
          TestConfig('the-sdk-key', AutoEnvAttributes.disabled),
          CommonPlatform(persistence: MockPersistence()),
          LDContextBuilder().kind('user', 'bob').build(),
          DiagnosticSdkData(name: '', version: ''), dataSourceFactories:
              (LDCommonConfig config, LDLogger logger,
                  HttpProperties properties) {
        DataSource factory(LDContext context) => context.canonicalKey == 'bob'
            ? TestDataSource()
            : SilentDataSource();
        return {
          ConnectionMode.streaming: factory,
          ConnectionMode.polling: factory,
        };
      });
    });

    test('close completes a pending identify with an error', () async {
      await client.start();
      final identify =
          client.identify(LDContextBuilder().kind('user', 'joe').build());

      await client.close();

      final result = await identify.timeout(const Duration(seconds: 1));
      expect(result, isA<IdentifyError>());
      expect((result as IdentifyError).error.toString(),
          contains('The client was closed before the identify completed.'));
    });

    test('close completes a pending start with false', () async {
      final otherClient = LDCommonClient(
          TestConfig('the-sdk-key', AutoEnvAttributes.disabled),
          CommonPlatform(persistence: MockPersistence()),
          LDContextBuilder().kind('user', 'joe').build(),
          DiagnosticSdkData(name: '', version: ''), dataSourceFactories:
              (LDCommonConfig config, LDLogger logger,
                  HttpProperties properties) {
        return {
          ConnectionMode.streaming: (_) => SilentDataSource(),
          ConnectionMode.polling: (_) => SilentDataSource(),
        };
      });
      final start = otherClient.start();

      await otherClient.close();

      expect(await start.timeout(const Duration(seconds: 1)), isFalse);
    });

    test('close does not change a completed identify or start', () async {
      expect(await client.start(), isTrue);
      expect(
          await client.identify(LDContextBuilder().kind('user', 'bob').build()),
          isA<IdentifyComplete>());

      await client.close();

      expect(await client.start(), isTrue);
    });
  });

  group('given an invalid context', () {
    test('start returns false with invalid context', () async {
      final invalidClient = LDCommonClient(
          TestConfig('', AutoEnvAttributes.disabled, offline: true),
          CommonPlatform(),
          LDContextBuilder()
              .kind('invalid#kind', '') // invalid kind and invalid key
              .build(),
          DiagnosticSdkData(name: '', version: ''));

      expect(await invalidClient.start(), false);
    });

    test('identify returns IdentifyError with invalid context', () async {
      final invalidClient = LDCommonClient(
          TestConfig('', AutoEnvAttributes.disabled, offline: true),
          CommonPlatform(),
          LDContextBuilder()
              .kind('user', 'bob')
              .build(), // Valid initial context
          DiagnosticSdkData(name: '', version: ''));

      await invalidClient.start();

      final invalidContext = LDContextBuilder()
          .kind('invalid#kind', '') // invalid kind and invalid key
          .build();

      expect(
          await invalidClient.identify(invalidContext), isA<IdentifyError>());

      // check subsequent identify with valid context is accepted
      final validContext = LDContextBuilder().kind('user', 'alice').build();

      final identifyResult = await invalidClient.identify(validContext);
      expect(identifyResult, isA<IdentifyComplete>());
    });
  });

  group('given mock flag data with prerequisites', () {
    late LDCommonClient client;
    late MockPersistence mockPersistence;
    late MockEventProcessor mockEventProcessor;
    final sdkKey = 'the-sdk-key';
    final sdkKeyPersistence =
        'LaunchDarkly_${sha256.convert(utf8.encode(sdkKey))}';

    setUp(() {
      mockPersistence = MockPersistence();
      mockEventProcessor = MockEventProcessor();
      client = LDCommonClient(
        TestConfig(sdkKey, AutoEnvAttributes.disabled),
        CommonPlatform(persistence: mockPersistence),
        LDContextBuilder().kind('user', 'bob').build(),
        DiagnosticSdkData(name: '', version: ''),
        dataSourceFactories: (LDCommonConfig config, LDLogger logger,
            HttpProperties properties) {
          return {
            ConnectionMode.streaming: (LDContext context) {
              return TestDataSource();
            },
            ConnectionMode.polling: (LDContext context) {
              return TestDataSource();
            },
          };
        },
        eventProcessorFactory: (
                {required allAttributesPrivate,
                required analyticsEventsPath,
                required client,
                required diagnosticEventsPath,
                required diagnosticRecordingInterval,
                diagnosticsManager,
                required endpoints,
                required eventCapacity,
                required flushInterval,
                required globalPrivateAttributes,
                required indexEvents,
                required logger}) =>
            mockEventProcessor,
      );
    });

    test('it reports events for each prerequisite', () async {
      final contextPersistenceKey =
          sha256.convert(utf8.encode('bob')).toString();
      mockPersistence.storage[sdkKeyPersistence] = {
        contextPersistenceKey:
            '{"flagA":{"version":1,"value":"storage","variation":0,"reason":{"kind":"OFF"},"prerequisites":["flagAB"]},"flagAB":{"version":1,"value":"storage","variation":0,"reason":{"kind":"OFF"}}}'
      };

      await client
          .start(); // note no call to wait for network results here so we get the storage values
      final res = client.stringVariation('flagA', 'default');
      expect(res, 'storage');
      expect(mockEventProcessor.evalEvents.length, 2);
      expect(mockEventProcessor.evalEvents[0].flagKey, 'flagAB');
      expect(mockEventProcessor.evalEvents[1].flagKey, 'flagA');
    });

    // Cycle-detection tests exercise the ancestor-set cycle guard added to
    // _variationInternal. Each test constructs a cyclic prereq graph via the
    // storage fixture, evaluates one flag on the cycle, and asserts (a) the
    // requested flag returns its cached value unchanged and (b) the recorded
    // evaluation events match exactly one entry per cycle-safe descent.
    Future<void> runCycleCase(String storageJson, String evalKey,
        List<String> expectedEventKeys) async {
      final contextPersistenceKey =
          sha256.convert(utf8.encode('bob')).toString();
      mockPersistence.storage[sdkKeyPersistence] = {
        contextPersistenceKey: storageJson,
      };
      await client.start();
      final res = client.stringVariation(evalKey, 'default');
      expect(res, 'cached');
      expect(mockEventProcessor.evalEvents.map((e) => e.flagKey).toList(),
          expectedEventKeys);
    }

    test('skips a self-loop prerequisite and returns the cached value',
        () async {
      // flagA's only prerequisite is itself; the cycle guard skips descent.
      await runCycleCase(
        '{"flagA":{"version":1,"value":"cached","variation":0,"reason":{"kind":"OFF"},"prerequisites":["flagA"]}}',
        'flagA',
        ['flagA'],
      );
    });

    test('handles a two-cycle evaluating A', () async {
      // A -> B -> [A skipped]. Events deepest-first: B (as prereq of A), then A.
      await runCycleCase(
        '{"flagA":{"version":1,"value":"cached","variation":0,"reason":{"kind":"OFF"},"prerequisites":["flagB"]},"flagB":{"version":1,"value":"cached","variation":0,"reason":{"kind":"OFF"},"prerequisites":["flagA"]}}',
        'flagA',
        ['flagB', 'flagA'],
      );
    });

    test('handles a two-cycle evaluating B', () async {
      // Symmetric: same graph, entry from B. Events: A (as prereq of B), then B.
      await runCycleCase(
        '{"flagA":{"version":1,"value":"cached","variation":0,"reason":{"kind":"OFF"},"prerequisites":["flagB"]},"flagB":{"version":1,"value":"cached","variation":0,"reason":{"kind":"OFF"},"prerequisites":["flagA"]}}',
        'flagB',
        ['flagA', 'flagB'],
      );
    });

    test('handles a three-cycle', () async {
      // A -> B -> C -> [A skipped]. Events emitted deepest-first: C, B, A.
      await runCycleCase(
        '{"flagA":{"version":1,"value":"cached","variation":0,"reason":{"kind":"OFF"},"prerequisites":["flagB"]},"flagB":{"version":1,"value":"cached","variation":0,"reason":{"kind":"OFF"},"prerequisites":["flagC"]},"flagC":{"version":1,"value":"cached","variation":0,"reason":{"kind":"OFF"},"prerequisites":["flagA"]}}',
        'flagA',
        ['flagC', 'flagB', 'flagA'],
      );
    });

    test('emits the shared descendant once per path in a non-cyclic diamond',
        () async {
      // Diamond: A -> [B, C], B -> [D], C -> [D]. Not a cycle. Ancestor-set
      // (current-path) semantics let D be reached on each of the two independent
      // paths, so D emits twice. A naive "visited across the whole walk"
      // implementation would drop the second event; this case guards against
      // that regression.
      await runCycleCase(
        '{"flagA":{"version":1,"value":"cached","variation":0,"reason":{"kind":"OFF"},"prerequisites":["flagB","flagC"]},"flagB":{"version":1,"value":"cached","variation":0,"reason":{"kind":"OFF"},"prerequisites":["flagD"]},"flagC":{"version":1,"value":"cached","variation":0,"reason":{"kind":"OFF"},"prerequisites":["flagD"]},"flagD":{"version":1,"value":"cached","variation":0,"reason":{"kind":"OFF"}}}',
        'flagA',
        ['flagD', 'flagB', 'flagD', 'flagC', 'flagA'],
      );
    });
  });

  group('given a flag with no value', () {
    late LDCommonClient client;

    Future<void> startWithFlag(String flagJson) async {
      client = LDCommonClient(
          TestConfig('the-sdk-key', AutoEnvAttributes.disabled,
              events: EventsConfig(disabled: true)),
          CommonPlatform(persistence: MockPersistence()),
          LDContextBuilder().kind('user', 'bob').build(),
          DiagnosticSdkData(name: '', version: ''), dataSourceFactories:
              (LDCommonConfig config, LDLogger logger,
                  HttpProperties properties) {
        return {
          ConnectionMode.streaming: (LDContext context) =>
              TestDataSource(payload: '{"flagA":$flagJson}'),
          ConnectionMode.polling: (LDContext context) =>
              TestDataSource(payload: '{"flagA":$flagJson}'),
        };
      });
      await client.start(waitForNetworkResults: true);
    }

    tearDown(() async {
      await client.close();
    });

    for (final (name, flagJson) in [
      (
        'a null value',
        '{"version":1,"value":null,"variation":null,"reason":{"kind":"OFF"}}'
      ),
      ('an omitted value', '{"version":1,"reason":{"kind":"OFF"}}'),
    ]) {
      test('jsonVariation returns the default value for $name', () async {
        await startWithFlag(flagJson);
        // Evaluate the flag without a type.
        final value =
            client.jsonVariation('flagA', LDValue.ofString('default'));
        // The application gets its default value, not JSON null.
        expect(value, LDValue.ofString('default'));
      });

      test(
          'jsonVariationDetail returns the default value and the flag reason '
          'for $name', () async {
        await startWithFlag(flagJson);
        // Evaluate the flag without a type, with details.
        final detail =
            client.jsonVariationDetail('flagA', LDValue.ofString('default'));
        // The value is the default value, and the reason comes from the flag.
        expect(detail.value, LDValue.ofString('default'));
        expect(detail.variationIndex, isNull);
        expect(detail.reason, LDEvaluationReason.off());
      });
    }
  });

  group('given configured application info', () {
    final platformApplicationInfo = ApplicationInfo(
        applicationId: 'platform-id', applicationVersion: 'platform-version');

    Future<String?> tagsHeaderFor(ApplicationInfo applicationInfo,
        AutoEnvAttributes autoEnvAttributes) async {
      final headers = Completer<Map<String, String>>();
      final client = LDCommonClient(
          TestConfig('the-sdk-key', autoEnvAttributes,
              applicationInfo: applicationInfo,
              events: EventsConfig(disabled: true)),
          CommonPlatform(
              persistence: MockPersistence(),
              platformEnvReporter: ConcreteEnvReporter(
                  applicationInfo: Future.value(platformApplicationInfo),
                  osInfo: Future.value(null),
                  deviceInfo: Future.value(null),
                  locale: Future.value(null))),
          LDContextBuilder().kind('user', 'bob').build(),
          DiagnosticSdkData(name: '', version: ''), dataSourceFactories:
              (LDCommonConfig config, LDLogger logger,
                  HttpProperties properties) {
        if (!headers.isCompleted) {
          headers.complete(properties.baseHeaders);
        }
        return {
          ConnectionMode.streaming: (LDContext context) => TestDataSource(),
          ConnectionMode.polling: (LDContext context) => TestDataSource(),
        };
      });
      await client.start();
      final tags = (await headers.future)['X-LaunchDarkly-Tags'];
      await client.close();
      return tags;
    }

    test('uses the configured application info over the platform values',
        () async {
      // Start with a valid configured ID while automatic attributes are on.
      final tags = await tagsHeaderFor(
          ApplicationInfo(
              applicationId: 'configured-id',
              applicationVersion: 'configured-version'),
          AutoEnvAttributes.enabled);
      // The configured values are sent.
      expect(tags,
          'application-id/configured-id application-version/configured-version');
    });

    test('uses the platform application info when the configured ID is invalid',
        () async {
      // Start with an ID that has a disallowed character.
      final tags = await tagsHeaderFor(
          ApplicationInfo(
              applicationId: 'invalid#id',
              applicationVersion: 'configured-version'),
          AutoEnvAttributes.enabled);
      // The platform ID and version are sent in place of the configured info.
      expect(tags,
          'application-id/platform-id application-version/platform-version');
    });

    test(
        'sends no application info when the configured ID is invalid and '
        'automatic attributes are off', () async {
      // Start with an ID that has a disallowed character.
      final tags = await tagsHeaderFor(
          ApplicationInfo(
              applicationId: 'invalid#id',
              applicationVersion: 'configured-version'),
          AutoEnvAttributes.disabled);
      // The configured version is not sent without an ID.
      expect(tags, isNull);
    });
  });
}
