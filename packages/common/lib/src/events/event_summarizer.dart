import '../ld_context.dart';
import '../ld_value.dart';
import 'events.dart';

typedef Variation = int?;
typedef Version = int?;
typedef FlagKey = String;

final class _Counter {
  int count = 0;
  final LDValue value;

  void increment() {
    count++;
  }

  _Counter(this.value);
}

final class _SummaryCounter {
  LDValue defaultValue;
  final Set<String> contextKinds = {};
  final Map<Variation, Map<Version, _Counter>> counters = {};

  _SummaryCounter(this.defaultValue);

  void count(Variation variation, Version version, LDValue value,
      Set<String> inKinds) {
    contextKinds.addAll(inKinds);
    if (!counters.containsKey(variation)) {
      counters[variation] = {};
    }
    final counterForVariation = counters[variation]!;
    if (!counterForVariation.containsKey(version)) {
      counterForVariation[version] = _Counter(value);
    }
    counterForVariation[version]!.increment();
  }
}

/// Accumulates summary statistics for a single context.
final class _ContextAccumulator {
  int _startDate = 0;
  int _endDate = 0;
  final LDContext context;
  final bool includeContextInSummary;
  final Map<FlagKey, _SummaryCounter> _features = {};

  _ContextAccumulator(this.context, {required this.includeContextInSummary});

  void count(FlagKey flagKey, LDValue defaultValue, Variation variation,
      Version version, LDValue value, Set<String> contextKinds) {
    if (!_features.containsKey(flagKey)) {
      _features[flagKey] = _SummaryCounter(defaultValue);
    }
    _features[flagKey]!.count(variation, version, value, contextKinds);
  }

  void updateDates(DateTime eventDate) {
    final timestamp = eventDate.millisecondsSinceEpoch;
    if (timestamp < _startDate || _startDate == 0) {
      _startDate = timestamp;
    }
    if (timestamp > _endDate) {
      _endDate = timestamp;
    }
  }

  SummaryEvent createSummary() {
    final features = <String, FlagSummary>{};

    for (var feature in _features.entries) {
      final counters = <FlagCounter>[];

      for (var MapEntry(key: variation, value: value)
          in feature.value.counters.entries) {
        for (var MapEntry(key: version, value: counter) in value.entries) {
          counters.add(FlagCounter(
              value: counter.value,
              count: counter.count,
              variation: variation,
              version: version,
              unknown: version == null));
        }
      }

      features[feature.key] = FlagSummary(
          defaultValue: feature.value.defaultValue,
          counters: counters,
          contextKinds: feature.value.contextKinds.toList());
    }

    final startDate = DateTime.fromMillisecondsSinceEpoch(_startDate);
    final endDate = DateTime.fromMillisecondsSinceEpoch(_endDate);

    return SummaryEvent(
      startDate: startDate,
      endDate: endDate,
      features: features,
      context: includeContextInSummary ? context : null,
    );
  }
}

/// Tracks evaluation events in order to generate summary events.
/// When [summariesPerContext] is true, generates one summary event per unique context.
/// When false, generates a single global summary event without context information.
final class EventSummarizer {
  final bool summariesPerContext;
  final Map<LDContext?, _ContextAccumulator> _accumulatorsByContext = {};

  EventSummarizer({this.summariesPerContext = true});

  void summarize(EvalEvent event) {
    // Skip invalid contexts
    if (!event.context.valid) {
      return;
    }

    // When per-context summaries are disabled, use null as the key so all
    // events go into a single accumulator. When enabled, use the actual context
    // as the key so each unique context gets its own accumulator.
    final contextKey = summariesPerContext ? event.context : null;

    // Get or create accumulator for this context key
    final accumulator = _accumulatorsByContext.putIfAbsent(
      contextKey,
      () => _ContextAccumulator(event.context,
          includeContextInSummary: summariesPerContext),
    );

    // Update the accumulator
    accumulator.count(
      event.flagKey,
      event.defaultValue,
      event.evaluationDetail.variationIndex,
      event.version,
      event.evaluationDetail.value,
      event.context.attributesByKind.keys.toSet(),
    );
    accumulator.updateDates(event.creationDate);
  }

  List<SummaryEvent> createEventsAndReset() {
    if (_accumulatorsByContext.isEmpty) {
      return [];
    }

    final events = _accumulatorsByContext.values
        .map((accumulator) => accumulator.createSummary())
        .toList();

    _accumulatorsByContext.clear();

    return events;
  }
}
