import 'dart:convert';

import 'package:crypto/crypto.dart';
import 'package:launchdarkly_common_client/src/flag_manager/flag_persistence.dart';
import 'package:launchdarkly_common_client/src/flag_manager/flag_store.dart';
import 'package:launchdarkly_common_client/src/flag_manager/flag_updater.dart';
import 'package:launchdarkly_common_client/src/item_descriptor.dart';
import 'package:launchdarkly_dart_common/launchdarkly_dart_common.dart';
import 'package:test/test.dart';

import 'mock_persistence.dart';

const sdkKey = 'fake-sdk-key';
final sdkKeyPersistence = 'LaunchDarkly_${sha256.convert(utf8.encode(sdkKey))}';

void main() {
  final logger = LDLogger();
  final basicData = {
    'flagA': ItemDescriptor(
        version: 1,
        flag: LDEvaluationResult(
            version: 1,
            detail: LDEvaluationDetail(
                LDValue.ofString('test'), 0, LDEvaluationReason.off()))),
    'flagB': ItemDescriptor(
        version: 2,
        flag: LDEvaluationResult(
            version: 2,
            detail: LDEvaluationDetail(LDValue.ofString('test2'), 1,
                LDEvaluationReason.targetMatch())))
  };

  group('with persistence', () {
    test('it stores cache on init', () async {
      final flagStore = FlagStore();
      final mockPersistence = MockPersistence();
      final flagPersistence = FlagPersistence(
          persistence: mockPersistence,
          updater: FlagUpdater(flagStore: flagStore, logger: logger),
          store: flagStore,
          sdkKey: sdkKey,
          maxCachedContexts: 5,
          logger: logger,
          stamper: () => DateTime.fromMillisecondsSinceEpoch(0));

      final context = LDContextBuilder().kind('user', 'user-key').build();

      await flagPersistence.init(context, basicData);

      // 1 environment
      expect(mockPersistence.storage.length, 1);
      // 1 context and 1 index.
      expect(mockPersistence.storage.values.first.length, 2);

      final contextPersistenceKey =
          sha256.convert(utf8.encode(context.canonicalKey)).toString();

      // The context index.
      expect(mockPersistence.storage[sdkKeyPersistence]!['ContextIndex'],
          '{"index":[{"id":"$contextPersistenceKey","msTimestamp":0}]}');

      // The flags for the cached context.
      expect(
          mockPersistence.storage[sdkKeyPersistence]![contextPersistenceKey],
          '{"flagA":{'
          '"version":1,'
          '"value":"test",'
          '"variation":0,'
          '"reason":{"kind":"OFF"}'
          '},'
          '"flagB":{'
          '"version":2,'
          '"value":"test2",'
          '"variation":1,'
          '"reason":{"kind":"TARGET_MATCH"}'
          '}}');

      expect(flagStore.getAll().equals(basicData), true);
    });

    test('it updates cache on upsert', () async {
      final flagStore = FlagStore();
      final mockPersistence = MockPersistence();
      final flagPersistence = FlagPersistence(
          persistence: mockPersistence,
          updater: FlagUpdater(flagStore: flagStore, logger: logger),
          store: flagStore,
          sdkKey: sdkKey,
          maxCachedContexts: 5,
          logger: logger,
          stamper: () => DateTime.fromMillisecondsSinceEpoch(0));

      final context = LDContextBuilder().kind('user', 'user-key').build();

      await flagPersistence.init(context, basicData);
      final flagB = LDEvaluationResult(
          version: 3,
          detail: LDEvaluationDetail(
              LDValue.ofString('test3'), 1, LDEvaluationReason.targetMatch()));

      expect(
          await flagPersistence.upsert(
              context, 'flagB', ItemDescriptor(version: 3, flag: flagB)),
          true);

      // 1 environment
      expect(mockPersistence.storage.length, 1);
      // 1 context and 1 index.
      expect(mockPersistence.storage.values.first.length, 2);

      final contextPersistenceKey =
          sha256.convert(utf8.encode(context.canonicalKey)).toString();

      // The context index.
      expect(mockPersistence.storage[sdkKeyPersistence]!['ContextIndex'],
          '{"index":[{"id":"$contextPersistenceKey","msTimestamp":0}]}');

      // The flags for the cached context.
      expect(
          mockPersistence.storage[sdkKeyPersistence]![contextPersistenceKey],
          '{"flagA":{'
          '"version":1,'
          '"value":"test",'
          '"variation":0,'
          '"reason":{"kind":"OFF"}'
          '},'
          '"flagB":{'
          '"version":3,'
          '"value":"test3",'
          '"variation":1,'
          '"reason":{"kind":"TARGET_MATCH"}'
          '}}');
    });

    test('it discards out of order updates', () async {
      final flagStore = FlagStore();
      final mockPersistence = MockPersistence();
      final flagPersistence = FlagPersistence(
          persistence: mockPersistence,
          updater: FlagUpdater(flagStore: flagStore, logger: logger),
          store: flagStore,
          sdkKey: sdkKey,
          maxCachedContexts: 5,
          logger: logger,
          stamper: () => DateTime.fromMillisecondsSinceEpoch(0));

      final context = LDContextBuilder().kind('user', 'user-key').build();

      await flagPersistence.init(context, basicData);
      final flagB = LDEvaluationResult(
          version: 1,
          detail: LDEvaluationDetail(
              LDValue.ofString('test1'), 1, LDEvaluationReason.targetMatch()));

      expect(
          await flagPersistence.upsert(
              context, 'flagB', ItemDescriptor(version: 1, flag: flagB)),
          false);

      // 1 environment
      expect(mockPersistence.storage.length, 1);
      // 1 context and 1 index.
      expect(mockPersistence.storage.values.first.length, 2);

      final contextPersistenceKey =
          sha256.convert(utf8.encode(context.canonicalKey)).toString();

      // The context index.
      expect(mockPersistence.storage[sdkKeyPersistence]!['ContextIndex'],
          '{"index":[{"id":"$contextPersistenceKey","msTimestamp":0}]}');

      // The flags for the cached context.
      expect(
          mockPersistence.storage[sdkKeyPersistence]![contextPersistenceKey],
          '{"flagA":{'
          '"version":1,'
          '"value":"test",'
          '"variation":0,'
          '"reason":{"kind":"OFF"}'
          '},'
          '"flagB":{'
          '"version":2,'
          '"value":"test2",'
          '"variation":1,'
          '"reason":{"kind":"TARGET_MATCH"}'
          '}}');

      expect(flagStore.getAll().equals(basicData), true);
    });

    test('it can load cache', () async {
      final context = LDContextBuilder().kind('user', 'user-key').build();
      final contextPersistenceKey =
          sha256.convert(utf8.encode(context.canonicalKey)).toString();

      final flagStore = FlagStore();
      final mockPersistence = MockPersistence();

      mockPersistence.storage[sdkKeyPersistence] = {
        contextPersistenceKey: '{"flagA":{'
            '"version":1,'
            '"value":"test",'
            '"variation":0,'
            '"reason":{"kind":"OFF"}'
            '},'
            '"flagB":{'
            '"version":2,'
            '"value":"test2",'
            '"variation":1,'
            '"reason":{"kind":"TARGET_MATCH"}'
            '}}',
      };

      final flagPersistence = FlagPersistence(
          persistence: mockPersistence,
          updater: FlagUpdater(flagStore: flagStore, logger: logger),
          store: flagStore,
          sdkKey: sdkKey,
          maxCachedContexts: 5,
          logger: logger,
          stamper: () => DateTime.fromMillisecondsSinceEpoch(0));

      final loaded = await flagPersistence.loadCached(context);
      expect(loaded, isTrue);

      expect(flagStore.get('flagA'), basicData['flagA']);
      expect(flagStore.get('flagB'), basicData['flagB']);
    });

    test('it can handle a corrupt cached flag payload', () async {
      final context = LDContextBuilder().kind('user', 'user-key').build();
      final contextPersistenceKey =
          sha256.convert(utf8.encode(context.canonicalKey)).toString();

      final flagStore = FlagStore();
      final mockPersistence = MockPersistence();

      mockPersistence.storage[sdkKeyPersistence] = {
        contextPersistenceKey: '{"flagA":{'
            '"version":1,'
            'CORRUPTION!!!!'
            '"value":"test",'
            '"variation":0,'
            '"reason":{"kind":"OFF"}'
            '}}',
      };

      final flagPersistence = FlagPersistence(
          persistence: mockPersistence,
          updater: FlagUpdater(flagStore: flagStore, logger: logger),
          store: flagStore,
          sdkKey: sdkKey,
          maxCachedContexts: 5,
          logger: logger,
          stamper: () => DateTime.fromMillisecondsSinceEpoch(0));

      final loaded = await flagPersistence.loadCached(context);
      expect(loaded, isFalse);

      expect(flagStore.getAll().length, 0);
    });

    test('it can handle a corrupt context index', () async {
      final context = LDContextBuilder().kind('user', 'user-key').build();

      final flagStore = FlagStore();
      final mockPersistence = MockPersistence();

      mockPersistence.storage[sdkKeyPersistence] = {
        'ContextIndex': '{"index":[{"idBUG,&&&&msTimestamp":0""}]}'
      };

      final flagPersistence = FlagPersistence(
          persistence: mockPersistence,
          updater: FlagUpdater(flagStore: flagStore, logger: logger),
          store: flagStore,
          sdkKey: sdkKey,
          maxCachedContexts: 5,
          logger: logger,
          stamper: () => DateTime.fromMillisecondsSinceEpoch(0));

      flagPersistence.init(context, basicData);

      expect(flagStore.get('flagA'), basicData['flagA']);
      expect(flagStore.get('flagB'), basicData['flagB']);

      expect(flagStore.getAll().length, 2);
    });

    test('it evicts contexts beyond max', () async {
      int now = 0;

      final flagStore = FlagStore();
      final mockPersistence = MockPersistence();
      final flagPersistence = FlagPersistence(
          persistence: mockPersistence,
          updater: FlagUpdater(flagStore: flagStore, logger: logger),
          store: flagStore,
          sdkKey: sdkKey,
          maxCachedContexts: 2,
          logger: logger,
          stamper: () => DateTime.fromMillisecondsSinceEpoch(now));

      await flagPersistence.init(
          LDContextBuilder().kind('user', now.toString()).build(), basicData);

      now++;

      await flagPersistence.init(
          LDContextBuilder().kind('user', now.toString()).build(), basicData);

      now++;

      await flagPersistence.init(
          LDContextBuilder().kind('user', now.toString()).build(), basicData);

      // 1 environment
      expect(mockPersistence.storage.length, 1);
      // 2 contexts and 1 index.
      expect(mockPersistence.storage.values.first.length, 3);

      expect(
          mockPersistence.storage[sdkKeyPersistence]!
              .containsKey(sha256.convert(utf8.encode('1')).toString()),
          true);

      expect(
          mockPersistence.storage[sdkKeyPersistence]!
              .containsKey(sha256.convert(utf8.encode('2')).toString()),
          true);

      expect(
          mockPersistence.storage[sdkKeyPersistence]!
              .containsKey(sha256.convert(utf8.encode('0')).toString()),
          false);
    });

    test('it stores environment ID separately in persistence', () async {
      final flagStore = FlagStore();
      final mockPersistence = MockPersistence();
      final flagPersistence = FlagPersistence(
          persistence: mockPersistence,
          updater: FlagUpdater(flagStore: flagStore, logger: logger),
          store: flagStore,
          sdkKey: sdkKey,
          maxCachedContexts: 5,
          logger: logger,
          stamper: () => DateTime.fromMillisecondsSinceEpoch(0));

      final context = LDContextBuilder().kind('user', 'user-key').build();

      await flagPersistence.init(context, basicData, environmentId: 'test-env-123');

      // Environment ID should be stored separately
      expect(mockPersistence.storage[sdkKeyPersistence]!['EnvironmentId'], 'test-env-123');
    });

    test('it loads environment ID from persistence', () async {
      final context = LDContextBuilder().kind('user', 'user-key').build();
      final contextPersistenceKey =
          sha256.convert(utf8.encode(context.canonicalKey)).toString();

      final flagStore = FlagStore();
      final mockPersistence = MockPersistence();

      // Pre-populate persistence with flag data and environment ID
      mockPersistence.storage[sdkKeyPersistence] = {
        contextPersistenceKey: '{"flagA":{'
            '"version":1,'
            '"value":"test",'
            '"variation":0,'
            '"reason":{"kind":"OFF"}'
            '},'
            '"flagB":{'
            '"version":2,'
            '"value":"test2",'
            '"variation":1,'
            '"reason":{"kind":"TARGET_MATCH"}'
            '}}',
        'EnvironmentId': 'cached-env-456'
      };

      final flagPersistence = FlagPersistence(
          persistence: mockPersistence,
          updater: FlagUpdater(flagStore: flagStore, logger: logger),
          store: flagStore,
          sdkKey: sdkKey,
          maxCachedContexts: 5,
          logger: logger,
          stamper: () => DateTime.fromMillisecondsSinceEpoch(0));

      final loaded = await flagPersistence.loadCached(context);
      expect(loaded, isTrue);

      // Verify environment ID was loaded
      expect(flagStore.environmentId, 'cached-env-456');
    });

    test('it handles missing environment ID in persistence gracefully', () async {
      final context = LDContextBuilder().kind('user', 'user-key').build();
      final contextPersistenceKey =
          sha256.convert(utf8.encode(context.canonicalKey)).toString();

      final flagStore = FlagStore();
      final mockPersistence = MockPersistence();

      // Pre-populate persistence with flag data but no environment ID
      mockPersistence.storage[sdkKeyPersistence] = {
        contextPersistenceKey: '{"flagA":{'
            '"version":1,'
            '"value":"test",'
            '"variation":0,'
            '"reason":{"kind":"OFF"}'
            '}}'
      };

      final flagPersistence = FlagPersistence(
          persistence: mockPersistence,
          updater: FlagUpdater(flagStore: flagStore, logger: logger),
          store: flagStore,
          sdkKey: sdkKey,
          maxCachedContexts: 5,
          logger: logger,
          stamper: () => DateTime.fromMillisecondsSinceEpoch(0));

      final loaded = await flagPersistence.loadCached(context);
      expect(loaded, isTrue);

      // Environment ID should be null when not in persistence
      expect(flagStore.environmentId, null);
    });

    test('it does not store environment ID when maxCachedContexts is 0', () async {
      final flagStore = FlagStore();
      final mockPersistence = MockPersistence();
      final flagPersistence = FlagPersistence(
          persistence: mockPersistence,
          updater: FlagUpdater(flagStore: flagStore, logger: logger),
          store: flagStore,
          sdkKey: sdkKey,
          maxCachedContexts: 0, // No caching
          logger: logger,
          stamper: () => DateTime.fromMillisecondsSinceEpoch(0));

      final context = LDContextBuilder().kind('user', 'user-key').build();

      await flagPersistence.init(context, basicData, environmentId: 'test-env-123');

      // Only the index should be stored, not the context data or environment ID
      expect(mockPersistence.storage[sdkKeyPersistence]!.containsKey('EnvironmentId'), false);
      expect(mockPersistence.storage[sdkKeyPersistence]!.length, 1); // Just the index
    });

    test('it does not store environment ID when environment ID is null', () async {
      final flagStore = FlagStore();
      final mockPersistence = MockPersistence();
      final flagPersistence = FlagPersistence(
          persistence: mockPersistence,
          updater: FlagUpdater(flagStore: flagStore, logger: logger),
          store: flagStore,
          sdkKey: sdkKey,
          maxCachedContexts: 5,
          logger: logger,
          stamper: () => DateTime.fromMillisecondsSinceEpoch(0));

      final context = LDContextBuilder().kind('user', 'user-key').build();

      await flagPersistence.init(context, basicData); // No environment ID provided

      // Environment ID should not be in storage when it's null
      expect(mockPersistence.storage[sdkKeyPersistence]!.containsKey('EnvironmentId'), false);
    });
  });

  group('without persistence', () {
    test('it can handle initialization', () async {
      final flagStore = FlagStore();
      final flagPersistence = FlagPersistence(
          updater: FlagUpdater(flagStore: flagStore, logger: logger),
          store: flagStore,
          sdkKey: sdkKey,
          maxCachedContexts: 5,
          logger: logger,
          stamper: () => DateTime.fromMillisecondsSinceEpoch(0));

      final context = LDContextBuilder().kind('user', 'user-key').build();

      await flagPersistence.init(context, basicData);

      expect(flagStore.getAll().equals(basicData), true);
    });

    test('loading cache has no effect', () async {
      final flagStore = FlagStore();
      final flagPersistence = FlagPersistence(
          updater: FlagUpdater(flagStore: flagStore, logger: logger),
          store: flagStore,
          sdkKey: sdkKey,
          maxCachedContexts: 5,
          logger: logger,
          stamper: () => DateTime.fromMillisecondsSinceEpoch(0));

      final loaded = await flagPersistence
          .loadCached(LDContextBuilder().kind('user', 'user-key').build());
      expect(loaded, isFalse);

      expect(flagStore.getAll().length, 0);
    });
  });
}
