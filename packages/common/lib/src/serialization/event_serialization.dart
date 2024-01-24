import '../../launchdarkly_dart_common.dart';

final class IdentifyEventSerialization {
  static Map<String, dynamic> toJson(IdentifyEvent event,
      {required bool allAttributesPrivate,
      required Set<AttributeReference> globalPrivateAttributes}) {
    final json = <String, dynamic>{};

    json['kind'] = 'identify';
    json['creationDate'] = event.creationDate.millisecondsSinceEpoch;
    json['context'] = LDContextSerialization.toJson(event.context,
        isEvent: true,
        allAttributesPrivate: allAttributesPrivate,
        globalPrivateAttributes: globalPrivateAttributes);

    return json;
  }
}

final class CustomEventSerialization {
  static Map<String, dynamic> toJson(CustomEvent event) {
    final json = <String, dynamic>{};

    json['kind'] = 'custom';
    json['key'] = event.key;
    json['creationDate'] = event.creationDate.millisecondsSinceEpoch;
    if (event.data != null && event.data?.type != LDValueType.nullType) {
      json['data'] = LDValueSerialization.toJson(event.data!);
    }
    if (event.metricValue != null) {
      json['metricValue'] = event.metricValue;
    }
    json['contextKeys'] = event.context.keys;

    return json;
  }
}

final class EvalEventSerialization {
  static Map<String, dynamic> toJson(EvalEvent event,
      {bool isDebug = false,
      required bool allAttributesPrivate,
      required Set<AttributeReference> globalPrivateAttributes}) {
    final json = <String, dynamic>{};

    json['kind'] = isDebug ? 'debug' : 'feature';
    json['creationDate'] = event.creationDate.millisecondsSinceEpoch;
    json['default'] = LDValueSerialization.toJson(event.defaultValue);
    json['key'] = event.flagKey;
    json['value'] = LDValueSerialization.toJson(event.evaluationDetail.value);
    json['context'] = LDContextSerialization.toJson(event.context,
        isEvent: true,
        allAttributesPrivate: allAttributesPrivate,
        globalPrivateAttributes: globalPrivateAttributes,
        redactAnonymous: !isDebug);

    if (event.version != null) {
      json['version'] = event.version;
    }

    if (event.evaluationDetail.variationIndex != null) {
      json['variation'] = event.evaluationDetail.variationIndex;
    }
    if (event.withReason && event.evaluationDetail.reason != null) {
      json['reason'] = LDEvaluationReasonSerialization.toJson(
          event.evaluationDetail.reason!);
    }

    return json;
  }
}

final class _FlagCounterSerialization {
  static Map<String, dynamic> toJson(FlagCounter counter) {
    final json = <String, dynamic>{};

    json['value'] = LDValueSerialization.toJson(counter.value);
    json['count'] = counter.count;
    if (counter.version != null) {
      json['version'] = counter.version;
    }
    if (counter.variation != null) {
      json['variation'] = counter.variation;
    }
    if (counter.unknown) {
      json['unknown'] = counter.unknown;
    }

    return json;
  }
}

final class _FlagSummarySerialization {
  static Map<String, dynamic> toJson(FlagSummary summary) {
    final json = <String, dynamic>{};

    json['default'] = LDValueSerialization.toJson(summary.defaultValue);
    json['contextKinds'] = summary.contextKinds;
    json['counters'] = summary.counters
        .map((counter) => _FlagCounterSerialization.toJson(counter))
        .toList();

    return json;
  }
}

final class SummaryEventSerialization {
  static Map<String, dynamic> toJson(SummaryEvent event) {
    final json = <String, dynamic>{};

    json['kind'] = 'summary';
    json['startDate'] = event.startDate.millisecondsSinceEpoch;
    json['endDate'] = event.endDate.millisecondsSinceEpoch;
    json['features'] = event.features.map(
        (key, value) => MapEntry(key, _FlagSummarySerialization.toJson(value)));

    return json;
  }
}
