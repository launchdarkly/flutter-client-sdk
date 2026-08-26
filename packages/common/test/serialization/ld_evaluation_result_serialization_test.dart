import 'dart:convert';

import 'package:launchdarkly_dart_common/launchdarkly_dart_common.dart';
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
          debugEventsUntilDate: DateTime.now().millisecondsSinceEpoch),
      // The store version and the flag version are independent: under FDv2
      // the wire object carries only flagVersion and the version comes from
      // the payload envelope. Both must survive a round trip.
      LDEvaluationResult(version: 40, flagVersion: 12, detail: basicEvalReason)
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

  test('it serializes flagVersion when it is set', () {
    final result = LDEvaluationResult(
        version: 40, flagVersion: 12, detail: basicEvalReason);

    final json = LDEvaluationResultSerialization.toJson(result);

    expect(json['flagVersion'], 12);
  });

  test('it omits flagVersion when it is not set', () {
    final result = LDEvaluationResult(version: 40, detail: basicEvalReason);

    final json = LDEvaluationResultSerialization.toJson(result);

    expect(json.containsKey('flagVersion'), isFalse);
  });
}
