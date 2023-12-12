import 'dart:convert';

import 'package:launchdarkly_dart_common/ld_common.dart';
import 'package:launchdarkly_dart_common/src/events/diagnostic_events.dart';
import 'package:launchdarkly_dart_common/src/serialization/diagnostic_event_serialization.dart';
import 'package:test/test.dart';

void main() {
  test('can serialize diagnostic init event', () {
    final event = DiagnosticInitEvent(
        id: DiagnosticId(diagnosticId: 'the-sdk', sdkKeySuffix: 'suffix'),
        creationDate: DateTime.fromMillisecondsSinceEpoch(1000),
        sdk: DiagnosticSdkData(name: 'sdk-name', version: 'sdk-version'),
        configuration: DiagnosticConfigData(
            customBaseUri: false,
            customStreamUri: false,
            eventsCapacity: 100,
            connectTimeoutMillis: 500,
            eventsFlushIntervalMillis: 600,
            pollingIntervalMillis: 300000,
            reconnectTimeoutMillis: 3000,
            streamingDisabled: false,
            offline: false,
            allAttributesPrivate: false,
            diagnosticRecordingIntervalMillis: 500),
        platform: DiagnosticPlatformData());

    final serializedEvent =
        jsonEncode(DiagnosticInitEventSerialization.toJson(event));

    final expectedSerializedEvent =
        '{"id":{"diagnosticId":"the-sdk","sdkKeySuffix":"suffix"},'
        '"creationDate":1000,'
        '"sdk":{"name":"sdk-name","version":"sdk-version"},'
        '"configuration":'
        '{"customBaseUri":false,'
        '"customStreamUri":false,'
        '"eventsCapacity":100,'
        '"connectTimeoutMillis":500,'
        '"eventsFlushIntervalMillis":600,'
        '"pollingIntervalMillis":300000,'
        '"reconnectTimeoutMillis":3000,'
        '"streamingDisabled":false,'
        '"offline":false,'
        '"allAttributesPrivate":false,'
        '"diagnosticRecordingIntervalMillis":500'
        '},'
        '"platform":{}}';
    expect(LDValueSerialization.fromJson(jsonDecode(serializedEvent)),
        LDValueSerialization.fromJson(jsonDecode(expectedSerializedEvent)));
  });

  test('can serialize diagnostic init event with all optional elements', () {
    final event = DiagnosticInitEvent(
        id: DiagnosticId(diagnosticId: 'the-sdk', sdkKeySuffix: 'suffix'),
        creationDate: DateTime.fromMillisecondsSinceEpoch(1000),
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

    final serializedEvent =
        jsonEncode(DiagnosticInitEventSerialization.toJson(event));

    final expectedSerializedEvent =
        '{"id":{"diagnosticId":"the-sdk","sdkKeySuffix":"suffix"},'
        '"creationDate":1000,'
        '"sdk":{"name":"sdk-name","version":"sdk-version", '
        '"wrapperName":"the-wrapper", "wrapperVersion":"the-wrapper-version"},'
        '"configuration":'
        '{"customBaseUri":true,'
        '"customStreamUri":true,'
        '"eventsCapacity":100,'
        '"connectTimeoutMillis":500,'
        '"eventsFlushIntervalMillis":600,'
        '"pollingIntervalMillis":300000,'
        '"reconnectTimeoutMillis":3000,'
        '"streamingDisabled":true,'
        '"offline":true,'
        '"allAttributesPrivate":true,'
        '"diagnosticRecordingIntervalMillis":500,'
        '"backgroundPollingIntervalMillis":555,'
        '"useReport":true,'
        '"backgroundPollingDisabled":false,'
        '"evaluationReasonsRequested": true'
        '},'
        '"platform":{'
        '"name":"flutter",'
        '"osArch":"arm64",'
        '"osName":"the-os",'
        '"osVersion":"the-version",'
        '"test":"true"'
        '}}';
    expect(LDValueSerialization.fromJson(jsonDecode(serializedEvent)),
        LDValueSerialization.fromJson(jsonDecode(expectedSerializedEvent)));
  });

  test('can serialize diagnostic stats event', () {
    final event = DiagnosticStatsEvent(
        id: DiagnosticId(diagnosticId: 'the-sdk', sdkKeySuffix: 'suffix'),
        creationDate: DateTime.fromMillisecondsSinceEpoch(1000),
        dataSinceDate: DateTime.fromMillisecondsSinceEpoch(2000),
        droppedEvents: 5,
        eventsInLastBatch: 10,
        streamInits: [
          StreamInitData(
              timestamp: DateTime.fromMillisecondsSinceEpoch(3000),
              failed: true,
              durationMillis: 4000)
        ]);

    final serializedEvent =
        jsonEncode(DiagnosticStatsEventSerialization.toJson(event));

    final expectedSerializedEvent =
        '{"id":{"diagnosticId":"the-sdk","sdkKeySuffix":"suffix"},'
        '"creationDate":1000,'
        '"dataSinceDate":2000,'
        '"droppedEvents":5,'
        '"eventsInLastBatch":10,'
        '"streamInits": [{"timestamp": 3000, "failed":true, "durationMillis":4000}]'
        '}';
    expect(LDValueSerialization.fromJson(jsonDecode(serializedEvent)),
        LDValueSerialization.fromJson(jsonDecode(expectedSerializedEvent)));
  });
}
