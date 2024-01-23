// ignore_for_file: close_sinks

import 'dart:async';
import 'dart:convert';

import 'package:http/testing.dart';
import 'package:launchdarkly_dart_common/launchdarkly_dart_common.dart';
import 'package:mocktail/mocktail.dart';
import 'package:test/test.dart';

import 'package:http/http.dart' as http;

import '../config/mock_endpoints.dart';
import '../logging_test.dart';

(DefaultEventProcessor, MockAdapter) createProcessor(MockClient innerClient) {
  final adapter = MockAdapter();
  final client = HttpClient(
      client: innerClient,
      httpProperties:
          HttpProperties(baseHeaders: {'test': 'header', 'a': 'b'}));

  return (
    DefaultEventProcessor(
        logger: LDLogger(adapter: adapter),
        eventCapacity: 100,
        flushInterval: Duration(milliseconds: 100),
        client: client,
        analyticsEventsPath: '/analytics',
        diagnosticEventsPath: '/diagnostics',
        endpoints: MockEndpoints(),
        allAttributesPrivate: false,
        globalPrivateAttributes: {},
        diagnosticRecordingInterval: Duration(milliseconds: 100)),
    adapter
  );
}

(DefaultEventProcessor, MockAdapter) createProcessorWithDiagnostics(
    MockClient innerClient) {
  final adapter = MockAdapter();
  final client = HttpClient(
      client: innerClient,
      httpProperties:
          HttpProperties(baseHeaders: {'test': 'header', 'a': 'b'}));

  return (
    DefaultEventProcessor(
        logger: LDLogger(adapter: adapter),
        eventCapacity: 100,
        flushInterval: Duration(milliseconds: 100),
        client: client,
        analyticsEventsPath: '/analytics',
        diagnosticEventsPath: '/diagnostics',
        endpoints: MockEndpoints(),
        allAttributesPrivate: false,
        globalPrivateAttributes: {},
        diagnosticsManager: DiagnosticsManager(
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
                useReport: true,
                evaluationReasonsRequested: true)),
        diagnosticRecordingInterval: Duration(milliseconds: 100)),
    adapter
  );
}

void main() {
  setUpAll(() {
    registerFallbackValue(LDLogRecord(
        level: LDLogLevel.debug,
        message: '',
        time: DateTime.now(),
        logTag: ''));
  });

  test('it can process a identify event', () async {
    final requests = <http.Request>[];
    final innerClient = MockClient((request) async {
      requests.add(request);
      return http.Response('', 200);
    });

    final (processor, _) = createProcessor(innerClient);

    final inputIdentifyEvent = IdentifyEvent(
        context: LDContextBuilder().kind('user', 'user-key').build());
    processor.processIdentifyEvent(inputIdentifyEvent);

    await processor.flush();
    expect(requests, hasLength(1));
    final decodedAsLdValue =
        LDValueSerialization.fromJson(jsonDecode(requests[0].body));
    expect(decodedAsLdValue.type, LDValueType.array);
    expect(decodedAsLdValue, hasLength(1));

    final ldValueIdentifyEvent = decodedAsLdValue.get(0);
    // Not validating each field, as the serialization tests handle that.
    expect(ldValueIdentifyEvent.getFor('kind').stringValue(), 'identify');
    expect(ldValueIdentifyEvent.getFor('creationDate').intValue(),
        inputIdentifyEvent.creationDate.millisecondsSinceEpoch);
  });

  test('it can process a custom event', () async {
    final requests = <http.Request>[];
    final innerClient = MockClient((request) async {
      requests.add(request);
      return http.Response('', 200);
    });

    final (processor, _) = createProcessor(innerClient);

    final inputCustomEvent = CustomEvent(
        key: 'my-key',
        context: LDContextBuilder().kind('user', 'user-key').build(),
        metricValue: 100,
        data: LDValue.ofString('my-data'));
    processor.processCustomEvent(inputCustomEvent);

    await processor.flush();
    expect(requests, hasLength(1));
    final decodedAsLdValue =
        LDValueSerialization.fromJson(jsonDecode(requests[0].body));
    expect(decodedAsLdValue.type, LDValueType.array);
    expect(decodedAsLdValue, hasLength(1));

    final ldValueCustomEvent = decodedAsLdValue.get(0);
    // Not validating each field, as the serialization tests handle that.
    expect(ldValueCustomEvent.getFor('kind').stringValue(), 'custom');
    expect(ldValueCustomEvent.getFor('creationDate').intValue(),
        inputCustomEvent.creationDate.millisecondsSinceEpoch);
  });

  test('it can process a tracked eval event', () async {
    final requests = <http.Request>[];
    final innerClient = MockClient((request) async {
      requests.add(request);
      return http.Response('', 200);
    });

    final (processor, _) = createProcessor(innerClient);

    final inputEvalEvent = EvalEvent(
        context: LDContextBuilder()
            .kind('user', 'user-key')
            .set('name', LDValue.ofString('Example Name'))
            .anonymous(true)
            .build(),
        flagKey: 'the-flag',
        defaultValue: LDValue.ofNum(10),
        evaluationDetail: LDEvaluationDetail(
            LDValue.ofNum(20), 1, LDEvaluationReason.fallthrough()),
        withReason: true,
        trackEvent: true);
    processor.processEvalEvent(inputEvalEvent);

    await processor.flush();
    expect(requests, hasLength(1));

    final decodedAsLdValue =
        LDValueSerialization.fromJson(jsonDecode(requests[0].body));
    expect(decodedAsLdValue.type, LDValueType.array);
    // Feature event and summary event
    expect(decodedAsLdValue, hasLength(2));

    final ldValueEvalEvent = decodedAsLdValue.get(0);
    // Not validating each field, as the serialization tests handle that.
    expect(ldValueEvalEvent.getFor('kind').stringValue(), 'feature');
    expect(ldValueEvalEvent.getFor('creationDate').intValue(),
        inputEvalEvent.creationDate.millisecondsSinceEpoch);
    expect(
        ldValueEvalEvent
            .getFor('context')
            .getFor('_meta')
            .getFor('redactedAttributes'),
        LDValue.buildArray().addString('/name').build());

    final ldValueSummaryEvent = decodedAsLdValue.get(1);
    // Not validating each field, as the serialization tests handle that.
    expect(ldValueSummaryEvent.getFor('kind').stringValue(), 'summary');
  });

  test('it can process an untracked eval event', () async {
    final requests = <http.Request>[];
    final innerClient = MockClient((request) async {
      requests.add(request);
      return http.Response('', 200);
    });

    final (processor, _) = createProcessor(innerClient);

    final inputEvalEvent = EvalEvent(
        context: LDContextBuilder().kind('user', 'user-key').build(),
        flagKey: 'the-flag',
        defaultValue: LDValue.ofNum(10),
        evaluationDetail: LDEvaluationDetail(
            LDValue.ofNum(20), 1, LDEvaluationReason.fallthrough()),
        withReason: true,
        trackEvent: false);
    processor.processEvalEvent(inputEvalEvent);

    await processor.flush();
    expect(requests, hasLength(1));

    final decodedAsLdValue =
        LDValueSerialization.fromJson(jsonDecode(requests[0].body));
    expect(decodedAsLdValue.type, LDValueType.array);
    // Only summary event
    expect(decodedAsLdValue, hasLength(1));

    final ldValueSummaryEvent = decodedAsLdValue.get(0);
    // Not validating each field, as the serialization tests handle that.
    expect(ldValueSummaryEvent.getFor('kind').stringValue(), 'summary');
  });

  test('it can produce a debug event', () async {
    final requests = <http.Request>[];
    final innerClient = MockClient((request) async {
      requests.add(request);
      return http.Response('', 200);
    });

    final (processor, _) = createProcessor(innerClient);

    final inputEvalEvent = EvalEvent(
        context: LDContextBuilder().kind('user', 'user-key').build(),
        flagKey: 'the-flag',
        defaultValue: LDValue.ofNum(10),
        evaluationDetail: LDEvaluationDetail(
            LDValue.ofNum(20), 1, LDEvaluationReason.fallthrough()),
        withReason: true,
        trackEvent: false,
        debugEventsUntilDate: DateTime(DateTime.now().year + 1));
    processor.processEvalEvent(inputEvalEvent);

    await processor.flush();
    expect(requests, hasLength(1));

    final decodedAsLdValue =
        LDValueSerialization.fromJson(jsonDecode(requests[0].body));
    expect(decodedAsLdValue.type, LDValueType.array);
    // Debug and summary
    expect(decodedAsLdValue, hasLength(2));

    final ldValueDebugEvent = decodedAsLdValue.get(0);
    // Not validating each field, as the serialization tests handle that.
    expect(ldValueDebugEvent.getFor('kind').stringValue(), 'debug');
    expect(ldValueDebugEvent.getFor('creationDate').intValue(),
        inputEvalEvent.creationDate.millisecondsSinceEpoch);

    final ldValueSummaryEvent = decodedAsLdValue.get(1);
    // Not validating each field, as the serialization tests handle that.
    expect(ldValueSummaryEvent.getFor('kind').stringValue(), 'summary');
  });

  test('it produces a diagnostic init event', () async {
    final requestController = StreamController<http.Request>();
    final stream = requestController.stream.asBroadcastStream();

    final innerClient = MockClient((request) async {
      requestController.sink.add(request);
      return http.Response('', 200);
    });

    stream.listen((request) {
      final decodedAsLdValue =
          LDValueSerialization.fromJson(jsonDecode(request.body));
      expect(decodedAsLdValue.getFor('kind').stringValue(), 'diagnostic-init');
    });

    expectLater(stream, emits(anything));

    final (processor, _) = createProcessorWithDiagnostics(innerClient);
    processor.start();
    processor.stop();
  });

  test('multiple starts do not produce multiple diagnostic init events.',
      () async {
    final requestController = StreamController<http.Request>();
    final stream = requestController.stream.asBroadcastStream();

    final innerClient = MockClient((request) async {
      requestController.sink.add(request);
      return http.Response('', 200);
    });

    final (processor, _) = createProcessorWithDiagnostics(innerClient);
    processor.start();
    final initRequest = await stream.first;

    final initDecodedAsJson =
        LDValueSerialization.fromJson(jsonDecode(initRequest.body));
    expect(initDecodedAsJson.getFor('kind').stringValue(), 'diagnostic-init');

    processor.stop();
    processor.start();

    // No init event will be generated, so the next event will be a stats event.
    final statsEventRequest = await stream.first;

    final statsDecodedAsJson =
        LDValueSerialization.fromJson(jsonDecode(statsEventRequest.body));
    expect(statsDecodedAsJson.getFor('kind').stringValue(), 'diagnostic');
  });

  test('it produces diagnostic stats events', () async {
    final requestController = StreamController<http.Request>();
    final stream = requestController.stream.asBroadcastStream();

    final innerClient = MockClient((request) async {
      requestController.sink.add(request);
      return http.Response('', 200);
    });

    final (processor, _) = createProcessorWithDiagnostics(innerClient);

    stream.skip(1).listen((request) {
      final decodedAsLdValue =
          LDValueSerialization.fromJson(jsonDecode(request.body));

      expect(decodedAsLdValue.getFor('kind').stringValue(), 'diagnostic');
      processor.stop();
    });

    expectLater(stream, emitsInAnyOrder([anything, anything]));

    processor.start();
  });

  test('it retries once for recoverable situations', () async {
    final requests = <http.Request>[];
    var first = true;
    final innerClient = MockClient((request) async {
      requests.add(request);
      if (first) {
        first = false;
        return http.Response('', 503);
      } else {
        return http.Response('', 200);
      }
    });

    final (processor, adapter) = createProcessor(innerClient);

    final inputIdentifyEvent = IdentifyEvent(
        context: LDContextBuilder().kind('user', 'user-key').build());
    processor.processIdentifyEvent(inputIdentifyEvent);

    await processor.flush();
    expect(requests, hasLength(2));

    expect(requests[0].body, requests[1].body);
    verifyNever(() => adapter.log(any()));
  });

  test('it reports if the events cannot be delivered because a failed status',
      () async {
    final innerClient = MockClient((request) async {
      return http.Response('', 503);
    });

    final (processor, adapter) = createProcessor(innerClient);

    final inputIdentifyEvent = IdentifyEvent(
        context: LDContextBuilder().kind('user', 'user-key').build());
    processor.processIdentifyEvent(inputIdentifyEvent);

    await processor.flush();

    final warningMessage =
        (verify(() => adapter.log(captureAny())).captured[0] as LDLogRecord);
    expect(warningMessage.level, LDLogLevel.warn);
    expect(warningMessage.message,
        'Received an unexpected response 503 delivering events and some events were dropped.');
  });

  test('it reports if the events cannot be delivered because of an exception',
      () async {
    final innerClient = MockClient((request) async {
      throw Exception('bad things');
    });

    final (processor, adapter) = createProcessor(innerClient);

    final inputIdentifyEvent = IdentifyEvent(
        context: LDContextBuilder().kind('user', 'user-key').build());
    processor.processIdentifyEvent(inputIdentifyEvent);

    await processor.flush();

    final warningMessage =
        (verify(() => adapter.log(captureAny())).captured[0] as LDLogRecord);
    expect(warningMessage.level, LDLogLevel.warn);
    expect(warningMessage.message,
        'Received an unexpected error: {Exception: bad things} delivering events and some events were dropped.');
  });

  test('it shuts down if it receives an unrecoverable error', () async {
    final requests = <http.Request>[];
    final innerClient = MockClient((request) async {
      requests.add(request);
      return http.Response('', 404);
    });

    final (processor, adapter) = createProcessor(innerClient);

    final inputIdentifyEvent = IdentifyEvent(
        context: LDContextBuilder().kind('user', 'user-key').build());
    processor.processIdentifyEvent(inputIdentifyEvent);

    await processor.flush();
    expect(requests, hasLength(1));

    final warningMessage =
        (verify(() => adapter.log(captureAny())).captured[0] as LDLogRecord);
    expect(warningMessage.level, LDLogLevel.error);
    expect(warningMessage.message,
        'Encountered unrecoverable status while sending events 404.');
    expect(processor.shutdown, isTrue);
  });

  test(
      'it reports when capacity is exceeded and it does so only once per batch',
      () async {
    final requestController = StreamController<http.Request>();
    final stream = requestController.stream.asBroadcastStream();

    final innerClient = MockClient((request) async {
      if (requestController.hasListener) {
        requestController.sink.add(request);
      }
      return http.Response('', 200);
    });

    final (processor, adapter) = createProcessorWithDiagnostics(innerClient);
    for (var eventIndex = 0; eventIndex < 150; eventIndex++) {
      final customEvent = CustomEvent(
          key: 'my-key',
          context: LDContextBuilder().kind('user', 'user-key').build(),
          metricValue: eventIndex);
      processor.processCustomEvent(customEvent);
    }

    final warningMessage =
        (verify(() => adapter.log(captureAny())).captured[0] as LDLogRecord);
    expect(warningMessage.level, LDLogLevel.warn);
    expect(warningMessage.message,
        'Event queue at capacity. Increase capacity to avoid dropping events.');
    processor.start();
    await processor.flush();
    // After this should only be the periodic stats.

    stream.listen((request) {
      final decodedAsLdValue =
          LDValueSerialization.fromJson(jsonDecode(request.body));

      expect(decodedAsLdValue.getFor('kind').stringValue(), 'diagnostic');
      expect(decodedAsLdValue.getFor('eventsInLastBatch').intValue(), 100);
      expect(decodedAsLdValue.getFor('droppedEvents').intValue(), 50);
      processor.stop();
    });

    expectLater(stream, emits(anything));
  });
}
