import 'package:launchdarkly_dart_common/src/events/diagnostic_events.dart';
import 'package:launchdarkly_dart_common/src/events/diagnostics_manager.dart';
import 'package:test/test.dart';

DiagnosticsManager createManager() {
  return DiagnosticsManager(
      credential: 'the-sdk-key',
      sdkData: DiagnosticSdkData(
          name: 'sdk-name',
          version: 'sdk-version',
          wrapperName: 'the-wrapper',
          wrapperVersion: 'the-wrapper-version'),
      platformData: DiagnosticPlatformData(
          name: 'flutter',
          osArch: 'arm64',
          osName: 'the-os',
          osVersion: 'the-version',
          additionalInformation: {'test': 'true'}),
      configData: DiagnosticConfigData(
          customBaseUri: true,
          customStreamUri: true,
          eventsCapacity: 100,
          connectTimeoutMillis: 500,
          eventsFlushIntervalMillis: 600,
          pollingIntervalMillis: 300000,
          reconnectTimeoutMillis: 3000,
          streamingDisabled: true,
          offline: true,
          allAttributesPrivate: true,
          diagnosticRecordingIntervalMillis: 500,
          backgroundPollingDisabled: false,
          backgroundPollingIntervalMillis: 555,
          useReport: true,
          evaluationReasonsRequested: true));
}

void main() {
  test('it creates the init event', () {
    final manager = createManager();
    final event = manager.getInitEvent()!;

    final expectedEvent = DiagnosticInitEvent(
        id: DiagnosticId(
            diagnosticId: event.id.diagnosticId,
            sdkKeySuffix: event.id.sdkKeySuffix),
        creationDate: event.creationDate,
        sdk: DiagnosticSdkData(
            name: 'sdk-name',
            version: 'sdk-version',
            wrapperName: 'the-wrapper',
            wrapperVersion: 'the-wrapper-version'),
        configuration: DiagnosticConfigData(
            customBaseUri: true,
            customStreamUri: true,
            eventsCapacity: 100,
            connectTimeoutMillis: 500,
            eventsFlushIntervalMillis: 600,
            pollingIntervalMillis: 300000,
            reconnectTimeoutMillis: 3000,
            streamingDisabled: true,
            offline: true,
            allAttributesPrivate: true,
            diagnosticRecordingIntervalMillis: 500,
            backgroundPollingDisabled: false,
            backgroundPollingIntervalMillis: 555,
            useReport: true,
            evaluationReasonsRequested: true),
        platform: DiagnosticPlatformData(
            name: 'flutter',
            osArch: 'arm64',
            osName: 'the-os',
            osVersion: 'the-version',
            additionalInformation: {'test': 'true'}));

    expect(event, expectedEvent);
  });

  test('getting the init event the second time returns null', () {
    final manager = createManager();
    manager.getInitEvent();
    expect(manager.getInitEvent(), isNull);
  });

  test('it records stream inits', () {
    final manager = createManager();
    manager.recordStreamInit(
        DateTime.fromMillisecondsSinceEpoch(1000), true, Duration(seconds: 10));
    manager.recordStreamInit(DateTime.fromMillisecondsSinceEpoch(2000), false,
        Duration(seconds: 20));

    final event = manager.createStatsEventAndReset(10, 30);

    final expectedEvent = DiagnosticStatsEvent(
        id: DiagnosticId(
            diagnosticId: event.id.diagnosticId,
            sdkKeySuffix: event.id.sdkKeySuffix),
        creationDate: event.creationDate,
        dataSinceDate: event.dataSinceDate,
        droppedEvents: 10,
        eventsInLastBatch: 30,
        streamInits: [
          StreamInitData(
              timestamp: DateTime.fromMillisecondsSinceEpoch(1000),
              failed: true,
              durationMillis: 10000),
          StreamInitData(
              timestamp: DateTime.fromMillisecondsSinceEpoch(2000),
              failed: false,
              durationMillis: 20000),
        ]);

    expect(event, expectedEvent);
  });

  test('it resets the periodic data', () {
    final manager = createManager();
    manager.recordStreamInit(
        DateTime.fromMillisecondsSinceEpoch(1000), true, Duration(seconds: 10));
    manager.recordStreamInit(DateTime.fromMillisecondsSinceEpoch(2000), false,
        Duration(seconds: 20));

    manager.createStatsEventAndReset(10, 30);
    final eventB = manager.createStatsEventAndReset(40, 50);

    final expectedEvent = DiagnosticStatsEvent(
        id: DiagnosticId(
            diagnosticId: eventB.id.diagnosticId,
            sdkKeySuffix: eventB.id.sdkKeySuffix),
        creationDate: eventB.creationDate,
        dataSinceDate: eventB.dataSinceDate,
        droppedEvents: 40,
        eventsInLastBatch: 50,
        streamInits: [
        ]);

    expect(eventB, expectedEvent);
  });
}
