import 'ld_evaluation_detail.dart';
import 'ld_value.dart';

/// This type represents the "Flag" model for client-side SDKs. It is common
/// because server-side SDKs can generate data which is used by client-side SDKs
/// for bootstrapping. So client-side SDKs consume this model and server-side
/// SDKs produce it.
final class LDEvaluationResult {
  /// Incremented by LaunchDarkly each time the flag's state changes.
  final int version;

  /// The version of the flag. Changes when modifications are made to the flag.
  final int? flagVersion;

  ///  True if a client SDK should track events for this flag.
  final bool trackEvents;

  /// True if a client SDK should track reasons for this flag.
  final bool trackReason;

  /// A millisecond timestamp, which if the current time is before, a client SDK
  /// should send debug events for the flag.
  final int? debugEventsUntilDate;

  /// Details of the flags evaluation.
  final LDEvaluationDetail<LDValue> detail;

  const LDEvaluationResult(
      {required this.version,
      this.flagVersion,
      required this.detail,
      this.trackEvents = false,
      this.trackReason = false,
      this.debugEventsUntilDate});

  @override
  String toString() {
    return 'LDEvaluationResult{version: $version, flagVersion: $flagVersion,'
        ' trackEvents: $trackEvents, trackReason: $trackReason,'
        ' debugEventsUntilDate: $debugEventsUntilDate,'
        ' detail: $detail}';
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is LDEvaluationResult &&
          version == other.version &&
          flagVersion == other.flagVersion &&
          trackEvents == other.trackEvents &&
          trackReason == other.trackReason &&
          debugEventsUntilDate == other.debugEventsUntilDate &&
          detail == other.detail;

  @override
  int get hashCode =>
      version.hashCode ^
      flagVersion.hashCode ^
      trackEvents.hashCode ^
      trackReason.hashCode ^
      debugEventsUntilDate.hashCode ^
      detail.hashCode;
}
