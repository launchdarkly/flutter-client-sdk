import 'package:launchdarkly_dart_common/src/serialization/ld_evaluation_result_serialization.dart';

import '../ld_evaluation_result.dart';

final class LDEvaluationResultsSerialization {
  static Map<String, LDEvaluationResult> fromJson(Map<String, dynamic> json) {
    return json.map((key, value) =>
        MapEntry(key, LDEvaluationResultSerialization.fromJson(value)));
  }

  static Map<String, dynamic> toJson(
      Map<String, LDEvaluationResult> evalResults) {
    return evalResults.map((key, value) =>
        MapEntry(key, LDEvaluationResultSerialization.toJson(value)));
  }
}
