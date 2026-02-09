import '../collections.dart';
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

  final int? version;

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

  @override
  String toString() {
    return 'EvalEvent{flagKey: $flagKey, creationDate: $creationDate, defaultValue: $defaultValue, evaluationDetail: $evaluationDetail, context: $context, withReason: $withReason, trackEvent: $trackEvent, debugEventsUntilDate: $debugEventsUntilDate, version: $version}';
  }
}

final class IdentifyEvent {
  final DateTime creationDate;
  final LDContext context;

  IdentifyEvent({required this.context, DateTime? creationDate})
      : creationDate = creationDate ?? DateTime.now();

  @override
  String toString() {
    return 'IdentifyEvent{creationDate: $creationDate, context: $context}';
  }
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

  @override
  String toString() {
    return 'CustomEvent{key: $key, creationDate: $creationDate, context: $context, metricValue: $metricValue, data: $data}';
  }
}

final class FlagCounter {
  final LDValue value;
  final int count;
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

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is FlagCounter &&
          value == other.value &&
          count == other.count &&
          variation == other.variation &&
          version == other.version &&
          unknown == other.unknown;

  @override
  int get hashCode =>
      value.hashCode ^
      count.hashCode ^
      variation.hashCode ^
      version.hashCode ^
      unknown.hashCode;

  @override
  String toString() {
    return 'FlagCounter{value: $value, count: $count, variation: $variation, version: $version, unknown: $unknown}';
  }
}

final class FlagSummary {
  final LDValue defaultValue;
  final List<FlagCounter> counters;
  final List<String> contextKinds;

  FlagSummary(
      {required this.defaultValue,
      required this.counters,
      required this.contextKinds});

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is FlagSummary &&
          defaultValue == other.defaultValue &&
          counters.equals(other.counters) &&
          contextKinds.equals(other.contextKinds);

  @override
  int get hashCode =>
      defaultValue.hashCode ^ counters.hashCode ^ contextKinds.hashCode;

  @override
  String toString() {
    return 'FlagSummary{defaultValue: $defaultValue, counters: $counters, contextKinds: $contextKinds}';
  }
}

final class SummaryEvent {
  final DateTime startDate;
  final DateTime endDate;
  final Map<String, FlagSummary> features;
  final LDContext context;

  SummaryEvent({
    required this.startDate,
    required this.endDate,
    required this.features,
    required this.context,
  });

  @override
  String toString() {
    return 'SummaryEvent{startDate: $startDate, endDate: $endDate, features: $features, context: $context}';
  }
}
