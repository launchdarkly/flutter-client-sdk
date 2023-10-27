import '../ld_evaluation_detail.dart';
import '../ld_value.dart';
import 'ld_value_serialization.dart';

final class _LDErrorKindSerialization {
  static LDErrorKind fromJson(dynamic json) {
    if (json is String) {
      return LDErrorKind.fromString(json);
    }
    return LDErrorKind.unknown;
  }

  static dynamic toJson(LDErrorKind kind) {
    return kind.toString();
  }
}

final class _LDKindSerialization {
  static LDKind fromJson(dynamic json) {
    if (json is String) {
      return LDKind.fromString(json);
    }
    return LDKind.unknown;
  }

  static dynamic toJson(LDKind kind) {
    return kind.toString();
  }
}

final class _LDEvaluationReasonSerialization {
  static LDEvaluationReason fromJson(Map<String, dynamic> json) {
    final kind = _LDKindSerialization.fromJson(json['kind']);
    switch (kind) {
      case LDKind.off:
        return LDEvaluationReason.off();
      case LDKind.fallthrough:
        {
          final inExperiment = (json['inExperiment'] ?? false) as bool;
          return LDEvaluationReason.fallthrough(inExperiment: inExperiment);
        }
      case LDKind.targetMatch:
        return LDEvaluationReason.targetMatch();
      case LDKind.ruleMatch:
        {
          final ruleIndex = json['ruleIndex'] as num;
          final ruleId = json['ruleId'] as String;
          final inExperiment = (json['inExperiment'] ?? false) as bool;
          return LDEvaluationReason.ruleMatch(
              ruleIndex: ruleIndex.toInt(),
              ruleId: ruleId,
              inExperiment: inExperiment);
        }
      case LDKind.prerequisiteFailed:
        {
          final prerequisiteKey = json['prerequisiteKey'] as String;
          return LDEvaluationReason.prerequisiteFailed(
              prerequisiteKey: prerequisiteKey);
        }
      case LDKind.error:
        {
          final errorKind =
              _LDErrorKindSerialization.fromJson(json['errorKind']);
          return LDEvaluationReason.error(errorKind: errorKind);
        }
      case LDKind.unknown:
        return LDEvaluationReason.unknown();
    }
  }

  static Map<String, dynamic> toJson(LDEvaluationReason reason) {
    Map<String, dynamic> result = {};

    result['kind'] = _LDKindSerialization.toJson(reason.kind);
    if (reason.errorKind != null) {
      result['errorKind'] = _LDErrorKindSerialization.toJson(reason.errorKind!);
    }
    if (reason.inExperiment) {
      result['inExperiment'] = true;
    }
    if (reason.ruleIndex != null) {
      result['ruleIndex'] = reason.ruleIndex;
    }
    if (reason.ruleId != null) {
      result['ruleId'] = reason.ruleId;
    }
    if (reason.prerequisiteKey != null) {
      result['prerequisiteKey'] = reason.prerequisiteKey;
    }

    return result;
  }
}

final class LDEvaluationDetailSerialization {
  static LDEvaluationDetail<LDValue> fromJson(Map<String, dynamic> json) {
    final value = LDValueSerialization.fromJson(json['value']);
    final variationIndex = json['variationIndex'] as num?;
    final reasonJson =
        _LDEvaluationReasonSerialization.fromJson(json['reason']);

    return LDEvaluationDetail(value, variationIndex?.toInt(), reasonJson);
  }

  static Map<String, dynamic> toJson(
      LDEvaluationDetail<LDValue> evaluationResult) {
    Map<String, dynamic> result = {};

    result['value'] = LDValueSerialization.toJson(evaluationResult.value);
    result['variationIndex'] = evaluationResult.variationIndex;
    result['reason'] =
        _LDEvaluationReasonSerialization.toJson(evaluationResult.reason);

    return result;
  }
}
