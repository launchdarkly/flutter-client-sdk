import 'package:launchdarkly_dart_client/ld_client.dart';
import 'package:test/test.dart';

import 'package:launchdarkly_dart_client/src/flag_manager/flag_store.dart';
import 'package:launchdarkly_dart_client/src/item_descriptor.dart';

void main() {
  test('can get an item that does not exist', () {
    final store = FlagStore();
    expect(store.get('flagKey'), null);
  });

  test('can get all flags when there are no flags', () {
    final store = FlagStore();
    expect(store.getAll().length, 0);
  });

  test('can initialize the store from empty', () {
    final store = FlagStore();
    final flagA = LDEvaluationResult(
        version: 1,
        detail: LDEvaluationDetail(
            LDValue.ofString('test'), 0, LDEvaluationReason.off()));

    final flagB = LDEvaluationResult(
        version: 2,
        detail: LDEvaluationDetail(
            LDValue.ofString('test2'), 1, LDEvaluationReason.targetMatch()));

    store.init({
      'flagA': ItemDescriptor(version: 1, flag: flagA),
      'flagB': ItemDescriptor(version: 2, flag: flagB),
    });

    expect(store.get('flagA')?.flag, flagA);
    expect(store.get('flagB')?.flag, flagB);
  });

  test('initialization replaces the flags in the store', () {
    final store = FlagStore();
    final flagA = LDEvaluationResult(
        version: 1,
        detail: LDEvaluationDetail(
            LDValue.ofString('test'), 0, LDEvaluationReason.off()));

    final flagB = LDEvaluationResult(
        version: 2,
        detail: LDEvaluationDetail(
            LDValue.ofString('test2'), 1, LDEvaluationReason.targetMatch()));

    store.init({
      'flagA': ItemDescriptor(version: 1, flag: flagA),
      'flagB': ItemDescriptor(version: 2, flag: flagB),
    });

    final flagC = LDEvaluationResult(
        version: 3,
        detail: LDEvaluationDetail(
            LDValue.ofString('test3'), 0, LDEvaluationReason.off()));

    final flagD = LDEvaluationResult(
        version: 4,
        detail: LDEvaluationDetail(
            LDValue.ofString('test4'), 1, LDEvaluationReason.targetMatch()));

    store.init({
      'flagC': ItemDescriptor(version: 3, flag: flagC),
      'flagD': ItemDescriptor(version: 4, flag: flagD),
    });

    expect(store.get('flagA'), null);
    expect(store.get('flagB'), null);

    expect(store.get('flagC')?.flag, flagC);
    expect(store.get('flagD')?.flag, flagD);
  });

  test('can insert or update an item into an empty store', () {
    final store = FlagStore();

    final flagA = LDEvaluationResult(
        version: 1,
        detail: LDEvaluationDetail(
            LDValue.ofString('test'), 0, LDEvaluationReason.off()));

    store.insertOrUpdate('flagA', ItemDescriptor(version: 1, flag: flagA));

    expect(store.get('flagA')?.flag, flagA);
  });

  test('you can update an item that exists', () {
    final store = FlagStore();

    final flagA = LDEvaluationResult(
        version: 1,
        detail: LDEvaluationDetail(
            LDValue.ofString('test'), 0, LDEvaluationReason.off()));

    store.insertOrUpdate('flagA', ItemDescriptor(version: 1, flag: flagA));

    final flagA2 = LDEvaluationResult(
        version: 2,
        detail: LDEvaluationDetail(
            LDValue.ofString('test2'), 1, LDEvaluationReason.off()));

    store.insertOrUpdate('flagA', ItemDescriptor(version: 2, flag: flagA2));

    expect(store.get('flagA')?.flag, flagA2);
  });

  test('you can insert a tombstone', () {
    final store = FlagStore();

    final flagA = LDEvaluationResult(
        version: 1,
        detail: LDEvaluationDetail(
            LDValue.ofString('test'), 0, LDEvaluationReason.off()));

    store.insertOrUpdate('flagA', ItemDescriptor(version: 1, flag: flagA));

    store.insertOrUpdate('flagA', ItemDescriptor(version: 2));

    expect(store.get('flagA')?.flag, null);
  });
}
