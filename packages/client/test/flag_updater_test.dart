import 'dart:convert';

import 'package:crypto/crypto.dart';
import 'package:launchdarkly_dart_client/ld_client.dart';
import 'package:launchdarkly_dart_client/src/flag_manager/flag_store.dart';
import 'package:launchdarkly_dart_client/src/flag_manager/flag_updater.dart';
import 'package:launchdarkly_dart_client/src/item_descriptor.dart';
import 'package:launchdarkly_dart_common/ld_common.dart';
import 'package:test/test.dart';

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
    final flagStore = FlagStore();
    final flagUpdater = FlagUpdater(flagStore: flagStore, logger: logger);

    final context = LDContextBuilder().kind('user', 'user-key').build();

    await flagUpdater.init(context, basicData);

    expect(flagStore.getAll().equals(basicData), true);
  });

  test('it emits events on store init', () async {
    final flagStore = FlagStore();
    final flagUpdater = FlagUpdater(flagStore: flagStore, logger: logger);

    final context = LDContextBuilder().kind('user', 'user-key').build();

    expectLater(flagUpdater.changes,
        emits(FlagsChangedEvent(keys: ['flagA', 'flagB'])));

    await flagUpdater.init(context, basicData);
  });

  test('it emits events for init changes', () async {
    final flagStore = FlagStore();
    final flagUpdater = FlagUpdater(flagStore: flagStore, logger: logger);

    final context = LDContextBuilder().kind('user', 'user-key').build();

    await flagUpdater.init(context, basicData);

    expectLater(flagUpdater.changes,
        emits(FlagsChangedEvent(keys: ['flagB'])));

    final secondData = {
      'flagA': ItemDescriptor(
          version: 1,
          flag: LDEvaluationResult(
              version: 1,
              detail: LDEvaluationDetail(
                  LDValue.ofString('test'), 0, LDEvaluationReason.off()))),
      'flagB': ItemDescriptor(
          version: 3,
          flag: LDEvaluationResult(
              version: 3,
              detail: LDEvaluationDetail(LDValue.ofString('test3'), 1,
                  LDEvaluationReason.targetMatch())))
    };

    await flagUpdater.init(context, secondData);
  });

  test('it emits events for init with fewer flags', () async {
    final flagStore = FlagStore();
    final flagUpdater = FlagUpdater(flagStore: flagStore, logger: logger);

    final context = LDContextBuilder().kind('user', 'user-key').build();

    await flagUpdater.init(context, basicData);

    expectLater(flagUpdater.changes,
        emits(FlagsChangedEvent(keys: ['flagB'])));

    final secondData = {
      'flagA': ItemDescriptor(
          version: 1,
          flag: LDEvaluationResult(
              version: 1,
              detail: LDEvaluationDetail(
                  LDValue.ofString('test'), 0, LDEvaluationReason.off()))),
    };

    await flagUpdater.init(context, secondData);
  });

  test('it updates the store on upsert', () async {
    final flagStore = FlagStore();
    final flagUpdater = FlagUpdater(flagStore: flagStore, logger: logger);

    final context = LDContextBuilder().kind('user', 'user-key').build();

    await flagUpdater.init(context, basicData);
    final flagB = LDEvaluationResult(
        version: 3,
        detail: LDEvaluationDetail(LDValue.ofString('test3'), 2,
            LDEvaluationReason.fallthrough(inExperiment: true)));

    expect(
        flagUpdater.upsert(
            context, 'flagB', ItemDescriptor(version: 3, flag: flagB)),
        true);

    final flagBFromStore = flagStore.get('flagB');
    expect(flagBFromStore?.flag?.detail.value.stringValue(), 'test3');
    expect(flagBFromStore?.flag?.version, 3);
    expect(flagBFromStore?.flag?.detail.variationIndex, 2);
    expect(flagBFromStore?.flag?.detail.reason,
        LDEvaluationReason.fallthrough(inExperiment: true));
  });

  test('it emits events on store upsert', () async {
    final flagStore = FlagStore();
    final flagUpdater = FlagUpdater(flagStore: flagStore, logger: logger);

    final context = LDContextBuilder().kind('user', 'user-key').build();

    await flagUpdater.init(context, basicData);

    expectLater(flagUpdater.changes, emits(FlagsChangedEvent(keys: ['flagB'])));
    final flagB = LDEvaluationResult(
        version: 3,
        detail: LDEvaluationDetail(LDValue.ofString('test3'), 2,
            LDEvaluationReason.fallthrough(inExperiment: true)));

    expect(
        flagUpdater.upsert(
            context, 'flagB', ItemDescriptor(version: 3, flag: flagB)),
        true);
  });

  test('it updates the store on delete', () async {
    final flagStore = FlagStore();
    final flagUpdater = FlagUpdater(flagStore: flagStore, logger: logger);

    final context = LDContextBuilder().kind('user', 'user-key').build();

    await flagUpdater.init(context, basicData);

    expect(
        flagUpdater.upsert(context, 'flagB', ItemDescriptor(version: 3)), true);

    final flagBFromStore = flagStore.get('flagB');
    expect(flagBFromStore?.flag, null);
  });

  test('it emits an event on delete', () async {
    final flagStore = FlagStore();
    final flagUpdater = FlagUpdater(flagStore: flagStore, logger: logger);

    final context = LDContextBuilder().kind('user', 'user-key').build();

    await flagUpdater.init(context, basicData);

    expectLater(flagUpdater.changes, emits(FlagsChangedEvent(keys: ['flagB'])));

    expect(
        flagUpdater.upsert(context, 'flagB', ItemDescriptor(version: 3)), true);

    final flagBFromStore = flagStore.get('flagB');
    expect(flagBFromStore?.flag, null);
  });

  test('it discards out of order updates', () async {
    final flagStore = FlagStore();
    final flagUpdater = FlagUpdater(flagStore: flagStore, logger: logger);

    final context = LDContextBuilder().kind('user', 'user-key').build();

    await flagUpdater.init(context, basicData);
    final flagB = LDEvaluationResult(
        version: 2,
        detail: LDEvaluationDetail(LDValue.ofString('test3'), 2,
            LDEvaluationReason.fallthrough(inExperiment: true)));

    expect(
        flagUpdater.upsert(
            context, 'flagB', ItemDescriptor(version: 2, flag: flagB)),
        false);

    expect(flagStore.getAll().equals(basicData), true);
  });

  test('it does not emit events for out of order updates', () async {
    final flagStore = FlagStore();
    final flagUpdater = FlagUpdater(flagStore: flagStore, logger: logger);

    final context = LDContextBuilder().kind('user', 'user-key').build();

    await flagUpdater.init(context, basicData);
    final flagB = LDEvaluationResult(
        version: 2,
        detail: LDEvaluationDetail(LDValue.ofString('test3'), 2,
            LDEvaluationReason.fallthrough(inExperiment: true)));

    expectLater(flagUpdater.changes, neverEmits(anything));

    expect(
        flagUpdater.upsert(
            context, 'flagB', ItemDescriptor(version: 2, flag: flagB)),
        false);

    flagUpdater.close();
  });
}
