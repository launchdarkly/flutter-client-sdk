import '../../launchdarkly_dart_common.dart';

final class LDEvaluationResultSerialization {
  static LDEvaluationResult fromJson(Map<String, dynamic> json) {
    final version = json['version'] as num;
    final flagVersion = json['flagVersion'] as num?;
    final trackEvents = (json['trackEvents'] ?? false) as bool;
    final trackReason = (json['trackReason'] ?? false) as bool;
    final prerequisites = (json['prerequisites'] as List<dynamic>?)
        ?.map((e) => e as String)
        .toList();
    final debugEventsUntilDateRaw = json['debugEventsUntilDate'] as num?;
    final value = LDValueSerialization.fromJson(json['value']);
    final jsonReason = json['reason'];

    LDEvaluationReason? reason = jsonReason != null
        ? LDEvaluationReasonSerialization.fromJson(jsonReason)
        : null;

    final jsonVariation = json['variation'];
    final variationIndex =
        jsonVariation != null ? (jsonVariation as num).toInt() : null;

    return LDEvaluationResult(
        version: version.toInt(),
        flagVersion: flagVersion?.toInt(),
        detail: LDEvaluationDetail(value, variationIndex, reason),
        trackEvents: trackEvents,
        trackReason: trackReason,
        prerequisites: prerequisites,
        debugEventsUntilDate: debugEventsUntilDateRaw?.toInt());
  }

  static Map<String, dynamic> toJson(LDEvaluationResult evaluationResult) {
    Map<String, dynamic> result = {};

    result['version'] = evaluationResult.version;
    if (evaluationResult.trackEvents) {
      result['trackEvents'] = evaluationResult.trackEvents;
    }
    if (evaluationResult.trackReason) {
      result['trackReason'] = evaluationResult.trackReason;
    }
    if (evaluationResult.prerequisites?.isNotEmpty ?? false) {
      result['prerequisites'] = evaluationResult.prerequisites;
    }
    if (evaluationResult.debugEventsUntilDate != null) {
      result['debugEventsUntilDate'] = evaluationResult.debugEventsUntilDate;
    }
    result['value'] =
        LDValueSerialization.toJson(evaluationResult.detail.value);
    if (evaluationResult.detail.variationIndex != null) {
      result['variation'] = evaluationResult.detail.variationIndex;
    }
    if (evaluationResult.detail.reason != null) {
      result['reason'] = LDEvaluationReasonSerialization.toJson(
          evaluationResult.detail.reason!);
    }

    return result;
  }
}
