import 'dart:convert';

import 'package:http/testing.dart';
import 'package:launchdarkly_dart_client/ld_client.dart';
import 'package:launchdarkly_dart_client/src/config/data_source_config.dart';
import 'package:launchdarkly_dart_client/src/data_sources/data_source.dart';
import 'package:launchdarkly_dart_client/src/data_sources/data_source_event_handler.dart';
import 'package:launchdarkly_dart_client/src/data_sources/data_source_status.dart';
import 'package:launchdarkly_dart_client/src/data_sources/data_source_status_manager.dart';
import 'package:launchdarkly_dart_client/src/data_sources/polling_data_source.dart';
import 'package:launchdarkly_dart_client/src/flag_manager/flag_manager.dart';
import 'package:launchdarkly_dart_common/ld_common.dart' as ld_common;
import 'package:http/http.dart' as http;

import 'package:test/test.dart';

(PollingDataSource, FlagManager, DataSourceStatusManager) makeDataSourceForTest(
    MockClient innerClient,
    {LDContext? inContext,
      HttpProperties? inProperties,
      bool useReport = false,
      bool withReasons = false,
      Duration? testingInterval}) {
  final context = inContext ?? LDContextBuilder().kind('user', 'test').build();
  // We are not testing the data source status manager here, so we just want a
  // fixed time to make events easy to get.
  final statusManager = DataSourceStatusManager(stamper: () => DateTime(1));
  final logger = LDLogger();
  final httpProperties = inProperties ?? HttpProperties();
  const sdkKey = 'dummy-key';
  final flagManager =
  FlagManager(sdkKey: sdkKey, logger: logger, maxCachedContexts: 5);

  final eventHandler = DataSourceEventHandler(
      logger: logger,
      flagManager: flagManager,
      statusManager: statusManager);

  final polling = PollingDataSource(
      credential: sdkKey,
      context: context,
      endpoints: ServiceEndpoints(),
      logger: logger,
      dataSourceConfig: PollingDataSourceConfig(
          pollingInterval: const Duration(seconds: 30),
          withReasons: withReasons,
          useReport: useReport),
      httpProperties: httpProperties,
      clientFactory: (properties) =>
          ld_common.HttpClient(client: innerClient, httpProperties: properties),
      testingInterval: testingInterval);

  polling.events.asyncMap((event) async {
    switch (event) {
      case DataEvent():
        return eventHandler.handleMessage(context, event.type, event.data);
      case StatusEvent():
        if (event.statusCode != null) {
          statusManager.setErrorResponse(event.statusCode!, event.message, shutdown: event.shutdown);
        } else {
          statusManager.setErrorByKind(event.kind, event.message, shutdown: event.shutdown);
        }
    }}).listen((_){});

  return (polling, flagManager, statusManager);
}

void main() {
  test('it makes an initial polling request', () {
    var methodCalled = false;
    final innerClient = MockClient((request) async {
      methodCalled = true;
      return http.Response('{}', 200);
    });

    final (polling, _, statusManager) = makeDataSourceForTest(innerClient);

    statusManager.changes.listen((event) {
      expect(methodCalled, isTrue);
    });
    expectLater(
        statusManager.changes,
        emits(DataSourceStatus(
            state: DataSourceState.valid, stateSince: DateTime(1))));

    polling.start();
  });

  test('permanent failure is reported for a 404', () {
    var methodCalled = false;
    final innerClient = MockClient((request) async {
      methodCalled = true;
      return http.Response('{}', 404);
    });

    final (polling, _, statusManager) = makeDataSourceForTest(innerClient);

    statusManager.changes.listen((event) {
      expect(methodCalled, isTrue);
    });
    expectLater(
        statusManager.changes,
        emits(DataSourceStatus(
            state: DataSourceState.shutdown,
            stateSince: DateTime(1),
            lastError: DataSourceStatusErrorInfo(
                kind: ErrorKind.errorResponse,
                message: 'Received unexpected status code: 404',
                time: DateTime(1),
                statusCode: 404))));

    polling.start();
  });

  test('it includes the content-type header for REPORT requests', () {
    var methodCalled = false;
    final innerClient = MockClient((request) async {
      methodCalled = true;
      expect(request.method, 'REPORT');
      expect(request.headers, containsPair('content-type', 'application/json'));
      return http.Response('{}', 200);
    });

    final (polling, _, statusManager) =
    makeDataSourceForTest(innerClient, useReport: true);

    statusManager.changes.listen((event) {
      expect(methodCalled, isTrue);
    });
    expectLater(
        statusManager.changes,
        emits(DataSourceStatus(
            state: DataSourceState.valid, stateSince: DateTime(1))));

    polling.start();
  });

  test('it sends the context in the body for REPORT requests', () {
    final context = LDContextBuilder().kind('user', 'test').build();
    var methodCalled = false;
    final innerClient = MockClient((request) async {
      methodCalled = true;
      final actualContextAsValue =
      ld_common.LDValueSerialization.fromJson(jsonDecode(request.body));
      final expectedContextAsValue = ld_common.LDValueSerialization.fromJson(
          jsonDecode(jsonEncode(ld_common.LDContextSerialization.toJson(context,
              isEvent: false))));
      expect(actualContextAsValue, expectedContextAsValue);
      return http.Response('{}', 200);
    });

    final (polling, _, statusManager) =
    makeDataSourceForTest(innerClient, useReport: true, inContext: context);

    statusManager.changes.listen((event) {
      expect(methodCalled, isTrue);
    });
    expectLater(
        statusManager.changes,
        emits(DataSourceStatus(
            state: DataSourceState.valid, stateSince: DateTime(1))));

    polling.start();
  });

  group('given GET or REPORT', () {
    for (var method in [
      ld_common.RequestMethod.get,
      ld_common.RequestMethod.report
    ]) {
      test('it includes withReason in the URL when requested: $method', () {
        var methodCalled = false;
        final innerClient = MockClient((request) async {
          methodCalled = true;
          expect(request.url.toString(), endsWith('?withReasons=true'));
          return http.Response('{}', 200);
        });

        final (polling, _, statusManager) = makeDataSourceForTest(innerClient,
            withReasons: true,
            useReport: method == ld_common.RequestMethod.report);

        statusManager.changes.listen((event) {
          expect(methodCalled, isTrue);
        });
        expectLater(
            statusManager.changes,
            emits(DataSourceStatus(
                state: DataSourceState.valid, stateSince: DateTime(1))));

        polling.start();
      });
    }
  });

  test('it uses the correct polling URL for GET requests', () {
    var methodCalled = false;
    final innerClient = MockClient((request) async {
      methodCalled = true;
      expect(request.url.toString(),
          'https://clientsdk.launchdarkly.com/msdk/evalx/contexts/eyJrZXkiOiJ0ZXN0Iiwia2luZCI6InVzZXIifQ==');
      return http.Response('{}', 200);
    });

    final (polling, _, statusManager) = makeDataSourceForTest(innerClient);

    statusManager.changes.listen((event) {
      expect(methodCalled, isTrue);
    });
    expectLater(
        statusManager.changes,
        emits(DataSourceStatus(
            state: DataSourceState.valid, stateSince: DateTime(1))));

    polling.start();
  });

  test('it uses the correct polling URL for REPORT requests', () {
    var methodCalled = false;
    final innerClient = MockClient((request) async {
      methodCalled = true;
      expect(request.url.toString(),
          'https://clientsdk.launchdarkly.com/msdk/evalx/contexts');
      return http.Response('{}', 200);
    });

    final (polling, _, statusManager) =
    makeDataSourceForTest(innerClient, useReport: true);

    statusManager.changes.listen((event) {
      expect(methodCalled, isTrue);
    });
    expectLater(
        statusManager.changes,
        emits(DataSourceStatus(
            state: DataSourceState.valid, stateSince: DateTime(1))));

    polling.start();
  });

  test('it polls on the interval', () async {
    var calledCount = 0;
    final innerClient = MockClient((request) async {
      calledCount += 1;
      expect(request.url.toString(),
          'https://clientsdk.launchdarkly.com/msdk/evalx/contexts');
      return http.Response('{}', 200);
    });

    final (polling, _, _) = makeDataSourceForTest(innerClient,
        useReport: true, testingInterval: Duration(milliseconds: 30));

    polling.start();

    while (calledCount < 2) {
      await Future.delayed(Duration(milliseconds: 30));
    }
  });

  test('it stops polling when stopped', () async {
    var calledCount = 0;
    final innerClient = MockClient((request) async {
      calledCount += 1;
      expect(request.url.toString(),
          'https://clientsdk.launchdarkly.com/msdk/evalx/contexts');
      return http.Response('{}', 200);
    });

    final (polling, _, _) = makeDataSourceForTest(innerClient,
        useReport: true, testingInterval: Duration(milliseconds: 50));

    polling.start();
    polling.stop();
    await Future.delayed(Duration(milliseconds: 100));
    expect(calledCount, 1);
  });

  test('it reports recoverable errors while initializing - status code', () {
    var methodCalled = false;
    final innerClient = MockClient((request) async {
      methodCalled = true;
      return http.Response('{}', 503);
    });

    final (polling, _, statusManager) = makeDataSourceForTest(innerClient);

    statusManager.changes.listen((event) {
      expect(methodCalled, isTrue);
    });
    expectLater(
        statusManager.changes,
        emits(DataSourceStatus(
            state: DataSourceState.initializing,
            stateSince: DateTime(1),
            lastError: DataSourceStatusErrorInfo(
                kind: ErrorKind.errorResponse,
                message: 'Received unexpected status code: 503',
                time: DateTime(1),
                statusCode: 503))));

    polling.start();
  });

  test('it reports recoverable errors while initializing - invalid json', () {
    var methodCalled = false;
    final innerClient = MockClient((request) async {
      methodCalled = true;
      return http.Response(')(&&*^', 200);
    });

    final (polling, _, statusManager) = makeDataSourceForTest(innerClient);

    statusManager.changes.listen((event) {
      expect(methodCalled, isTrue);
    });
    expectLater(
        statusManager.changes,
        emits(DataSourceStatus(
            state: DataSourceState.initializing,
            stateSince: DateTime(1),
            lastError: DataSourceStatusErrorInfo(
                kind: ErrorKind.invalidData,
                message: 'Could not parse PUT message',
                time: DateTime(1),
                statusCode: null))));

    polling.start();
  });

  test('it reports recoverable errors while initializing - invalid put data',
          () {
        var methodCalled = false;
        final innerClient = MockClient((request) async {
          methodCalled = true;
          return http.Response('{"boat": true}', 200);
        });

        final (polling, _, statusManager) = makeDataSourceForTest(innerClient);

        statusManager.changes.listen((event) {
          expect(methodCalled, isTrue);
        });
        expectLater(
            statusManager.changes,
            emits(DataSourceStatus(
                state: DataSourceState.initializing,
                stateSince: DateTime(1),
                lastError: DataSourceStatusErrorInfo(
                    kind: ErrorKind.invalidData,
                    message: 'PUT message contained invalid data',
                    time: DateTime(1),
                    statusCode: null))));

        polling.start();
      });

  test('it transitions to interrupted for recoverable errors after valid', () {
    var statusCode = 200;
    var methodCalled = false;
    final innerClient = MockClient((request) async {
      methodCalled = true;
      return http.Response('{}', statusCode);
    });

    final (polling, _, statusManager) = makeDataSourceForTest(innerClient,
        testingInterval: Duration(milliseconds: 100));

    statusManager.changes.listen((event) {
      statusCode = 503;
      expect(methodCalled, isTrue);
    });
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

    polling.start();
  });
}
