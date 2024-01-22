import 'dart:convert';

import 'package:crypto/crypto.dart';
import 'package:launchdarkly_common_client/ld_common_client.dart';
import 'package:launchdarkly_common_client/src/flag_manager/flag_manager.dart';
import 'package:launchdarkly_common_client/src/item_descriptor.dart';
import 'package:launchdarkly_dart_common/ld_common.dart';
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

  test('it updates the store on init', () async {
    final flagManager =
        FlagManager(sdkKey: sdkKey, maxCachedContexts: 5, logger: logger);

    final context = LDContextBuilder().kind('user', 'user-key').build();

    await flagManager.init(context, basicData);

    expect(flagManager.getAll().equals(basicData), true);
  });

  test('it emits events on store init', () async {
    final flagManager =
        FlagManager(sdkKey: sdkKey, maxCachedContexts: 5, logger: logger);

    final context = LDContextBuilder().kind('user', 'user-key').build();

    expectLater(flagManager.changes,
        emits(FlagsChangedEvent(keys: ['flagA', 'flagB'])));

    await flagManager.init(context, basicData);
  });

  test('it updates the store on upsert', () async {
    final flagManager =
        FlagManager(sdkKey: sdkKey, maxCachedContexts: 5, logger: logger);

    final context = LDContextBuilder().kind('user', 'user-key').build();

    await flagManager.init(context, basicData);
    final flagB = LDEvaluationResult(
        version: 3,
        detail: LDEvaluationDetail(LDValue.ofString('test3'), 2,
            LDEvaluationReason.fallthrough(inExperiment: true)));

    expect(
        await flagManager.upsert(
            context, 'flagB', ItemDescriptor(version: 3, flag: flagB)),
        true);

    final flagBFromStore = flagManager.get('flagB');
    expect(flagBFromStore?.flag?.detail.value.stringValue(), 'test3');
    expect(flagBFromStore?.flag?.version, 3);
    expect(flagBFromStore?.flag?.detail.variationIndex, 2);
    expect(flagBFromStore?.flag?.detail.reason,
        LDEvaluationReason.fallthrough(inExperiment: true));
  });

  test('it emits events on store upsert', () async {
    final flagManager =
        FlagManager(sdkKey: sdkKey, maxCachedContexts: 5, logger: logger);

    final context = LDContextBuilder().kind('user', 'user-key').build();

    await flagManager.init(context, basicData);

    expectLater(flagManager.changes, emits(FlagsChangedEvent(keys: ['flagB'])));
    final flagB = LDEvaluationResult(
        version: 3,
        detail: LDEvaluationDetail(LDValue.ofString('test3'), 2,
            LDEvaluationReason.fallthrough(inExperiment: true)));

    expect(
        await flagManager.upsert(
            context, 'flagB', ItemDescriptor(version: 3, flag: flagB)),
        true);
  });

  test('it updates the store on delete', () async {
    final flagManager =
        FlagManager(sdkKey: sdkKey, maxCachedContexts: 5, logger: logger);
    final context = LDContextBuilder().kind('user', 'user-key').build();

    await flagManager.init(context, basicData);

    expect(
        await flagManager.upsert(context, 'flagB', ItemDescriptor(version: 3)),
        true);

    final flagBFromStore = flagManager.get('flagB');
    expect(flagBFromStore?.flag, null);
  });

  test('it can load cache', () async {
    final context = LDContextBuilder().kind('user', 'user-key').build();
    final contextPersistenceKey =
        sha256.convert(utf8.encode(context.canonicalKey)).toString();
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

    final flagManager = FlagManager(
        sdkKey: sdkKey,
        maxCachedContexts: 5,
        logger: logger,
        persistence: mockPersistence);
    await flagManager.loadCached(context);

    expect(flagManager.get('flagA'), basicData['flagA']);
    expect(flagManager.get('flagB'), basicData['flagB']);
  });
}
