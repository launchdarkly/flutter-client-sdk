// ignore_for_file: close_sinks

import 'dart:async';

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
import 'package:launchdarkly_event_source_client/launchdarkly_event_source_client.dart';
import 'package:http/http.dart' as http;
import 'package:test/test.dart';

class MockSseClient implements SSEClient {
  final Stream<MessageEvent> mockStream;

  MockSseClient(this.mockStream);

  @override
  Future close() async {}

  @override
  void restart() {}

  @override
  Stream<MessageEvent> get stream => mockStream;
}

(
  StreamingDataSource,
  FlagManager,
  DataSourceStatusManager
) makeDataSourceForTest(Stream<MessageEvent> mockStream,
    {LDContext? inContext,
    HttpProperties? inProperties,
    bool useReport = false,
    bool withReasons = false,
    Duration? testingInterval,
    MockClient? mockHttpClient,
    Function(Uri, HttpProperties, String?, SseHttpMethod?)? factoryCallback}) {
  final context = inContext ?? LDContextBuilder().kind('user', 'test').build();
  // We are not testing the data source status manager here, so we just want a
  // fixed time to make events easy to get.
  final statusManager = DataSourceStatusManager(stamper: () => DateTime(1));

  final logger = LDLogger();
  final properties = inProperties ?? HttpProperties();

  final client = MockSseClient(mockStream);
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
      clientFactory: (Uri uri, HttpProperties properties, String? body,
          SseHttpMethod? method, EventSourceLogger? logger) {
        factoryCallback?.call(uri, properties, body, method);
        return client;
      });

  streaming.events.asyncMap((event) async {
    switch (event) {
      case DataEvent():
        return eventHandler.handleMessage(context, event.type, event.data);
      case StatusEvent():
        if (event.statusCode != null) {
          statusManager.setErrorResponse(event.statusCode!, event.message,
              shutdown: event.shutdown);
        } else {
          statusManager.setErrorByKind(event.kind, event.message,
              shutdown: event.shutdown);
        }
    }
  }).listen((_) {});

  return (streaming, flagManager, statusManager);
}

void main() {
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
}
