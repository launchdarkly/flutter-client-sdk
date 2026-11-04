// ignore_for_file: close_sinks

import 'dart:async';
import 'dart:collection';

import 'package:http/testing.dart';
import 'package:launchdarkly_common_client/launchdarkly_common_client.dart';
import 'package:launchdarkly_common_client/src/config/data_source_config.dart';
import 'package:launchdarkly_common_client/src/data_sources/data_source.dart';
import 'package:launchdarkly_common_client/src/data_sources/data_source_event_handler.dart';
import 'package:launchdarkly_common_client/src/data_sources/data_source_status.dart';
import 'package:launchdarkly_common_client/src/data_sources/data_source_status_manager.dart';
import 'package:launchdarkly_common_client/src/data_sources/streaming_data_source.dart';
import 'package:launchdarkly_common_client/src/flag_manager/flag_manager.dart';
import 'package:launchdarkly_dart_common/launchdarkly_dart_common.dart'
    as ld_common;
import 'package:http/http.dart' as http;
import 'package:mocktail/mocktail.dart';
import 'package:test/test.dart';

class MockLogAdapter extends Mock implements LDLogAdapter {}

class MockSseClient implements SSEClient {
  final Stream<Event> mockStream;
  final bool supportsCustomMethod;
  bool closed = false;

  MockSseClient(this.mockStream, {this.supportsCustomMethod = true});

  @override
  Future close() async {
    closed = true;
  }

  @override
  void restart() {}

  @override
  Stream<Event> get stream => mockStream;

  @override
  bool hasCapability(SSECapability capability) =>
      capability != SSECapability.customMethod || supportsCustomMethod;
}

(
  StreamingDataSource,
  FlagManager,
  DataSourceStatusManager
) makeDataSourceForTest(Stream<Event> mockStream,
    {LDContext? inContext,
    HttpProperties? inProperties,
    bool useReport = false,
    bool withReasons = false,
    Duration? testingInterval,
    MockClient? mockHttpClient,
    bool supportsCustomMethod = true,
    // Receives every client the factory creates.
    List<MockSseClient>? createdClients,
    LDLogger? inLogger,
    Function(Uri, HttpProperties, String?, SseHttpMethod?)? factoryCallback}) {
  final context = inContext ?? LDContextBuilder().kind('user', 'test').build();
  // We are not testing the data source status manager here, so we just want a
  // fixed time to make events easy to get.
  final statusManager = DataSourceStatusManager(stamper: () => DateTime(1));

  final logger = inLogger ?? LDLogger();
  final properties = inProperties ?? HttpProperties();

  const sdkKey = 'dummy-key';
  final flagManager =
      FlagManager(sdkKey: sdkKey, logger: logger, maxCachedContexts: 5);
  final eventHandler = DataSourceEventHandler(
      logger: logger, flagManager: flagManager, statusManager: statusManager);

  final streaming = StreamingDataSource(
      credential: sdkKey,
      context: context,
      endpoints: ServiceEndpoints(),
      logger: logger,
      dataSourceConfig: StreamingDataSourceConfig(
          withReasons: withReasons, useReport: useReport),
      pollingDataSourceConfig: PollingDataSourceConfig(
          useReport: useReport, withReasons: withReasons),
      httpProperties: properties,
      httpClientFactory: mockHttpClient != null
          ? (httpProps) => ld_common.HttpClient(
              client: mockHttpClient, httpProperties: httpProps)
          : null,
      clientFactory: (request) {
        factoryCallback?.call(
            request.uriProvider(), properties, request.body, request.method);
        final client = MockSseClient(mockStream,
            supportsCustomMethod: supportsCustomMethod);
        createdClients?.add(client);
        return client;
      });

  streaming.events.asyncMap((event) async {
    switch (event) {
      case DataEvent():
        return eventHandler.handleMessage(context, event.type, event.data,
            environmentId: event.environmentId);
      case StatusEvent():
        if (event.statusCode != null) {
          statusManager.setErrorResponse(event.statusCode!, event.message,
              shutdown: event.shutdown);
        } else {
          statusManager.setErrorByKind(event.kind, event.message,
              shutdown: event.shutdown);
        }
      case PayloadEvent():
      case InitializedEvent():
        break;
    }
  }).listen((_) {});

  return (streaming, flagManager, statusManager);
}

void main() {
  setUpAll(() {
    registerFallbackValue(LDLogRecord(
        level: LDLogLevel.debug,
        message: '',
        time: DateTime.now(),
        logTag: ''));
  });

  group('parameters are correctly calculated for the stream subscription', () {
    test('it uses the correct URL without reasons', () {
      final controller = StreamController<MessageEvent>();
      final (dataSource, _, statusManager) = makeDataSourceForTest(
          controller.stream, factoryCallback: (uri, properties, body, method) {
        expect(uri.toString(),
            'https://clientstream.launchdarkly.com/meval/eyJrZXkiOiJ0ZXN0Iiwia2luZCI6InVzZXIifQ==');
      });

      expectLater(
          statusManager.changes,
          emits(DataSourceStatus(
              state: DataSourceState.valid, stateSince: DateTime(1))));

      dataSource.start();
      controller.sink.add(MessageEvent('put', '{}', null));
    });

    test('is includes no body when not using REPORT', () {
      final controller = StreamController<MessageEvent>();
      final (dataSource, _, statusManager) = makeDataSourceForTest(
          controller.stream, factoryCallback: (uri, properties, body, method) {
        expect(method, SseHttpMethod.get);
        expect(body, isNull);
      });

      expectLater(
          statusManager.changes,
          emits(DataSourceStatus(
              state: DataSourceState.valid, stateSince: DateTime(1))));

      dataSource.start();
      controller.sink.add(MessageEvent('put', '{}', null));
    });

    test('is includes a body when using REPORT', () {
      final controller = StreamController<MessageEvent>();
      final (dataSource, _, statusManager) = makeDataSourceForTest(
          controller.stream, factoryCallback: (uri, properties, body, method) {
        expect(body, '{"key":"test","kind":"user"}');
        expect(method, SseHttpMethod.report);
      }, useReport: true);

      expectLater(
          statusManager.changes,
          emits(DataSourceStatus(
              state: DataSourceState.valid, stateSince: DateTime(1))));

      dataSource.start();
      controller.sink.add(MessageEvent('put', '{}', null));
    });

    test('it falls back to GET when the client cannot send REPORT', () {
      final calls = <(Uri, String?, SseHttpMethod?)>[];
      final clients = <MockSseClient>[];
      final controller = StreamController<MessageEvent>();
      final (dataSource, _, _) = makeDataSourceForTest(controller.stream,
          factoryCallback: (uri, properties, body, method) =>
              calls.add((uri, body, method)),
          createdClients: clients,
          useReport: true,
          supportsCustomMethod: false);

      dataSource.start();

      expect(calls, hasLength(2));
      expect(calls.first.$3, SseHttpMethod.report);
      expect(calls.last.$3, SseHttpMethod.get);
      expect(calls.last.$2, isNull);
      expect(calls.last.$1.toString(),
          'https://clientstream.launchdarkly.com/meval/eyJrZXkiOiJ0ZXN0Iiwia2luZCI6InVzZXIifQ==');
      expect(clients.first.closed, isTrue,
          reason: 'the REPORT client is closed');
      expect(clients.last.closed, isFalse, reason: 'the GET client is in use');
    });

    test('it logs a warning when it falls back to GET', () {
      final adapter = MockLogAdapter();
      final controller = StreamController<MessageEvent>();
      final (dataSource, _, _) = makeDataSourceForTest(controller.stream,
          inLogger: LDLogger(adapter: adapter),
          useReport: true,
          supportsCustomMethod: false);

      dataSource.start();

      final records = verify(() => adapter.log(captureAny()))
          .captured
          .cast<LDLogRecord>()
          .where((record) => record.level == LDLogLevel.warn);
      expect(records.map((record) => record.message), [
        'The SSE client cannot send REPORT requests. Streaming with GET instead.'
      ]);
    });

    test('it keeps REPORT when the client can send it', () {
      final calls = <SseHttpMethod?>[];
      final controller = StreamController<MessageEvent>();
      final (dataSource, _, _) = makeDataSourceForTest(controller.stream,
          factoryCallback: (uri, properties, body, method) => calls.add(method),
          useReport: true);

      dataSource.start();

      expect(calls, [SseHttpMethod.report]);
    });

    test('a ping poll keeps the configured REPORT method after the fallback',
        () async {
      // The polling request method follows the polling configuration. The
      // stream fallback does not change it. A GET on the REPORT polling path
      // would carry no context.
      final pollRequests = <http.Request>[];
      final innerHttpClient = MockClient((request) async {
        pollRequests.add(request);
        return http.Response('{}', 200);
      });
      final controller = StreamController<MessageEvent>();
      final (dataSource, _, _) = makeDataSourceForTest(controller.stream,
          mockHttpClient: innerHttpClient,
          useReport: true,
          supportsCustomMethod: false);

      dataSource.start();
      controller.sink.add(MessageEvent('ping', '', null));
      await Future.delayed(Duration(milliseconds: 50));

      expect(pollRequests, hasLength(1));
      expect(pollRequests.single.method, 'REPORT');
      expect(pollRequests.single.url.path, '/msdk/evalx/context');
      expect(pollRequests.single.body, '{"key":"test","kind":"user"}');
    });

    test('it closes the client when it stops', () {
      final clients = <MockSseClient>[];
      final controller = StreamController<MessageEvent>();
      final (dataSource, _, _) =
          makeDataSourceForTest(controller.stream, createdClients: clients);

      dataSource.start();
      dataSource.stop();

      expect(clients.single.closed, isTrue);
    });

    test('it shuts down when the client factory throws', () async {
      final adapter = MockLogAdapter();
      final dataSource = StreamingDataSource(
          credential: 'dummy-key',
          context: LDContextBuilder().kind('user', 'test').build(),
          endpoints: ServiceEndpoints(),
          logger: LDLogger(adapter: adapter),
          dataSourceConfig: StreamingDataSourceConfig(),
          pollingDataSourceConfig: PollingDataSourceConfig(),
          httpProperties: HttpProperties(),
          clientFactory: (request) => throw StateError('no client'));
      final events = <DataSourceEvent>[];
      dataSource.events.listen(events.add);

      dataSource.start();
      await Future.delayed(Duration.zero);

      expect(events, hasLength(1));
      expect(events.single, isA<StatusEvent>());
      expect((events.single as StatusEvent).kind, ErrorKind.unknown);
      final errors = verify(() => adapter.log(captureAny()))
          .captured
          .cast<LDLogRecord>()
          .where((record) => record.level == LDLogLevel.error);
      expect(errors.map((record) => record.message), [
        'The SSE client factory failed: "Bad state: no client", Shutting down.'
      ]);
    });

    test('it uses the correct URL without reasons with REPORT', () {
      final controller = StreamController<MessageEvent>();
      final (dataSource, _, statusManager) = makeDataSourceForTest(
          controller.stream, factoryCallback: (uri, properties, body, method) {
        expect(uri.toString(), 'https://clientstream.launchdarkly.com/meval');
      }, useReport: true);

      expectLater(
          statusManager.changes,
          emits(DataSourceStatus(
              state: DataSourceState.valid, stateSince: DateTime(1))));

      dataSource.start();
      controller.sink.add(MessageEvent('put', '{}', null));
    });

    test('it uses the correct URL with reasons', () {
      final controller = StreamController<MessageEvent>();
      final (dataSource, _, statusManager) =
          makeDataSourceForTest(controller.stream, withReasons: true,
              factoryCallback: (uri, properties, body, method) {
        expect(uri.toString(),
            'https://clientstream.launchdarkly.com/meval/eyJrZXkiOiJ0ZXN0Iiwia2luZCI6InVzZXIifQ==?withReasons=true');
      });

      expectLater(
          statusManager.changes,
          emits(DataSourceStatus(
              state: DataSourceState.valid, stateSince: DateTime(1))));

      dataSource.start();
      controller.sink.add(MessageEvent('put', '{}', null));
    });

    test('it uses the correct URL with reasons and REPORT', () {
      final controller = StreamController<MessageEvent>();
      final (dataSource, _, statusManager) =
          makeDataSourceForTest(controller.stream, withReasons: true,
              factoryCallback: (uri, properties, body, method) {
        expect(uri.toString(),
            'https://clientstream.launchdarkly.com/meval?withReasons=true');
      }, useReport: true);

      expectLater(
          statusManager.changes,
          emits(DataSourceStatus(
              state: DataSourceState.valid, stateSince: DateTime(1))));

      dataSource.start();
      controller.sink.add(MessageEvent('put', '{}', null));
    });
  });

  test('it cancels the subscription on stop', () {
    bool cancelled = false;
    final controller =
        StreamController<MessageEvent>(onCancel: () => cancelled = true);
    final (dataSource, _, _) = makeDataSourceForTest(controller.stream,
        withReasons: true, factoryCallback: (uri, properties, body, method) {});

    dataSource.start();
    dataSource.stop();
    expect(cancelled, true);
  });

  test('it forwards messages to the data source event handler', () async {
    final controller = StreamController<MessageEvent>();
    final (dataSource, flagManager, _) =
        makeDataSourceForTest(controller.stream);

    dataSource.start();
    controller.sink.add(MessageEvent(
        'put',
        '{"my-boolean-flag":{"version":11,"flagVersion":5,"value":false,"variation":1,'
            '"trackEvents":false},'
            '"killswitch":{"version":10,"flagVersion":4,"value":true,'
            '"variation":0,"trackEvents":false}'
            '}',
        null));

    final firstChange = await flagManager.changes.first;
    expect(firstChange.keys, ['my-boolean-flag', 'killswitch']);
    expect(
        flagManager.get('my-boolean-flag')!.flag!.detail.value.booleanValue(),
        false);
    expect(
        flagManager.get('killswitch')!.flag!.detail.value.booleanValue(), true);

    controller.sink.add(MessageEvent(
        'patch',
        '{"key": "my-boolean-flag", "version": 681, "flagVersion": 53,'
            ' "value": true, "variation": 1, "trackEvents": false}',
        null));

    final secondChange = await flagManager.changes.first;

    expect(secondChange.keys, ['my-boolean-flag']);
    expect(
        flagManager.get('my-boolean-flag')!.flag!.detail.value.booleanValue(),
        true);

    controller.sink.add(MessageEvent(
        'delete', '{"key":"my-boolean-flag","version":682}', null));

    final thirdChange = await flagManager.changes.first;

    expect(thirdChange.keys, ['my-boolean-flag']);
    expect(flagManager.get('my-boolean-flag')!.flag, isNull);
  });

  group('ping event handling', () {
    test('it makes a polling request when receiving a ping event', () async {
      var pollingRequestMade = false;
      final innerHttpClient = MockClient((request) async {
        pollingRequestMade = true;
        return http.Response('{}', 200);
      });

      final controller = StreamController<MessageEvent>();
      final (dataSource, _, statusManager) = makeDataSourceForTest(
          controller.stream,
          mockHttpClient: innerHttpClient);

      // Wait for initial put event to establish valid state
      expectLater(
          statusManager.changes,
          emits(DataSourceStatus(
              state: DataSourceState.valid, stateSince: DateTime(1))));

      dataSource.start();
      controller.sink.add(MessageEvent('put', '{}', null));

      // Wait for the initial state to be established
      await Future.delayed(Duration(milliseconds: 50));

      // Now send a ping event
      controller.sink.add(MessageEvent('ping', '', null));

      // Wait for the polling request to be made
      await Future.delayed(Duration(milliseconds: 50));

      expect(pollingRequestMade, isTrue);
    });

    test('it updates flags when ping triggers successful polling response',
        () async {
      final innerHttpClient = MockClient((request) async {
        return http.Response(
            '{"updated-flag":{"version":20,"flagVersion":10,"value":true,"variation":0,"trackEvents":false}}',
            200);
      });

      final controller = StreamController<MessageEvent>();
      final (dataSource, flagManager, statusManager) = makeDataSourceForTest(
          controller.stream,
          mockHttpClient: innerHttpClient);

      expectLater(
          statusManager.changes,
          emits(DataSourceStatus(
              state: DataSourceState.valid, stateSince: DateTime(1))));

      dataSource.start();
      controller.sink.add(MessageEvent(
          'put',
          '{"my-boolean-flag":{"version":11,"flagVersion":5,"value":false,"variation":1,"trackEvents":false}}',
          null));

      // Wait for initial flags to be processed and consume that change event
      final firstChange = await flagManager.changes.first;
      expect(firstChange.keys, ['my-boolean-flag']);

      // Send a ping event
      controller.sink.add(MessageEvent('ping', '', null));

      // Wait for the polling request and flag update from the ping
      final secondChange = await flagManager.changes.first;

      expect(secondChange.keys.toSet(), {'updated-flag', 'my-boolean-flag'});
      expect(flagManager.get('updated-flag')!.flag!.detail.value.booleanValue(),
          true);
    });

    test('it does not update when ping triggers 304 response', () async {
      var requestCount = 0;
      final innerHttpClient = MockClient((request) async {
        requestCount++;
        if (requestCount == 1) {
          // First request returns data with etag
          return http.Response('{"flag1":{"version":1,"value":true}}', 200,
              headers: {'etag': 'abc123'});
        } else {
          // Second request (from ping) returns 304
          return http.Response('', 304, headers: {'etag': 'abc123'});
        }
      });

      final controller = StreamController<MessageEvent>();
      final (dataSource, flagManager, _) = makeDataSourceForTest(
          controller.stream,
          mockHttpClient: innerHttpClient);

      dataSource.start();
      controller.sink.add(MessageEvent('ping', '', null));

      // Wait for first change from the initial payload.
      await flagManager.changes.first;

      var changeCount = 0;
      flagManager.changes.listen((_) => changeCount++);

      // Send a ping event which will trigger a 304 response
      controller.sink.add(MessageEvent('ping', '', null));

      // Wait to ensure no additional changes
      await Future.delayed(Duration(milliseconds: 100));

      // Should have no additional changes since 304 means no update
      expect(changeCount, 0);
    });

    test('it reports error when ping triggers error response from polling',
        () async {
      final innerHttpClient = MockClient((request) async {
        return http.Response('{}', 503);
      });

      final controller = StreamController<MessageEvent>();
      final (dataSource, _, statusManager) = makeDataSourceForTest(
          controller.stream,
          mockHttpClient: innerHttpClient);

      // First expect valid state from the put event
      expectLater(
          statusManager.changes,
          emitsInOrder([
            DataSourceStatus(
                state: DataSourceState.valid, stateSince: DateTime(1)),
            DataSourceStatus(
                state: DataSourceState.interrupted,
                stateSince: DateTime(1),
                lastError: DataSourceStatusErrorInfo(
                    kind: ErrorKind.errorResponse,
                    message: 'Received unexpected status code: 503',
                    time: DateTime(1),
                    statusCode: 503))
          ]));

      dataSource.start();
      controller.sink.add(MessageEvent('put', '{}', null));

      // Wait for initial state
      await Future.delayed(Duration(milliseconds: 50));

      // Send a ping event which will trigger an error response
      controller.sink.add(MessageEvent('ping', '', null));

      // Wait for error to be processed
      await Future.delayed(Duration(milliseconds: 50));
    });

    test('it handles network error during polling request from ping', () async {
      final innerHttpClient = MockClient((request) async {
        throw Exception('Network error');
      });

      final controller = StreamController<MessageEvent>();
      final (dataSource, _, statusManager) = makeDataSourceForTest(
          controller.stream,
          mockHttpClient: innerHttpClient);

      // First expect valid state from the put event
      expectLater(
          statusManager.changes,
          emitsInOrder([
            DataSourceStatus(
                state: DataSourceState.valid, stateSince: DateTime(1)),
            predicate<DataSourceStatus>((status) =>
                status.state == DataSourceState.interrupted &&
                status.lastError?.kind == ErrorKind.networkError)
          ]));

      dataSource.start();
      controller.sink.add(MessageEvent('put', '{}', null));

      // Wait for initial state
      await Future.delayed(Duration(milliseconds: 50));

      // Send a ping event which will trigger a network error
      controller.sink.add(MessageEvent('ping', '', null));

      // Wait for error to be processed
      await Future.delayed(Duration(milliseconds: 100));
    });

    test('it uses GET method for ping polling when useReport is false',
        () async {
      String? actualMethod;
      final innerHttpClient = MockClient((request) async {
        actualMethod = request.method;
        return http.Response('{}', 200);
      });

      final controller = StreamController<MessageEvent>();
      final (dataSource, _, _) = makeDataSourceForTest(controller.stream,
          mockHttpClient: innerHttpClient, useReport: false);

      dataSource.start();
      controller.sink.add(MessageEvent('put', '{}', null));

      await Future.delayed(Duration(milliseconds: 50));

      // Send a ping event
      controller.sink.add(MessageEvent('ping', '', null));

      await Future.delayed(Duration(milliseconds: 50));

      expect(actualMethod, 'GET');
    });

    test('it uses REPORT method for ping polling when useReport is true',
        () async {
      String? actualMethod;
      final innerHttpClient = MockClient((request) async {
        actualMethod = request.method;
        return http.Response('{}', 200);
      });

      final controller = StreamController<MessageEvent>();
      final (dataSource, _, _) = makeDataSourceForTest(controller.stream,
          mockHttpClient: innerHttpClient, useReport: true);

      dataSource.start();
      controller.sink.add(MessageEvent('put', '{}', null));

      await Future.delayed(Duration(milliseconds: 50));

      // Send a ping event
      controller.sink.add(MessageEvent('ping', '', null));

      await Future.delayed(Duration(milliseconds: 50));

      expect(actualMethod, 'REPORT');
    });
  });

  group('stream error handling', () {
    test(
        'it emits a status event without throwing when the stream reports an '
        'unrecoverable error', () async {
      final controller = StreamController<Event>();
      final (dataSource, _, statusManager) =
          makeDataSourceForTest(controller.stream);

      final statusChange = expectLater(
          statusManager.changes,
          emits(predicate<DataSourceStatus>((status) =>
              status.lastError?.kind == ErrorKind.unknown &&
              status.lastError?.message ==
                  'Encountered unrecoverable error streaming')));

      dataSource.start();
      controller.sink.addError(Exception('Unable to make request'));

      await statusChange;
    });
  });

  group('environment ID from the stream connection', () {
    test('it uses the environment ID response header', () async {
      final controller = StreamController<Event>();
      final (dataSource, flagManager, _) =
          makeDataSourceForTest(controller.stream);
      dataSource.start();

      controller.sink.add(OpenEvent(
          headers: UnmodifiableMapView({'x-ld-envid': 'env-from-header'})));
      controller.sink.add(MessageEvent(
          'put',
          '{"my-boolean-flag": '
              '{"version":11,"value":true,"variation":0,"trackEvents":false}}',
          null));
      for (var i = 0; i < 5; i++) {
        await Future<void>.delayed(Duration.zero);
      }

      expect(flagManager.environmentId, 'env-from-header');
    });

    test(
        'it uses the platform environment ID fallback when the connection '
        'provides no headers', () async {
      final controller = StreamController<Event>();
      final (dataSource, flagManager, _) =
          makeDataSourceForTest(controller.stream);
      dataSource.start();

      controller.sink.add(OpenEvent(headers: null));
      controller.sink.add(MessageEvent(
          'put',
          '{"my-boolean-flag": '
              '{"version":11,"value":true,"variation":0,"trackEvents":false}}',
          null));
      for (var i = 0; i < 5; i++) {
        await Future<void>.delayed(Duration.zero);
      }

      // A mobile key does not identify an environment, so the fallback
      // is null on this platform.
      expect(flagManager.environmentId, isNull);
    });
  });
}
