import 'dart:convert';

import 'package:launchdarkly_dart_common/ld_common.dart';
import 'package:test/test.dart';

void main() {
  final _basicEvalReason = LDEvaluationDetail<LDValue>(
      LDValue.ofNull(), null, LDEvaluationReason.off());
  group('given different evaluation results', () {
    [
      LDEvaluationResult(version: 1, detail: _basicEvalReason),
      LDEvaluationResult(
          version: 2,
          detail: _basicEvalReason,
          trackEvents: true,
          trackReason: false),
      LDEvaluationResult(
          version: 3,
          detail: _basicEvalReason,
          trackEvents: false,
          trackReason: true),
      LDEvaluationResult(
          version: 4,
          detail: _basicEvalReason,
          trackEvents: true,
          trackReason: true),
      LDEvaluationResult(
          version: 5,
          detail: _basicEvalReason,
          debugEventsUntilDate: DateTime.now().millisecondsSinceEpoch)
    ].forEach((result) {
      test('it can serialize/deserialize the evaluation detail: ${result}', () {
        var serialized =
            jsonEncode(LDEvaluationResultSerialization.toJson(result));
        var deserialized =
            LDEvaluationResultSerialization.fromJson(jsonDecode(serialized));
        expect(deserialized, result);
      });
    });
  });
}
