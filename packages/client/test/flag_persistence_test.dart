import 'dart:convert';

import 'package:crypto/crypto.dart';
import 'package:launchdarkly_dart_client/ld_client.dart';
import 'package:launchdarkly_dart_client/src/flag_manager/flag_persistence.dart';
import 'package:launchdarkly_dart_client/src/flag_manager/flag_store.dart';
import 'package:launchdarkly_dart_client/src/flag_manager/flag_updater.dart';
import 'package:launchdarkly_dart_client/src/item_descriptor.dart';
import 'package:test/test.dart';

final class MockPersistence implements Persistence {
  final storage = <String, Map<String, String>>{};

  @override
  Future<String?> read(String namespace, String key) async {
    return storage[namespace]?[key];
  }

  @override
  Future<void> remove(String namespace, String key) async {
    storage[namespace]?.remove(key);
  }

  @override
  Future<void> set(String namespace, String key, String data) async {
    if (!storage.containsKey(namespace)) {
      storage[namespace] = <String, String>{};
    }
    storage[namespace]![key] = data;
  }
}

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
                LDValue.ofString("test"), 0, LDEvaluationReason.off()))),
    'flagB': ItemDescriptor(
        version: 2,
        flag: LDEvaluationResult(
            version: 2,
            detail: LDEvaluationDetail(LDValue.ofString("test2"), 1,
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
      expect(mockPersistence.storage[sdkKeyPersistence]!["ContextIndex"],
          '{"index":[{"id":"$contextPersistenceKey","msTimestamp":0}]}');

      // The flags for the cached context.
      expect(
          mockPersistence.storage[sdkKeyPersistence]![contextPersistenceKey],
          '{"flagA":{'
              '"version":1,'
              '"detail":{"value":"test","variationIndex":0,"reason":{"kind":"OFF"}}'
              '},'
              '"flagB":{'
              '"version":2,'
              '"detail":{"value":"test2","variationIndex":1,"reason":{"kind":"TARGET_MATCH"}}}'
              '}');

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
              LDValue.ofString("test3"), 1, LDEvaluationReason.targetMatch()));

      await flagPersistence.upsert(
          context, "flagB", ItemDescriptor(version: 3, flag: flagB));

      // 1 environment
      expect(mockPersistence.storage.length, 1);
      // 1 context and 1 index.
      expect(mockPersistence.storage.values.first.length, 2);

      final contextPersistenceKey =
      sha256.convert(utf8.encode(context.canonicalKey)).toString();

      // The context index.
      expect(mockPersistence.storage[sdkKeyPersistence]!["ContextIndex"],
          '{"index":[{"id":"$contextPersistenceKey","msTimestamp":0}]}');

      // The flags for the cached context.
      expect(
          mockPersistence.storage[sdkKeyPersistence]![contextPersistenceKey],
          '{"flagA":{'
              '"version":1,'
              '"detail":{"value":"test","variationIndex":0,"reason":{"kind":"OFF"}}'
              '},'
              '"flagB":{'
              '"version":3,'
              '"detail":{"value":"test3","variationIndex":1,"reason":{"kind":"TARGET_MATCH"}}}'
              '}');
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
              LDValue.ofString("test1"), 1, LDEvaluationReason.targetMatch()));

      await flagPersistence.upsert(
          context, "flagB", ItemDescriptor(version: 1, flag: flagB));

      // 1 environment
      expect(mockPersistence.storage.length, 1);
      // 1 context and 1 index.
      expect(mockPersistence.storage.values.first.length, 2);

      final contextPersistenceKey =
      sha256.convert(utf8.encode(context.canonicalKey)).toString();

      // The context index.
      expect(mockPersistence.storage[sdkKeyPersistence]!["ContextIndex"],
          '{"index":[{"id":"$contextPersistenceKey","msTimestamp":0}]}');

      // The flags for the cached context.
      expect(
          mockPersistence.storage[sdkKeyPersistence]![contextPersistenceKey],
          '{"flagA":{'
              '"version":1,'
              '"detail":{"value":"test","variationIndex":0,"reason":{"kind":"OFF"}}'
              '},'
              '"flagB":{'
              '"version":2,'
              '"detail":{"value":"test2","variationIndex":1,"reason":{"kind":"TARGET_MATCH"}}}'
              '}');

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
            '"detail":{"value":"test","variationIndex":0,"reason":{"kind":"OFF"}}'
            '},'
            '"flagB":{'
            '"version":2,'
            '"detail":{"value":"test2","variationIndex":1,"reason":{"kind":"TARGET_MATCH"}}}'
            '}',
      };

      final flagPersistence = FlagPersistence(
          persistence: mockPersistence,
          updater: FlagUpdater(flagStore: flagStore, logger: logger),
          store: flagStore,
          sdkKey: sdkKey,
          maxCachedContexts: 5,
          logger: logger,
          stamper: () => DateTime.fromMillisecondsSinceEpoch(0));

      await flagPersistence.loadCached(context);

      expect(flagStore.get("flagA"), basicData['flagA']);
      expect(flagStore.get("flagB"), basicData['flagB']);
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
            '"detail":{"value":"test2","variationIndex":1,"reason":{"kind":"TARGET_MATCH"}}}'
            '}',
      };

      final flagPersistence = FlagPersistence(
          persistence: mockPersistence,
          updater: FlagUpdater(flagStore: flagStore, logger: logger),
          store: flagStore,
          sdkKey: sdkKey,
          maxCachedContexts: 5,
          logger: logger,
          stamper: () => DateTime.fromMillisecondsSinceEpoch(0));

      await flagPersistence.loadCached(context);

      expect(flagStore
          .getAll()
          .length, 0);
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

      expect(flagStore.get("flagA"), basicData['flagA']);
      expect(flagStore.get("flagB"), basicData['flagB']);

      expect(flagStore
          .getAll()
          .length, 2);
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

      await flagPersistence
          .loadCached(LDContextBuilder().kind('user', 'user-key').build());

      expect(flagStore
          .getAll()
          .length, 0);
    });
  });
}
