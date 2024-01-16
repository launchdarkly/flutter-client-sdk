import 'dart:convert';

import 'package:launchdarkly_dart_common/ld_common.dart';
import 'package:test/test.dart';

void main() {
  group('given different evaluation reasons', () {
    for (var reason in [
      LDEvaluationReason.flagNotFound(),
      LDEvaluationReason.error(errorKind: LDErrorKind.clientNotReady),
      LDEvaluationReason.error(errorKind: LDErrorKind.exception),
      LDEvaluationReason.error(errorKind: LDErrorKind.flagNotFound),
      LDEvaluationReason.error(errorKind: LDErrorKind.malformedFlag),
      LDEvaluationReason.error(errorKind: LDErrorKind.userNotSpecified),
      LDEvaluationReason.error(errorKind: LDErrorKind.wrongType),
      LDEvaluationReason.prerequisiteFailed(prerequisiteKey: 'flagA'),
      LDEvaluationReason.ruleMatch(
          ruleIndex: 10, ruleId: 'RULE', inExperiment: true),
      LDEvaluationReason.ruleMatch(
          ruleIndex: 10, ruleId: 'RULE', inExperiment: false),
      LDEvaluationReason.fallthrough(inExperiment: true),
      LDEvaluationReason.fallthrough(inExperiment: false),
      LDEvaluationReason.targetMatch(),
      LDEvaluationReason.off(),
    ]) {
      test(
          'it can serialize/deserialize the evaluation detail: '
              '$reason', () {
        final detail = LDEvaluationDetail(
            LDValue.ofString('test'), null, reason);
        var serialized = jsonEncode(LDEvaluationDetailSerialization.toJson(
            detail));
        var deserialized =
        LDEvaluationDetailSerialization.fromJson(jsonDecode(serialized));

        expect(deserialized, detail);
      });
    }
  });

  group('given different values', () {
    for (var value in [
      LDValue.ofString('test'),
      LDValue.ofNum(42),
      LDValue.ofBool(true),
      LDValue.buildArray()
          .addValue(LDValue.ofNull())
          .addBool(true)
          .addNum(42)
          .addString('forty-two')
          .addValue(LDValue.buildObject().addString('potato', 'cheese').build())
          .addValue(LDValue.buildArray().addString('nested').build())
          .build()
    ]) {
      test('it serializes and deserializes the value: ${value.type}', () {
        var serialized = jsonEncode(LDEvaluationDetailSerialization.toJson(
            LDEvaluationDetail(value, null, LDEvaluationReason.off())));
        var deserialized =
        LDEvaluationDetailSerialization.fromJson(jsonDecode(serialized));

        expect(deserialized.value, value);
      });
    }
  });

  group('given different variation indexes', () {
    for (var variationIndex in [42, 10, 0, null]) {
      test(
          'it serializes and deserializes the variationIndex: $variationIndex',
              () {
            var serialized = jsonEncode(LDEvaluationDetailSerialization.toJson(
                LDEvaluationDetail(
                    LDValue.ofNull(), variationIndex,
                    LDEvaluationReason.off())));
            var deserialized =
            LDEvaluationDetailSerialization.fromJson(jsonDecode(serialized));

            expect(deserialized.variationIndex, variationIndex);
          });
    }
  });
}
