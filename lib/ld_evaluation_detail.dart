part of launchdarkly_flutter_client_sdk;

enum LDKind { OFF, FALLTHROUGH, TARGET_MATCH, RULE_MATCH, PREREQUISITE_FAILED, ERROR, UNKNOWN }
enum LDErrorKind { CLIENT_NOT_READY, FLAG_NOT_FOUND, MALFORMED_FLAG, USER_NOT_SPECIFIED, WRONG_TYPE, EXCEPTION, UNKNOWN }

class LDEvaluationReason {
  static const _errorKindNames =
      { 'CLIENT_NOT_READY': LDErrorKind.CLIENT_NOT_READY, 'FLAG_NOT_FOUND': LDErrorKind.FLAG_NOT_FOUND
      , 'MALFORMED_FLAG': LDErrorKind.MALFORMED_FLAG, 'USER_NOT_SPECIFIED': LDErrorKind.USER_NOT_SPECIFIED
      , 'WRONG_TYPE': LDErrorKind.WRONG_TYPE, 'EXCEPTION': LDErrorKind.EXCEPTION, 'UNKNOWN': LDErrorKind.UNKNOWN};

  static const _OFF_INSTANCE = LDEvaluationReason._(LDKind.OFF);
  static const _FALLTHROUGH_INSTANCE = LDEvaluationReason._(LDKind.FALLTHROUGH);
  static const _TARGET_MATCH_INSTANCE = LDEvaluationReason._(LDKind.TARGET_MATCH);
  static const _UNKNOWN_INSTANCE = LDEvaluationReason._(LDKind.UNKNOWN);

  final LDKind kind;
  final int ruleIndex;
  final String ruleId;
  final String prerequisiteKey;
  final LDErrorKind errorKind;

  static LDEvaluationReason _fromCodecValue(dynamic value) {
    if (!(value is Map)) return null;
    Map<String, dynamic> map = Map.from(value as Map);
    switch (map['kind']) {
      case 'OFF': return off();
      case 'FALLTHROUGH': return fallthrough();
      case 'TARGET_MATCH': return targetMatch();
      case 'RULE_MATCH': return ruleMatch(ruleIndex: map['ruleIndex'], ruleId: map['ruleId']);
      case 'PREREQUISITE_FAILED': return prerequisiteFailed(prerequisiteKey: map['prerequisiteKey']);
      case 'ERROR': return error(errorKind: _errorKindNames[map['errorKind']]);
      case 'UNKNOWN': return unknown();
    }
  }

  const LDEvaluationReason._(this.kind, {this.ruleIndex = null, this.ruleId = null, this.prerequisiteKey = null, this.errorKind = null});

  static LDEvaluationReason off() => _OFF_INSTANCE;
  static LDEvaluationReason fallthrough() => _FALLTHROUGH_INSTANCE;
  static LDEvaluationReason targetMatch() => _TARGET_MATCH_INSTANCE;
  static LDEvaluationReason ruleMatch({int ruleIndex, String ruleId}) {
    return LDEvaluationReason._(LDKind.RULE_MATCH, ruleIndex: ruleIndex, ruleId: ruleId);
  }
  static LDEvaluationReason prerequisiteFailed({String prerequisiteKey}) {
    return LDEvaluationReason._(LDKind.PREREQUISITE_FAILED, prerequisiteKey: prerequisiteKey);
  }
  static LDEvaluationReason error({LDErrorKind errorKind}) {
    return LDEvaluationReason._(LDKind.ERROR, errorKind: errorKind);
  }
  static LDEvaluationReason unknown() => _UNKNOWN_INSTANCE;
}

class LDEvaluationDetail<T> {
  final T value;
  final int variationIndex;
  final LDEvaluationReason reason;

  const LDEvaluationDetail(this.value, this.variationIndex, this.reason);
}