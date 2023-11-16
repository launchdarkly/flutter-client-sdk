import 'dart:convert';

import 'package:launchdarkly_dart_common/ld_common.dart';
import 'package:launchdarkly_dart_common/src/collections.dart';

import 'package:test/test.dart';

void main() {
  final basicEvalReason = LDEvaluationDetail<LDValue>(
      LDValue.ofNull(), null, LDEvaluationReason.off());

  test('can serialize and deserialize a map of evaluation results', () {
    final results = {
      "basic": LDEvaluationResult(version: 1, detail: basicEvalReason),
      "trackEvents": LDEvaluationResult(
          version: 2,
          detail: basicEvalReason,
          trackEvents: true,
          trackReason: false),
      "trackReason": LDEvaluationResult(
          version: 3,
          detail: basicEvalReason,
          trackEvents: false,
          trackReason: true),
      "trackBoth": LDEvaluationResult(
          version: 4,
          detail: basicEvalReason,
          trackEvents: true,
          trackReason: true),
      "withDate": LDEvaluationResult(
          version: 5,
          detail: basicEvalReason,
          debugEventsUntilDate: DateTime.now().millisecondsSinceEpoch)
    };

    final serialized = jsonEncode(LDEvaluationResultsSerialization.toJson(results));
    final deserialized = LDEvaluationResultsSerialization.fromJson(jsonDecode(serialized));

    deserialized.equals(results);
  });
}
