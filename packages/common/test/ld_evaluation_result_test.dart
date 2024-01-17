import 'package:launchdarkly_dart_common/ld_common.dart';
import 'package:test/test.dart';

void main() {
  test('equivalent os info objects are equal', () {
    final a = LDEvaluationResult(
        version: 1,
        detail: LDEvaluationDetail<LDValue>(
            LDValue.ofString('toast'), null, LDEvaluationReason.targetMatch()));
    final b = LDEvaluationResult(
        version: 1,
        detail: LDEvaluationDetail<LDValue>(
            LDValue.ofString('toast'), null, LDEvaluationReason.targetMatch()));

    expect(a, b);

    final c = OsInfo(family: 'Adams');
    final d = OsInfo(family: 'Adams');

    expect(c, d);
  });

  test('non-equivalent os info objects are not equal', () {
    final a = LDEvaluationResult(
        version: 1,
        detail: LDEvaluationDetail<LDValue>(
            LDValue.ofString('toast'), null, LDEvaluationReason.targetMatch()));
    final b = LDEvaluationResult(
        version: 2,
        detail: LDEvaluationDetail<LDValue>(
            LDValue.ofString('toast'), null, LDEvaluationReason.targetMatch()));

    expect(a, isNot(b));
  });

  test('equivalent os info objects have equal hash codes', () {
    final a = LDEvaluationResult(
        version: 1,
        detail: LDEvaluationDetail<LDValue>(
            LDValue.ofString('toast'), null, LDEvaluationReason.targetMatch()));
    final b = LDEvaluationResult(
        version: 1,
        detail: LDEvaluationDetail<LDValue>(
            LDValue.ofString('toast'), null, LDEvaluationReason.targetMatch()));

    expect(a.hashCode, b.hashCode);
  });

  test('non-equivalent os info objects do not have equal hash codes', () {
    final a = LDEvaluationResult(
        version: 1,
        detail: LDEvaluationDetail<LDValue>(
            LDValue.ofString('toast'), null, LDEvaluationReason.targetMatch()));
    final b = LDEvaluationResult(
        version: 2,
        detail: LDEvaluationDetail<LDValue>(
            LDValue.ofString('toast'), null, LDEvaluationReason.targetMatch()));

    expect(a.hashCode, isNot(b.hashCode));
  });

  test('it produces the expected string', () {
    final a = LDEvaluationResult(
        version: 1,
        detail: LDEvaluationDetail<LDValue>(
            LDValue.ofString('toast'), null, LDEvaluationReason.targetMatch()));

    expect(
        a.toString(),
        'LDEvaluationResult{version: 1, trackEvents: false, trackReason: false,'
        ' debugEventsUntilDate: null, detail: LDEvaluationDetail{value:'
        ' LDValue{_value: toast}, variationIndex: null, reason:'
        ' LDEvaluationReason{kind: TARGET_MATCH, ruleIndex: null,'
        ' ruleId: null, inExperiment: false, prerequisiteKey: null, '
        'errorKind: null}}}');
  });
}
