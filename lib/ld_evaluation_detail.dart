// @dart=2.12
part of launchdarkly_flutter_client_sdk;

/// Enumerated type defining the possible reasons for a flag evaluation result, used in [LDEvaluationReason].
enum LDKind {
  /// Indicates that the flag was off and therefore returned its configured off value.
  OFF,
  /// Indicates that the flag was on but the user did not match any targets or rules, resulting in the fallback value.
  FALLTHROUGH,
  /// Indicates that the context key was specifically targeted for this flag.
  TARGET_MATCH,
  /// Indicates that the context matched one of the flag's rules.
  RULE_MATCH,
  /// Indicates that the flag was considered off because it had at least one prerequisite flag that was off or did not
  /// return the desired variation.
  PREREQUISITE_FAILED,
  /// Indicates that the flag could not be evaluated, e.g. because it does not exist or due to an unexpected error.
  ///
  /// In this case the result value will be the default value that the caller passed to the client. See the
  /// [LDErrorKind] for the defined error cases which can be retrieved from [LDEvaluationReason.errorKind].
  ERROR,
  /// Indicates that LaunchDarkly provided an [LDKind] value that is not supported by this version of the SDK.
  UNKNOWN
}

/// Enumerated type defining the defined error cases for an [LDEvaluationReason] with the kind [LDKind.ERROR].
///
/// This field can be retrieved from an [LDEvaluationReason] with the kind [LDKind.ERROR] through the
/// [LDEvaluationReason.errorKind] property.
enum LDErrorKind {
  /// Indicates that the caller tried to evaluate a flag before the client had successfully initialized.
  CLIENT_NOT_READY,
  /// Indicates that the caller provided a flag key that did not match any known flag.
  FLAG_NOT_FOUND,
  /// Indicates that there was an internal inconsistency in the flag data, e.g. a rule specified a non-existent
  /// variation.
  MALFORMED_FLAG,
  /// Indicates that the caller passed `null` for the `context` parameter, or the context lacked a key.  This
  /// enum name is an artifact of user being the predecessor to context.
  USER_NOT_SPECIFIED,
  /// Indicates that the result value was not of the requested type, e.g. you called `LDClient.boolVariationDetail` but
  /// the flag value was an `int`.
  WRONG_TYPE,
  /// Indicates that an unexpected exception stopped flag evaluation.
  EXCEPTION,
  /// Indicates that LaunchDarkly provided an [LDErrorKind] value that is not supported by this version of the SDK.
  UNKNOWN
}

/// Describes the reason that a flag evaluation produced a particular value.
class LDEvaluationReason {
  static const _errorKindNames =
      { 'CLIENT_NOT_READY': LDErrorKind.CLIENT_NOT_READY, 'FLAG_NOT_FOUND': LDErrorKind.FLAG_NOT_FOUND
      , 'MALFORMED_FLAG': LDErrorKind.MALFORMED_FLAG, 'USER_NOT_SPECIFIED': LDErrorKind.USER_NOT_SPECIFIED
      , 'WRONG_TYPE': LDErrorKind.WRONG_TYPE, 'EXCEPTION': LDErrorKind.EXCEPTION, 'UNKNOWN': LDErrorKind.UNKNOWN};

  static const _OFF_INSTANCE = LDEvaluationReason._(LDKind.OFF);
  static const _FALLTHROUGH_INSTANCE = LDEvaluationReason._(LDKind.FALLTHROUGH, inExperiment: false);
  static const _FALLTHROUGH_EXPERIMENT_INSTANCE = LDEvaluationReason._(LDKind.FALLTHROUGH, inExperiment: true);
  static const _TARGET_MATCH_INSTANCE = LDEvaluationReason._(LDKind.TARGET_MATCH);
  static const _UNKNOWN_INSTANCE = LDEvaluationReason._(LDKind.UNKNOWN);

  /// The general category for the reason responsible for the evaluation result.
  ///
  /// See [LDKind] for details on the types of reasons.
  final LDKind kind;
  /// The index of the rule that match the user when [kind] is [LDKind.RULE_MATCH].
  ///
  /// For all other kinds, this field is undefined.
  final int? ruleIndex;
  /// The id of the rule that match the user when [kind] is [LDKind.RULE_MATCH].
  ///
  /// For all other kinds, this field is undefined.
  final String? ruleId;
  /// Whether the rule or fallthrough is part of an experiment when [kind] is [LDKind.RULE_MATCH] or [LDKind.FALLTHROUGH].
  ///
  /// For all other kinds, this field is undefined.
  final bool? inExperiment;
  /// The key of the first prerequisite that failed when [kind] is [LDKind.PREREQUISITE_FAILED].
  ///
  /// For all other kinds, this field is undefined.
  final String? prerequisiteKey;
  /// The type of the error responsible when the [kind] is [LDKind.ERROR].
  ///
  /// For all other kinds, this field is undefined.
  final LDErrorKind? errorKind;

  static LDEvaluationReason _fromCodecValue(dynamic value) {
    if (!(value is Map)) return unknown();
    Map<String, dynamic> map = Map.from(value as Map);
    switch (map['kind']) {
      case 'OFF': return off();
      case 'FALLTHROUGH': return fallthrough(inExperiment: map['inExperiment']);
      case 'TARGET_MATCH': return targetMatch();
      case 'RULE_MATCH': return ruleMatch(ruleIndex: map['ruleIndex'], ruleId: map['ruleId'], inExperiment: map['inExperiment'] ?? false);
      case 'PREREQUISITE_FAILED':
        String? prereqKey = map['prerequisiteKey'];
        if (prereqKey == null) {
          return unknown();
        }
        return prerequisiteFailed(prerequisiteKey: prereqKey);
      case 'ERROR': return error(errorKind: _errorKindNames[map['errorKind']] ?? LDErrorKind.UNKNOWN);
      default: return unknown();
    }
  }

  const LDEvaluationReason._(this.kind, {this.ruleIndex, this.ruleId, this.prerequisiteKey, this.errorKind, this.inExperiment});

  /// Returns an [LDEvaluationReason] with the kind [LDKind.OFF].
  static LDEvaluationReason off() => _OFF_INSTANCE;
  /// Returns an [LDEvaluationReason] with the kind [LDKind.FALLTHROUGH].
  static LDEvaluationReason fallthrough({bool? inExperiment}) {
    if (inExperiment == true) {
      return _FALLTHROUGH_EXPERIMENT_INSTANCE;
    }
    return _FALLTHROUGH_INSTANCE;
  }
  /// Returns an [LDEvaluationReason] with the kind [LDKind.TARGET_MATCH].
  static LDEvaluationReason targetMatch() => _TARGET_MATCH_INSTANCE;
  /// Returns an [LDEvaluationReason] with the kind [LDKind.RULE_MATCH] and the given [ruleIndex] and [ruleId].
  static LDEvaluationReason ruleMatch({required int ruleIndex, required String ruleId, bool? inExperiment}) {
    return LDEvaluationReason._(LDKind.RULE_MATCH, ruleIndex: ruleIndex, ruleId: ruleId, inExperiment: inExperiment ?? false);
  }
  /// Returns an [LDEvaluationReason] with the kind [LDKind.PREREQUISITE_FAILED] and the given [prerequisiteKey].
  static LDEvaluationReason prerequisiteFailed({required String prerequisiteKey}) {
    return LDEvaluationReason._(LDKind.PREREQUISITE_FAILED, prerequisiteKey: prerequisiteKey);
  }
  /// Returns an [LDEvaluationReason] with the kind [LDKind.ERROR] and the given [errorKind].
  static LDEvaluationReason error({LDErrorKind errorKind = LDErrorKind.UNKNOWN}) {
    return LDEvaluationReason._(LDKind.ERROR, errorKind: errorKind);
  }
  /// Returns an [LDEvaluationReason] with the kind [LDKind.UNKNOWN].
  static LDEvaluationReason unknown() => _UNKNOWN_INSTANCE;
}

/// Class returned by the "variation detail" methods such as [LDClient.boolVariationDetail], combining the result of
/// the evaluation with an explanation of how it was calculated.
class LDEvaluationDetail<T> {
  /// The result of the flag evaluation.
  final T value;
  /// The index of the returned flag within the list of variations if the default value was not returned.
  final int variationIndex;
  /// An object describing the primary reason for the resultant flag value.
  ///
  /// See [LDEvaluationReason] for details.
  final LDEvaluationReason reason;

  /// Constructor for [LDEvaluationDetail].
  const LDEvaluationDetail(this.value, this.variationIndex, this.reason);
}
