import 'dart:convert';

import 'package:launchdarkly_dart_common/ld_common.dart';
import 'package:test/test.dart';

void main() {
  final basicEvalReason = LDEvaluationDetail<LDValue>(
      LDValue.ofNull(), null, LDEvaluationReason.off());
  group('given different evaluation results', () {
    for (var result in [
      LDEvaluationResult(version: 1, detail: basicEvalReason),
      LDEvaluationResult(
          version: 2,
          detail: basicEvalReason,
          trackEvents: true,
          trackReason: false),
      LDEvaluationResult(
          version: 3,
          detail: basicEvalReason,
          trackEvents: false,
          trackReason: true),
      LDEvaluationResult(
          version: 4,
          detail: basicEvalReason,
          trackEvents: true,
          trackReason: true),
      LDEvaluationResult(
          version: 5,
          detail: basicEvalReason,
          debugEventsUntilDate: DateTime.now().millisecondsSinceEpoch)
    ]) {
      test('it can serialize/deserialize the evaluation detail: $result', () {
        var serialized =
            jsonEncode(LDEvaluationResultSerialization.toJson(result));
        var deserialized =
            LDEvaluationResultSerialization.fromJson(jsonDecode(serialized));
        expect(deserialized, result);
      });
    }
  });
}
