import '../ld_evaluation_result.dart';
import 'ld_evaluation_detail_serialization.dart';

final class LDEvaluationResultSerialization {
  static LDEvaluationResult fromJson(Map<String, dynamic> json) {
    final version = json['version'] as num;
    final trackEvents = (json['trackEvents'] ?? false) as bool;
    final trackReason = (json['trackReason'] ?? false) as bool;
    final debugEventsUntilDateRaw = json['debugEventsUntilDate'] as num?;
    final detail = LDEvaluationDetailSerialization.fromJson(json['detail']);

    return LDEvaluationResult(
        version: version.toInt(),
        detail: detail,
        trackEvents: trackEvents,
        trackReason: trackReason,
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
    if (evaluationResult.debugEventsUntilDate != null) {
      result['debugEventsUntilDate'] = evaluationResult.debugEventsUntilDate;
    }
    result['detail'] =
        LDEvaluationDetailSerialization.toJson(evaluationResult.detail);

    return result;
  }
}
