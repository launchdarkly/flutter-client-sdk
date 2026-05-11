import 'dart:convert';

import 'package:http/testing.dart';
import 'package:launchdarkly_common_client/launchdarkly_common_client.dart';
import 'package:launchdarkly_common_client/src/config/data_source_config.dart';
import 'package:launchdarkly_common_client/src/data_sources/data_source.dart';
import 'package:launchdarkly_common_client/src/data_sources/data_source_event_handler.dart';
import 'package:launchdarkly_common_client/src/data_sources/data_source_status.dart';
import 'package:launchdarkly_common_client/src/data_sources/data_source_status_manager.dart';
import 'package:launchdarkly_common_client/src/data_sources/polling_data_source.dart';
import 'package:launchdarkly_common_client/src/flag_manager/flag_manager.dart';
import 'package:launchdarkly_dart_common/launchdarkly_dart_common.dart'
    as ld_common;
import 'package:http/http.dart' as http;
import 'package:mocktail/mocktail.dart';

import 'package:test/test.dart';

class MockLogAdapter extends Mock implements LDLogAdapter {}

(PollingDataSource, FlagManager, DataSourceStatusManager) makeDataSourceForTest(
    MockClient innerClient,
    {LDContext? inContext,
    HttpProperties? inProperties,
    bool useReport = false,
    bool withReasons = false,
    Duration? testingInterval,
    LDLogger? inLogger}) {
  final context = inContext ?? LDContextBuilder().kind('user', 'test').build();
  // We are not testing the data source status manager here, so we just want a
  // fixed time to make events easy to get.
  final statusManager = DataSourceStatusManager(stamper: () => DateTime(1));
  final logger = inLogger ?? LDLogger();
  final httpProperties = inProperties ?? HttpProperties();
  const sdkKey = 'dummy-key';
  final flagManager =
      FlagManager(sdkKey: sdkKey, logger: logger, maxCachedContexts: 5);

  final eventHandler = DataSourceEventHandler(
      logger: logger, flagManager: flagManager, statusManager: statusManager);

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
      httpClientFactory: (properties) =>
          ld_common.HttpClient(client: innerClient, httpProperties: properties),
      testingInterval: testingInterval);

  polling.events.asyncMap((event) async {
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
          'https://clientsdk.launchdarkly.com/msdk/evalx/context');
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
          'https://clientsdk.launchdarkly.com/msdk/evalx/context');
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
          'https://clientsdk.launchdarkly.com/msdk/evalx/context');
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

  test('it extracts environment ID from response headers', () async {
    final flagData = '{"testFlag":{"version":1,"value":true,"variation":0}}';
    var receivedEnvironmentId = '';

    final innerClient = MockClient((request) async {
      return http.Response(flagData, 200,
          headers: {'x-ld-envid': 'env-123-test'});
    });

    final context = LDContextBuilder().kind('user', 'test').build();
    final statusManager = DataSourceStatusManager(stamper: () => DateTime(1));
    final logger = LDLogger();
    const sdkKey = 'dummy-key';
    final flagManager =
        FlagManager(sdkKey: sdkKey, logger: logger, maxCachedContexts: 5);

    final eventHandler = DataSourceEventHandler(
        logger: logger, flagManager: flagManager, statusManager: statusManager);

    final polling = PollingDataSource(
        credential: sdkKey,
        context: context,
        endpoints: ServiceEndpoints(),
        logger: logger,
        dataSourceConfig: PollingDataSourceConfig(
            pollingInterval: const Duration(seconds: 30),
            withReasons: false,
            useReport: false),
        httpProperties: HttpProperties(),
        httpClientFactory: (properties) => ld_common.HttpClient(
            client: innerClient, httpProperties: properties),
        testingInterval: Duration(milliseconds: 50));

    polling.events.asyncMap((event) async {
      switch (event) {
        case DataEvent():
          receivedEnvironmentId = event.environmentId ?? '';
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
      }
    }).listen((_) {});

    polling.start();

    // Wait for the polling to complete and the environment ID to be processed
    await Future.delayed(Duration(milliseconds: 100));

    // Verify that the environment ID was extracted from headers and passed through
    expect(receivedEnvironmentId, 'env-123-test');
    expect(flagManager.environmentId, 'env-123-test');

    polling.stop();
  });

  test('it handles missing environment ID header gracefully', () async {
    final flagData = '{"testFlag":{"version":1,"value":true,"variation":0}}';
    var receivedEnvironmentId = '';

    final innerClient = MockClient((request) async {
      return http.Response(flagData, 200); // No environment ID header
    });

    final context = LDContextBuilder().kind('user', 'test').build();
    final statusManager = DataSourceStatusManager(stamper: () => DateTime(1));
    final logger = LDLogger();
    const sdkKey = 'dummy-key';
    final flagManager =
        FlagManager(sdkKey: sdkKey, logger: logger, maxCachedContexts: 5);

    final eventHandler = DataSourceEventHandler(
        logger: logger, flagManager: flagManager, statusManager: statusManager);

    final polling = PollingDataSource(
        credential: sdkKey,
        context: context,
        endpoints: ServiceEndpoints(),
        logger: logger,
        dataSourceConfig: PollingDataSourceConfig(
            pollingInterval: const Duration(seconds: 30),
            withReasons: false,
            useReport: false),
        httpProperties: HttpProperties(),
        httpClientFactory: (properties) => ld_common.HttpClient(
            client: innerClient, httpProperties: properties),
        testingInterval: Duration(milliseconds: 50));

    polling.events.asyncMap((event) async {
      switch (event) {
        case DataEvent():
          receivedEnvironmentId = event.environmentId ?? 'null-received';
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
      }
    }).listen((_) {});

    polling.start();

    // Wait for the polling to complete
    await Future.delayed(Duration(milliseconds: 100));

    // Verify that no environment ID was received and store remains null
    expect(receivedEnvironmentId, 'null-received');
    expect(flagManager.environmentId, null);

    polling.stop();
  });

  group('conditional requests', () {
    setUpAll(() {
      registerFallbackValue(LDLogRecord(
          level: LDLogLevel.debug,
          message: '',
          time: DateTime.now(),
          logTag: ''));
    });

    test(
        'sends if-none-match on the next request after receiving a 200 with etag',
        () async {
      var requestNumber = 0;
      Map<String, String>? secondRequestHeaders;
      final innerClient = MockClient((request) async {
        requestNumber++;
        if (requestNumber == 1) {
          return http.Response('{}', 200, headers: {'etag': 'abc-123'});
        }
        secondRequestHeaders = request.headers;
        return http.Response('{}', 200);
      });

      final (polling, _, _) = makeDataSourceForTest(innerClient,
          testingInterval: const Duration(milliseconds: 5));
      polling.start();

      // Drain to the second request before asserting.
      while (requestNumber < 2) {
        await Future<void>.delayed(const Duration(milliseconds: 5));
      }
      polling.stop();

      expect(secondRequestHeaders, containsPair('if-none-match', 'abc-123'));
      // The wrong header name (`etag`) must not be sent.
      expect(secondRequestHeaders!.containsKey('etag'), isFalse);
    });

    test('empty-string etag on a 200 response is not stored', () async {
      var requestNumber = 0;
      Map<String, String>? secondRequestHeaders;
      final innerClient = MockClient((request) async {
        requestNumber++;
        if (requestNumber == 1) {
          return http.Response('{}', 200, headers: {'etag': ''});
        }
        secondRequestHeaders = request.headers;
        return http.Response('{}', 200);
      });

      final (polling, _, _) = makeDataSourceForTest(innerClient,
          testingInterval: const Duration(milliseconds: 5));
      polling.start();

      while (requestNumber < 2) {
        await Future<void>.delayed(const Duration(milliseconds: 5));
      }
      polling.stop();

      // An unquoted empty token is invalid per RFC 7232 and sending
      // `if-none-match: ` could pin the SDK to permanent 304s on lenient
      // servers. The empty value must not round-trip.
      expect(secondRequestHeaders!.containsKey('if-none-match'), isFalse);
    });

    test('200 without an etag header preserves the previously stored value',
        () async {
      var requestNumber = 0;
      Map<String, String>? thirdRequestHeaders;
      final innerClient = MockClient((request) async {
        requestNumber++;
        if (requestNumber == 1) {
          return http.Response('{}', 200, headers: {'etag': 'first'});
        }
        if (requestNumber == 2) {
          // 200 without an etag header. Old code would clear `_lastEtag`
          // to null here; the fix preserves "first".
          return http.Response('{}', 200);
        }
        thirdRequestHeaders = request.headers;
        return http.Response('{}', 200);
      });

      final (polling, _, _) = makeDataSourceForTest(innerClient,
          testingInterval: const Duration(milliseconds: 5));
      polling.start();

      while (requestNumber < 3) {
        await Future<void>.delayed(const Duration(milliseconds: 5));
      }
      polling.stop();

      expect(thirdRequestHeaders, containsPair('if-none-match', 'first'));
    });

    test('304 response is treated as no-change, not as malformed data',
        () async {
      // The pre-fix behavior fell through 304 to DataEvent('put', '', ...),
      // which downstream parsed as empty JSON and surfaced as
      // `ErrorKind.invalidData`. The fix returns null on 304, so the
      // status manager should never see an `invalidData` error.
      var requestCount = 0;
      final innerClient = MockClient((request) async {
        requestCount++;
        return http.Response('', 304);
      });

      final (polling, flagManager, statusManager) = makeDataSourceForTest(
          innerClient,
          testingInterval: const Duration(milliseconds: 5));
      polling.start();

      while (requestCount < 1) {
        await Future<void>.delayed(const Duration(milliseconds: 5));
      }
      // Give the status pipeline a chance to surface anything.
      await Future<void>.delayed(const Duration(milliseconds: 20));
      polling.stop();

      final lastError = statusManager.status.lastError;
      expect(lastError?.kind, isNot(equals(ErrorKind.invalidData)));
      // FlagManager should remain in its initial empty state -- no
      // attempt was made to parse the empty body.
      expect(flagManager.environmentId, isNull);
    });

    test('a 304 response does not stop polling', () async {
      // Regression: a previous version of _doPoll early-returned on a
      // null event without scheduling the next poll, so the first 304
      // permanently halted the loop. This pins multiple 304s in a row
      // resulting in multiple requests.
      var requestCount = 0;
      final innerClient = MockClient((request) async {
        requestCount++;
        return http.Response('', 304);
      });

      final (polling, _, _) = makeDataSourceForTest(innerClient,
          testingInterval: const Duration(milliseconds: 5));
      polling.start();

      while (requestCount < 3) {
        await Future<void>.delayed(const Duration(milliseconds: 5));
      }
      polling.stop();

      expect(requestCount, greaterThanOrEqualTo(3));
    });
  });

  group('network error log content', () {
    setUpAll(() {
      registerFallbackValue(LDLogRecord(
          level: LDLogLevel.debug,
          message: '',
          time: DateTime.now(),
          logTag: ''));
    });

    test(
        'warn-level log on a network error does not contain the encoded context',
        () async {
      // http.ClientException's toString embeds the request URL, which
      // in turn embeds the base64url-encoded context. The requestor
      // must categorize the exception into a fixed string and log
      // only that.
      final adapter = MockLogAdapter();
      when(() => adapter.log(any())).thenReturn(null);
      final logger = LDLogger(adapter: adapter, level: LDLogLevel.debug);

      final secretContext =
          LDContextBuilder().kind('user', 'secret-key-shibboleth').build();
      final innerClient = MockClient((request) async {
        throw http.ClientException('Connection refused', request.url);
      });

      final (polling, _, statusManager) = makeDataSourceForTest(innerClient,
          inContext: secretContext,
          inLogger: logger,
          testingInterval: const Duration(milliseconds: 1));
      polling.start();
      await Future<void>.delayed(const Duration(milliseconds: 30));
      polling.stop();

      final encodedContext = base64UrlEncode(utf8.encode(jsonEncode(
          ld_common.LDContextSerialization.toJson(secretContext,
              isEvent: false))));
      final records = verify(() => adapter.log(captureAny())).captured;
      for (final record in records) {
        expect(
            (record as LDLogRecord).message, isNot(contains(encodedContext)));
        expect(record.message, isNot(contains('secret-key-shibboleth')));
      }

      // The user-visible status surface must also not echo the URL.
      final lastError = statusManager.status.lastError;
      if (lastError != null) {
        expect(lastError.message, isNot(contains(encodedContext)));
        expect(lastError.message, isNot(contains('secret-key-shibboleth')));
      }
    });
  });
}
