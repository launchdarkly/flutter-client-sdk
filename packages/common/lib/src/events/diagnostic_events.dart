import '../collections.dart';

final class DiagnosticId {
  final String diagnosticId;
  final String sdkKeySuffix;

  const DiagnosticId({required this.diagnosticId, required this.sdkKeySuffix});

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is DiagnosticId &&
          diagnosticId == other.diagnosticId &&
          sdkKeySuffix == other.sdkKeySuffix;

  @override
  int get hashCode => diagnosticId.hashCode ^ sdkKeySuffix.hashCode;

  @override
  String toString() {
    return 'DiagnosticId{diagnosticId: $diagnosticId, sdkKeySuffix: $sdkKeySuffix}';
  }
}

final class DiagnosticSdkData {
  final String name;
  final String version;
  final String? wrapperName;
  final String? wrapperVersion;

  const DiagnosticSdkData(
      {required this.name,
      required this.version,
      this.wrapperName,
      this.wrapperVersion});

  @override
  String toString() {
    return 'DiagnosticSdkData{name: $name, version: $version, wrapperName:'
        ' $wrapperName, wrapperVersion: $wrapperVersion}';
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is DiagnosticSdkData &&
          name == other.name &&
          version == other.version &&
          wrapperName == other.wrapperName &&
          wrapperVersion == other.wrapperVersion;

  @override
  int get hashCode =>
      name.hashCode ^
      version.hashCode ^
      wrapperName.hashCode ^
      wrapperVersion.hashCode;
}

final class DiagnosticConfigData {
  // All client types
  final bool customBaseUri;
  final bool customStreamUri;
  final int eventsCapacity;
  final int connectTimeoutMillis;
  final int eventsFlushIntervalMillis;
  final int pollingIntervalMillis;
  final int reconnectTimeoutMillis;
  final bool streamingDisabled;
  final bool offline;
  final bool allAttributesPrivate;
  final int diagnosticRecordingIntervalMillis;

  // Client-side SDKs.
  final int? backgroundPollingIntervalMillis;
  final bool? useReport;
  final bool? backgroundPollingDisabled;
  final bool? evaluationReasonsRequested;

  // Unsupported
  // int socketTimeoutMillis;
  // bool usingRelayDaemon;
  // int contextKeysCapacity;
  // int userKeysFlushIntervalMillis;
  // bool usingProxy;
  // bool usingProxyAuthenticator;

  // String dataStoreType;
  // int startWaitMillis;
  // int samplingInterval;
  // int? mobileKeyCount;

  const DiagnosticConfigData(
      {required this.customBaseUri,
      required this.customStreamUri,
      required this.eventsCapacity,
      required this.connectTimeoutMillis,
      required this.eventsFlushIntervalMillis,
      required this.pollingIntervalMillis,
      required this.reconnectTimeoutMillis,
      required this.streamingDisabled,
      required this.offline,
      required this.allAttributesPrivate,
      required this.diagnosticRecordingIntervalMillis,
      this.backgroundPollingDisabled,
      this.useReport,
      this.backgroundPollingIntervalMillis,
      this.evaluationReasonsRequested});

  @override
  String toString() {
    return 'DiagnosticConfigData{customBaseUri: $customBaseUri, '
        'customStreamUri: $customStreamUri, eventsCapacity: $eventsCapacity,'
        ' connectTimeoutMillis: $connectTimeoutMillis,'
        ' eventsFlushIntervalMillis: $eventsFlushIntervalMillis,'
        ' pollingIntervalMillis: $pollingIntervalMillis,'
        ' reconnectTimeoutMillis: $reconnectTimeoutMillis,'
        ' streamingDisabled: $streamingDisabled, offline: $offline,'
        ' allAttributesPrivate: $allAttributesPrivate,'
        ' diagnosticRecordingIntervalMillis: '
        '$diagnosticRecordingIntervalMillis, backgroundPollingIntervalMillis: '
        '$backgroundPollingIntervalMillis, useReport: $useReport, '
        'backgroundPollingDisabled: $backgroundPollingDisabled, '
        'evaluationReasonsRequested: $evaluationReasonsRequested}';
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is DiagnosticConfigData &&
          runtimeType == other.runtimeType &&
          customBaseUri == other.customBaseUri &&
          customStreamUri == other.customStreamUri &&
          eventsCapacity == other.eventsCapacity &&
          connectTimeoutMillis == other.connectTimeoutMillis &&
          eventsFlushIntervalMillis == other.eventsFlushIntervalMillis &&
          pollingIntervalMillis == other.pollingIntervalMillis &&
          reconnectTimeoutMillis == other.reconnectTimeoutMillis &&
          streamingDisabled == other.streamingDisabled &&
          offline == other.offline &&
          allAttributesPrivate == other.allAttributesPrivate &&
          diagnosticRecordingIntervalMillis ==
              other.diagnosticRecordingIntervalMillis &&
          backgroundPollingIntervalMillis ==
              other.backgroundPollingIntervalMillis &&
          useReport == other.useReport &&
          backgroundPollingDisabled == other.backgroundPollingDisabled &&
          evaluationReasonsRequested == other.evaluationReasonsRequested;

  @override
  int get hashCode =>
      customBaseUri.hashCode ^
      customStreamUri.hashCode ^
      eventsCapacity.hashCode ^
      connectTimeoutMillis.hashCode ^
      eventsFlushIntervalMillis.hashCode ^
      pollingIntervalMillis.hashCode ^
      reconnectTimeoutMillis.hashCode ^
      streamingDisabled.hashCode ^
      offline.hashCode ^
      allAttributesPrivate.hashCode ^
      diagnosticRecordingIntervalMillis.hashCode ^
      backgroundPollingIntervalMillis.hashCode ^
      useReport.hashCode ^
      backgroundPollingDisabled.hashCode ^
      evaluationReasonsRequested.hashCode;
}

final class DiagnosticPlatformData {
  final String? name;
  final String? osArch;
  final String? osName;
  final String? osVersion;

  final Map<String, String>? additionalInformation;

  const DiagnosticPlatformData(
      {this.name,
      this.osArch,
      this.osName,
      this.osVersion,
      this.additionalInformation});

  @override
  String toString() {
    return 'DiagnosticPlatformData{name: $name, osArch: $osArch, osName: '
        '$osName, osVersion: $osVersion, additionalInformation:'
        ' $additionalInformation}';
  }

  bool _additionalEquals(Map<String, String>? otherAdditional) {
    if (additionalInformation == null && otherAdditional == null) {
      return true;
    }
    if (additionalInformation != null && otherAdditional != null) {
      return additionalInformation!.equals(otherAdditional);
    }
    return false;
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is DiagnosticPlatformData &&
          name == other.name &&
          osArch == other.osArch &&
          osName == other.osName &&
          osVersion == other.osVersion &&
          _additionalEquals(other.additionalInformation);

  @override
  int get hashCode =>
      name.hashCode ^
      osArch.hashCode ^
      osName.hashCode ^
      osVersion.hashCode ^
      additionalInformation.hashCode;
}

final class DiagnosticInitEvent {
  final DiagnosticId id;
  final DateTime creationDate;
  final DiagnosticSdkData sdk;
  final DiagnosticConfigData configuration;
  final DiagnosticPlatformData platform;

  DiagnosticInitEvent(
      {required this.id,
      required this.creationDate,
      required this.sdk,
      required this.configuration,
      required this.platform});

  @override
  String toString() {
    return 'DiagnosticInitEvent{id: $id, creationDate: $creationDate, sdk:'
        ' $sdk, configuration: $configuration, platform: $platform}';
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is DiagnosticInitEvent &&
          id == other.id &&
          creationDate == other.creationDate &&
          sdk == other.sdk &&
          configuration == other.configuration &&
          platform == other.platform;

  @override
  int get hashCode =>
      id.hashCode ^
      creationDate.hashCode ^
      sdk.hashCode ^
      configuration.hashCode ^
      platform.hashCode;
}

final class StreamInitData {
  final DateTime timestamp;
  final bool failed;
  final int durationMillis;

  StreamInitData(
      {required this.timestamp,
      required this.failed,
      required this.durationMillis});

  @override
  String toString() {
    return 'StreamInitData{timestamp: $timestamp, failed: $failed, '
        'durationMillis: $durationMillis}';
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is StreamInitData &&
          timestamp == other.timestamp &&
          failed == other.failed &&
          durationMillis == other.durationMillis;

  @override
  int get hashCode =>
      timestamp.hashCode ^ failed.hashCode ^ durationMillis.hashCode;
}

final class DiagnosticStatsEvent {
  final DiagnosticId id;
  final DateTime creationDate;
  final DateTime dataSinceDate;
  final int droppedEvents;
  final int eventsInLastBatch;
  final List<StreamInitData> streamInits;

  DiagnosticStatsEvent(
      {required this.id,
      required this.creationDate,
      required this.dataSinceDate,
      required this.droppedEvents,
      required this.eventsInLastBatch,
      required List<StreamInitData> streamInits})
      : streamInits = List.unmodifiable(streamInits);

  @override
  String toString() {
    return 'DiagnosticStatsEvent{id: $id, creationDate: $creationDate,'
        ' dataSinceDate: $dataSinceDate, droppedEvents: $droppedEvents, '
        'eventsInLastBatch: $eventsInLastBatch, streamInits: $streamInits}';
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is DiagnosticStatsEvent &&
          id == other.id &&
          creationDate == other.creationDate &&
          dataSinceDate == other.dataSinceDate &&
          droppedEvents == other.droppedEvents &&
          eventsInLastBatch == other.eventsInLastBatch &&
          streamInits.equals(other.streamInits);

  @override
  int get hashCode =>
      id.hashCode ^
      creationDate.hashCode ^
      dataSinceDate.hashCode ^
      droppedEvents.hashCode ^
      eventsInLastBatch.hashCode ^
      streamInits.hashCode;

// Unsupported
// int deduplicatedUsers;
}
