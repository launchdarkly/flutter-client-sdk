import 'dart:convert';

import 'package:crypto/crypto.dart';
import 'package:launchdarkly_common_client/launchdarkly_common_client.dart';
import 'package:launchdarkly_common_client/src/data_sources/fdv2/payload.dart';
import 'package:launchdarkly_common_client/src/flag_manager/flag_store.dart';
import 'package:launchdarkly_common_client/src/flag_manager/flag_updater.dart';
import 'package:launchdarkly_common_client/src/item_descriptor.dart';
import 'package:launchdarkly_dart_common/launchdarkly_dart_common.dart';
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

    flagUpdater.init(context, basicData);

    expect(flagStore.getAll().equals(basicData), true);
  });

  test('it emits events on store init', () async {
    final flagStore = FlagStore();
    final flagUpdater = FlagUpdater(flagStore: flagStore, logger: logger);

    final context = LDContextBuilder().kind('user', 'user-key').build();

    expectLater(flagUpdater.changes,
        emits(FlagsChangedEvent(keys: ['flagA', 'flagB'])));

    flagUpdater.init(context, basicData);
  });

  test('it emits events for init changes', () async {
    final flagStore = FlagStore();
    final flagUpdater = FlagUpdater(flagStore: flagStore, logger: logger);

    final context = LDContextBuilder().kind('user', 'user-key').build();

    flagUpdater.init(context, basicData);

    expectLater(flagUpdater.changes, emits(FlagsChangedEvent(keys: ['flagB'])));

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

    flagUpdater.init(context, secondData);
  });

  test('it emits events for init with fewer flags', () async {
    final flagStore = FlagStore();
    final flagUpdater = FlagUpdater(flagStore: flagStore, logger: logger);

    final context = LDContextBuilder().kind('user', 'user-key').build();

    flagUpdater.init(context, basicData);

    expectLater(flagUpdater.changes, emits(FlagsChangedEvent(keys: ['flagB'])));

    final secondData = {
      'flagA': ItemDescriptor(
          version: 1,
          flag: LDEvaluationResult(
              version: 1,
              detail: LDEvaluationDetail(
                  LDValue.ofString('test'), 0, LDEvaluationReason.off()))),
    };

    flagUpdater.init(context, secondData);
  });

  test('it updates the store on upsert', () async {
    final flagStore = FlagStore();
    final flagUpdater = FlagUpdater(flagStore: flagStore, logger: logger);

    final context = LDContextBuilder().kind('user', 'user-key').build();

    flagUpdater.init(context, basicData);
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

    flagUpdater.init(context, basicData);

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

    flagUpdater.init(context, basicData);

    expect(
        flagUpdater.upsert(context, 'flagB', ItemDescriptor(version: 3)), true);

    final flagBFromStore = flagStore.get('flagB');
    expect(flagBFromStore?.flag, null);
  });

  test('it emits an event on delete', () async {
    final flagStore = FlagStore();
    final flagUpdater = FlagUpdater(flagStore: flagStore, logger: logger);

    final context = LDContextBuilder().kind('user', 'user-key').build();

    flagUpdater.init(context, basicData);

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

    flagUpdater.init(context, basicData);
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

    flagUpdater.init(context, basicData);
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

  test('applyChanges partial applies updates without version comparison',
      () async {
    final flagStore = FlagStore();
    final flagUpdater = FlagUpdater(flagStore: flagStore, logger: logger);

    final context = LDContextBuilder().kind('user', 'user-key').build();

    flagUpdater.init(context, basicData);
    final olderFlagB = LDEvaluationResult(
        version: 1,
        detail: LDEvaluationDetail(
            LDValue.ofString('test3'), 2, LDEvaluationReason.fallthrough()));

    expect(
        flagUpdater.applyChanges(
            context,
            {'flagB': ItemDescriptor(version: 1, flag: olderFlagB)},
            PayloadType.partial),
        true);

    expect(
        flagStore.get('flagB')?.flag?.detail.value, LDValue.ofString('test3'));
  });

  test('applyChanges partial emits a single event for the changed keys',
      () async {
    final flagStore = FlagStore();
    final flagUpdater = FlagUpdater(flagStore: flagStore, logger: logger);

    final context = LDContextBuilder().kind('user', 'user-key').build();

    flagUpdater.init(context, basicData);

    expectLater(flagUpdater.changes,
        emits(FlagsChangedEvent(keys: ['flagA', 'flagB'])));

    final updatedA = LDEvaluationResult(
        version: 3,
        detail: LDEvaluationDetail(
            LDValue.ofString('newA'), 0, LDEvaluationReason.off()));
    final updatedB = LDEvaluationResult(
        version: 3,
        detail: LDEvaluationDetail(
            LDValue.ofString('newB'), 1, LDEvaluationReason.off()));
    flagUpdater.applyChanges(
        context,
        {
          'flagA': ItemDescriptor(version: 3, flag: updatedA),
          'flagB': ItemDescriptor(version: 3, flag: updatedB),
        },
        PayloadType.partial);
  });

  test('applyChanges partial applies a tombstone and emits a change event',
      () async {
    final flagStore = FlagStore();
    final flagUpdater = FlagUpdater(flagStore: flagStore, logger: logger);

    final context = LDContextBuilder().kind('user', 'user-key').build();

    flagUpdater.init(context, basicData);

    expectLater(flagUpdater.changes, emits(FlagsChangedEvent(keys: ['flagB'])));

    expect(
        flagUpdater.applyChanges(context, {'flagB': ItemDescriptor(version: 3)},
            PayloadType.partial),
        true);
    expect(flagStore.get('flagB')?.flag, isNull,
        reason: 'the entry becomes a tombstone');
    expect(flagStore.get('flagB')?.version, 3);
  });

  test('applyChanges partial rejects updates for an inactive context',
      () async {
    final flagStore = FlagStore();
    final flagUpdater = FlagUpdater(flagStore: flagStore, logger: logger);

    final context = LDContextBuilder().kind('user', 'user-key').build();
    final otherContext =
        LDContextBuilder().kind('user', 'other-user-key').build();

    flagUpdater.init(context, basicData);

    final updated = LDEvaluationResult(
        version: 3,
        detail: LDEvaluationDetail(
            LDValue.ofString('newA'), 0, LDEvaluationReason.off()));
    expect(
        flagUpdater.applyChanges(
            otherContext,
            {'flagA': ItemDescriptor(version: 3, flag: updated)},
            PayloadType.partial),
        false);
    expect(flagStore.getAll().equals(basicData), true);
  });

  test('applyChanges full replaces all stored flags and emits the differences',
      () async {
    final flagStore = FlagStore();
    final flagUpdater = FlagUpdater(flagStore: flagStore, logger: logger);

    final context = LDContextBuilder().kind('user', 'user-key').build();

    flagUpdater.init(context, basicData);

    // flagA changes value and flagB is absent from the replacement, so both
    // are reported.
    expectLater(flagUpdater.changes,
        emits(FlagsChangedEvent(keys: ['flagA', 'flagB'])));

    final updatedA = LDEvaluationResult(
        version: 3,
        detail: LDEvaluationDetail(
            LDValue.ofString('newA'), 0, LDEvaluationReason.off()));
    final replacement = {'flagA': ItemDescriptor(version: 3, flag: updatedA)};
    expect(
        flagUpdater.applyChanges(context, replacement, PayloadType.full), true);
    expect(flagStore.getAll().equals(replacement), true);
    expect(flagStore.get('flagB'), isNull,
        reason: 'a full transfer replaces everything');
  });

  test('applyChanges full makes the context active', () async {
    final flagStore = FlagStore();
    final flagUpdater = FlagUpdater(flagStore: flagStore, logger: logger);

    final context = LDContextBuilder().kind('user', 'user-key').build();
    final otherContext =
        LDContextBuilder().kind('user', 'other-user-key').build();

    flagUpdater.init(context, basicData);
    expect(flagUpdater.applyChanges(otherContext, basicData, PayloadType.full),
        true);

    final updated = LDEvaluationResult(
        version: 3,
        detail: LDEvaluationDetail(
            LDValue.ofString('newA'), 0, LDEvaluationReason.off()));
    expect(
        flagUpdater.applyChanges(
            otherContext,
            {'flagA': ItemDescriptor(version: 3, flag: updated)},
            PayloadType.partial),
        true,
        reason: 'a partial transfer succeeds for the newly active context');
  });

  test('applyChanges full sets the environment ID', () async {
    final flagStore = FlagStore();
    final flagUpdater = FlagUpdater(flagStore: flagStore, logger: logger);

    final context = LDContextBuilder().kind('user', 'user-key').build();

    flagUpdater.applyChanges(context, basicData, PayloadType.full,
        environmentId: 'the-environment-id');
    expect(flagStore.environmentId, 'the-environment-id');
  });

  test('applyChanges none takes no action', () async {
    final flagStore = FlagStore();
    final flagUpdater = FlagUpdater(flagStore: flagStore, logger: logger);

    final context = LDContextBuilder().kind('user', 'user-key').build();

    flagUpdater.init(context, basicData);

    expectLater(flagUpdater.changes, neverEmits(anything));

    expect(flagUpdater.applyChanges(context, {}, PayloadType.none), true);
    expect(flagStore.getAll().equals(basicData), true);

    flagUpdater.close();
  });
}
