/// Enumerated type defining the possible reasons for a flag evaluation result, used in [LDEvaluationReason].
enum LDKind {
  /// Indicates that the flag was off and therefore returned its configured off value.
  off('OFF'),

  /// Indicates that the flag was on but the user did not match any targets or rules, resulting in the fallback value.
  fallthrough('FALLTHROUGH'),

  /// Indicates that the context key was specifically targeted for this flag.
  targetMatch('TARGET_MATCH'),

  /// Indicates that the context matched one of the flag's rules.
  ruleMatch('RULE_MATCH'),

  /// Indicates that the flag was considered off because it had at least one prerequisite flag that was off or did not
  /// return the desired variation.
  prerequisiteFailed('PREREQUISITE_FAILED'),

  /// Indicates that the flag could not be evaluated, e.g. because it does not exist or due to an unexpected error.
  ///
  /// In this case the result value will be the default value that the caller passed to the client. See the
  /// [LDErrorKind] for the defined error cases which can be retrieved from [LDEvaluationReason.errorKind].
  error('ERROR'),

  /// Indicates that LaunchDarkly provided an [LDKind] value that is not supported by this version of the SDK.
  unknown('UNKNOWN');

  final String _value;

  const LDKind(this._value);

  @override
  String toString() {
    return _value;
  }

  static LDKind fromString(String value) {
    return LDKind.values.firstWhere((entry) => entry._value == value,
        orElse: () => LDKind.unknown);
  }
}

/// Enumerated type defining the defined error cases for an [LDEvaluationReason] with the kind [LDKind.ERROR].
///
/// This field can be retrieved from an [LDEvaluationReason] with the kind [LDKind.ERROR] through the
/// [LDEvaluationReason.errorKind] property.
enum LDErrorKind {
  /// Indicates that the caller tried to evaluate a flag before the client had successfully initialized.
  clientNotReady('CLIENT_NOT_READY'),

  /// Indicates that the caller provided a flag key that did not match any known flag.
  flagNotFound('FLAG_NOT_FOUND'),

  /// Indicates that there was an internal inconsistency in the flag data, e.g. a rule specified a non-existent
  /// variation.
  malformedFlag('MALFORMED_FLAG'),

  /// Indicates that the caller passed `null` for the `context` parameter, or the context lacked a key.  This
  /// enum name is an artifact of user being the predecessor to context.
  userNotSpecified('USER_NOT_SPECIFIED'),

  /// Indicates that the result value was not of the requested type, e.g. you called `LDClient.boolVariationDetail` but
  /// the flag value was an `int`.
  wrongType('WRONG_TYPE'),

  /// Indicates that an unexpected exception stopped flag evaluation.
  exception('EXCEPTION'),

  /// Indicates that LaunchDarkly provided an [LDErrorKind] value that is not supported by this version of the SDK.
  unknown('UNKNOWN');

  final String _value;

  const LDErrorKind(this._value);

  @override
  String toString() {
    return _value;
  }

  static LDErrorKind fromString(String value) {
    return LDErrorKind.values.firstWhere((entry) => entry._value == value,
        orElse: () => LDErrorKind.unknown);
  }
}

/// Describes the reason that a flag evaluation produced a particular value.
final class LDEvaluationReason {
  static const _offInstance = LDEvaluationReason._(LDKind.off);
  static const _fallthroughInstance =
      LDEvaluationReason._(LDKind.fallthrough, inExperiment: false);
  static const _fallthroughExperimentInsance =
      LDEvaluationReason._(LDKind.fallthrough, inExperiment: true);
  static const _targetMatchInstance =
      LDEvaluationReason._(LDKind.targetMatch);
  static const _unknownInstance = LDEvaluationReason._(LDKind.unknown);

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
  final bool inExperiment;

  /// The key of the first prerequisite that failed when [kind] is [LDKind.PREREQUISITE_FAILED].
  ///
  /// For all other kinds, this field is undefined.
  final String? prerequisiteKey;

  /// The type of the error responsible when the [kind] is [LDKind.ERROR].
  ///
  /// For all other kinds, this field is undefined.
  final LDErrorKind? errorKind;

  const LDEvaluationReason._(this.kind,
      {this.ruleIndex,
      this.ruleId,
      this.prerequisiteKey,
      this.errorKind,
      this.inExperiment = false});

  /// Returns an [LDEvaluationReason] with the kind [LDKind.OFF].
  static LDEvaluationReason off() => _offInstance;

  /// Returns an [LDEvaluationReason] with the kind [LDKind.FALLTHROUGH].
  static LDEvaluationReason fallthrough({bool? inExperiment}) {
    if (inExperiment == true) {
      return _fallthroughExperimentInsance;
    }
    return _fallthroughInstance;
  }

  /// Returns an [LDEvaluationReason] with the kind [LDKind.TARGET_MATCH].
  static LDEvaluationReason targetMatch() => _targetMatchInstance;

  /// Returns an [LDEvaluationReason] with the kind [LDKind.RULE_MATCH] and the given [ruleIndex] and [ruleId].
  static LDEvaluationReason ruleMatch(
      {required int ruleIndex, required String ruleId, bool? inExperiment}) {
    return LDEvaluationReason._(LDKind.ruleMatch,
        ruleIndex: ruleIndex,
        ruleId: ruleId,
        inExperiment: inExperiment ?? false);
  }

  /// Returns an [LDEvaluationReason] with the kind [LDKind.PREREQUISITE_FAILED] and the given [prerequisiteKey].
  static LDEvaluationReason prerequisiteFailed(
      {required String prerequisiteKey}) {
    return LDEvaluationReason._(LDKind.prerequisiteFailed,
        prerequisiteKey: prerequisiteKey);
  }

  /// Returns an [LDEvaluationReason] with the kind [LDKind.ERROR] and the given [errorKind].
  static LDEvaluationReason error(
      {LDErrorKind errorKind = LDErrorKind.unknown}) {
    return LDEvaluationReason._(LDKind.error, errorKind: errorKind);
  }

  /// Returns an [LDEvaluationReason] with the kind [LDKind.UNKNOWN].
  static LDEvaluationReason unknown() => _unknownInstance;

  @override
  String toString() {
    return 'LDEvaluationReason{kind: $kind, ruleIndex: $ruleIndex, '
        'ruleId: $ruleId, inExperiment: $inExperiment,'
        ' prerequisiteKey: $prerequisiteKey, errorKind: $errorKind}';
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is LDEvaluationReason &&
          kind == other.kind &&
          ruleIndex == other.ruleIndex &&
          ruleId == other.ruleId &&
          inExperiment == other.inExperiment &&
          prerequisiteKey == other.prerequisiteKey &&
          errorKind == other.errorKind;

  @override
  int get hashCode =>
      kind.hashCode ^
      ruleIndex.hashCode ^
      ruleId.hashCode ^
      inExperiment.hashCode ^
      prerequisiteKey.hashCode ^
      errorKind.hashCode;
}

/// Class returned by the "variation detail" methods such as [LDClient.boolVariationDetail], combining the result of
/// the evaluation with an explanation of how it was calculated.
final class LDEvaluationDetail<T> {
  /// The result of the flag evaluation.
  final T value;

  /// The index of the returned flag within the list of variations if the default value was not returned.
  final int? variationIndex;

  /// An object describing the primary reason for the resultant flag value.
  ///
  /// See [LDEvaluationReason] for details.
  final LDEvaluationReason? reason;

  /// Constructor for [LDEvaluationDetail].
  const LDEvaluationDetail(this.value, this.variationIndex, this.reason);

  @override
  String toString() {
    return 'LDEvaluationDetail{value: $value, variationIndex:'
        ' $variationIndex, reason: $reason}';
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is LDEvaluationDetail &&
          value == other.value;

  @override
  int get hashCode => value.hashCode;
}
