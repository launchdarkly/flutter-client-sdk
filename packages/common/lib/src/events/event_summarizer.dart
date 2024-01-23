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

/// Tracks evaluation events in order to generate summary events.
final class EventSummarizer {
  int _startDate = 0;
  int _endDate = 0;

  final Map<FlagKey, _SummaryCounter> _features = {};

  void summarize(EvalEvent event) {
    if (!_features.containsKey(event.flagKey)) {
      _features[event.flagKey] = _SummaryCounter(event.defaultValue);
    }
    _features[event.flagKey]!.count(
        event.evaluationDetail.variationIndex,
        event.version,
        event.evaluationDetail.value,
        event.context.attributesByKind.keys.toSet());

    if (event.creationDate.millisecondsSinceEpoch < _startDate ||
        _startDate == 0) {
      _startDate = event.creationDate.millisecondsSinceEpoch;
    }
    if (event.creationDate.millisecondsSinceEpoch > _endDate) {
      _endDate = event.creationDate.millisecondsSinceEpoch;
    }
  }

  void _clear() {
    _startDate = 0;
    _endDate = 0;
    _features.clear();
  }

  SummaryEvent? createEventAndReset() {
    final features = <String, FlagSummary>{};

    if (_features.isEmpty) {
      return null;
    }

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

    _clear();

    return SummaryEvent(
        startDate: startDate, endDate: endDate, features: features);
  }
}
