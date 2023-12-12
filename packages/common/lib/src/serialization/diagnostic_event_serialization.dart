import '../events/diagnostic_events.dart';

final class _DiagnosticIdSerialization {
  static Map<String, dynamic> toJson(DiagnosticId id) {
    final json = <String, dynamic>{};

    json['diagnosticId'] = id.diagnosticId;
    json['sdkKeySuffix'] = id.sdkKeySuffix;

    return json;
  }
}

final class _DiagnosticSdkDataSerialization {
  static Map<String, dynamic> toJson(DiagnosticSdkData data) {
    final json = <String, dynamic>{};

    json['name'] = data.name;
    json['version'] = data.version;

    if (data.wrapperName != null) {
      json['wrapperName'] = data.wrapperName;
    }
    if (data.wrapperVersion != null) {
      json['wrapperVersion'] = data.wrapperVersion;
    }

    return json;
  }
}

final class _DiagnosticConfigDataSerialization {
  static Map<String, dynamic> toJson(DiagnosticConfigData data) {
    final json = <String, dynamic>{};

    json['customBaseUri'] = data.customBaseUri;
    json['customStreamUri'] = data.customStreamUri;
    json['eventsCapacity'] = data.eventsCapacity;
    json['connectTimeoutMillis'] = data.connectTimeoutMillis;
    json['eventsFlushIntervalMillis'] = data.eventsFlushIntervalMillis;
    json['pollingIntervalMillis'] = data.pollingIntervalMillis;
    json['reconnectTimeoutMillis'] = data.reconnectTimeoutMillis;
    json['streamingDisabled'] = data.streamingDisabled;
    json['offline'] = data.offline;
    json['allAttributesPrivate'] = data.allAttributesPrivate;
    json['diagnosticRecordingIntervalMillis'] =
        data.diagnosticRecordingIntervalMillis;

    if (data.backgroundPollingIntervalMillis != null) {
      json['backgroundPollingIntervalMillis'] =
          data.backgroundPollingIntervalMillis;
    }
    if (data.useReport != null) {
      json['useReport'] = data.useReport;
    }
    if (data.backgroundPollingDisabled != null) {
      json['backgroundPollingDisabled'] = data.backgroundPollingDisabled;
    }
    if (data.evaluationReasonsRequested != null) {
      json['evaluationReasonsRequested'] = data.evaluationReasonsRequested;
    }

    return json;
  }
}

final class _DiagnosticPlatformDataSerialization {
  static Map<String, dynamic> toJson(DiagnosticPlatformData data) {
    final json = <String, dynamic>{};

    if (data.name != null) {
      json['name'] = data.name;
    }
    if (data.osArch != null) {
      json['osArch'] = data.osArch;
    }
    if (data.osName != null) {
      json['osName'] = data.osName;
    }
    if (data.osVersion != null) {
      json['osVersion'] = data.osVersion;
    }
    if (data.additionalInformation != null) {
      json.addAll(data.additionalInformation!);
    }

    return json;
  }
}

final class DiagnosticInitEventSerialization {
  static Map<String, dynamic> toJson(DiagnosticInitEvent event) {
    final json = <String, dynamic>{};

    json['id'] = _DiagnosticIdSerialization.toJson(event.id);
    json['creationDate'] = event.creationDate.millisecondsSinceEpoch;
    json['sdk'] = _DiagnosticSdkDataSerialization.toJson(event.sdk);
    json['configuration'] =
        _DiagnosticConfigDataSerialization.toJson(event.configuration);
    json['platform'] =
        _DiagnosticPlatformDataSerialization.toJson(event.platform);

    return json;
  }
}

final class _StreamInitDataSerialization {
  static Map<String, dynamic> toJson(StreamInitData data) {
    final json = <String, dynamic>{};

    json['timestamp'] = data.timestamp.millisecondsSinceEpoch;
    json['failed'] = data.failed;
    json['durationMillis'] = data.durationMillis;

    return json;
  }
}

final class DiagnosticStatsEventSerialization {
  static Map<String, dynamic> toJson(DiagnosticStatsEvent event) {
    final json = <String, dynamic>{};

    json['id'] = _DiagnosticIdSerialization.toJson(event.id);
    json['creationDate'] = event.creationDate.millisecondsSinceEpoch;
    json['dataSinceDate'] = event.dataSinceDate.millisecondsSinceEpoch;
    json['droppedEvents'] = event.droppedEvents;
    json['eventsInLastBatch'] = event.eventsInLastBatch;

    json['streamInits'] = event.streamInits
        .map((e) => _StreamInitDataSerialization.toJson(e))
        .toList(growable: false);

    return json;
  }
}
