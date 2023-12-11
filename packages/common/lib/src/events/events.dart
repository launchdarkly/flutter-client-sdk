import '../ld_context.dart';
import '../ld_evaluation_detail.dart';
import '../ld_value.dart';

final class EvalEvent {
  final String flagKey;
  final DateTime creationDate;
  final LDValue defaultValue;
  final LDEvaluationDetail evaluationDetail;
  final LDContext context;

  /// Used to determine if the reason should be included in the output JSON.
  final bool withReason;

  /// Used in determining if the event processor should output a feature event.
  final bool trackEvent;

  /// Used in determining if the event processor should output a debug event.
  final DateTime? debugEventsUntilDate;

  final num? version;

  EvalEvent(
      {required this.flagKey,
      required this.defaultValue,
      required this.evaluationDetail,
      required this.context,
      required this.withReason,
      required this.trackEvent,
      DateTime? creationDate,
      this.debugEventsUntilDate,
      this.version})
      : creationDate = creationDate ?? DateTime.now();
}

final class IdentifyEvent {
  final DateTime creationDate;
  final LDContext context;

  IdentifyEvent({required this.context, DateTime? creationDate})
      : creationDate = creationDate ?? DateTime.now();
}

final class CustomEvent {
  final String key;
  final DateTime creationDate;
  final LDContext context;
  final num? metricValue;
  final LDValue? data;

  CustomEvent({
    required this.key,
    required this.context,
    this.metricValue,
    this.data,
    DateTime? creationDate,
  }) : creationDate = creationDate ?? DateTime.now();
}

final class FlagCounter {
  final LDValue value;
  final num count;
  final int? variation;
  final int? version;
  final bool unknown;

  FlagCounter(
      {required this.value,
      required this.count,
      this.variation,
      this.version,
      bool? unknown})
      : unknown = unknown ?? false;
}

final class FlagSummary {
  final LDValue defaultValue;
  final List<FlagCounter> counters;
  final List<String> contextKinds;

  FlagSummary(
      {required this.defaultValue,
      required this.counters,
      required this.contextKinds});
}

final class SummaryEvent {
  final DateTime startDate;
  final DateTime endDate;
  final Map<String, FlagSummary> features;

  SummaryEvent(
      {required this.startDate, required this.endDate, required this.features});
}
