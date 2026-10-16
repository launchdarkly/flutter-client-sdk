import 'dart:async';

import 'package:fake_async/fake_async.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:launchdarkly_common_client/launchdarkly_common_client.dart';
import 'package:launchdarkly_common_client/src/config/data_source_config.dart';
import 'package:launchdarkly_common_client/src/data_sources/data_source.dart';
import 'package:launchdarkly_common_client/src/data_sources/data_source_status.dart';
import 'package:launchdarkly_common_client/src/data_sources/streaming_data_source.dart';
import 'package:launchdarkly_dart_common/launchdarkly_dart_common.dart'
    as ld_common;
import 'package:launchdarkly_event_source_client/launchdarkly_event_source_client.dart';
import 'package:mocktail/mocktail.dart';
import 'package:test/test.dart';

class _MockLogAdapter extends Mock implements LDLogAdapter {}

const _credentialHint =
    'Check that the SDK credential (mobile key or client-side ID) is correct.';

/// Holds a streaming data source and every SSE client that it makes.
final class _Harness {
  final StreamingDataSource dataSource;
  final List<TestSseClient> clients;
  final List<DataSourceEvent> events;

  _Harness(this.dataSource, this.clients, this.events);

  List<StatusEvent> get statuses => events.whereType<StatusEvent>().toList();
}

_Harness _makeHarness({MockClient? pollingClient, LDLogger? logger}) {
  final clients = <TestSseClient>[];
  final events = <DataSourceEvent>[];
  final dataSource = StreamingDataSource(
      credential: 'dummy-key',
      context: LDContextBuilder().kind('user', 'test').build(),
      endpoints: ServiceEndpoints(),
      logger: logger ?? LDLogger(level: LDLogLevel.none),
      dataSourceConfig: StreamingDataSourceConfig(),
      pollingDataSourceConfig: PollingDataSourceConfig(),
      httpProperties: HttpProperties(),
      httpClientFactory: pollingClient != null
          ? (properties) => ld_common.HttpClient(
              client: pollingClient, httpProperties: properties)
          : null,
      clientFactory: (uri, properties, body, method, logger) {
        final client = SSEClient.testClient(uri, {});
        clients.add(client);
        return client;
      });
  dataSource.events.listen(events.add);
  return _Harness(dataSource, clients, events);
}

void main() {
  setUpAll(() {
    registerFallbackValue(LDLogRecord(
        level: LDLogLevel.debug,
        message: '',
        time: DateTime.now(),
        logTag: ''));
  });

  /// Sends a ping whose poll gets [status], and returns the records logged
  /// about it.
  List<LDLogRecord> pingPollLogs(int status) {
    final adapter = _MockLogAdapter();
    final records = <LDLogRecord>[];
    fakeAsync((async) {
      final harness = _makeHarness(
          pollingClient:
              MockClient((request) async => http.Response('', status)),
          logger: LDLogger(adapter: adapter, level: LDLogLevel.debug));
      harness.dataSource.start();
      async.flushMicrotasks();
      harness.clients[0].emitEvent(MessageEvent('ping', '', null));
      async.flushMicrotasks();
      harness.dataSource.stop();
      records.addAll(verify(() => adapter.log(captureAny()))
          .captured
          .cast<LDLogRecord>()
          .where((record) => record.message.contains('ping')));
    });
    return records;
  }

  test('a normal failure of the poll after a ping logs a warning', () {
    final records = pingPollLogs(503);
    expect(records.map((record) => record.level), [LDLogLevel.warn]);
  });

  for (final status in [401, 403]) {
    test('a $status for the poll after a ping logs an error with the hint', () {
      final records = pingPollLogs(status);
      expect(records.map((record) => record.level), [LDLogLevel.error]);
      expect(records.single.message, contains(_credentialHint));
    });
  }

  test('a 404 for the poll after a ping logs an error without the hint', () {
    final records = pingPollLogs(404);
    expect(records.map((record) => record.level), [LDLogLevel.error]);
    expect(records.single.message, isNot(contains('Check that')));
  });

  /// Fails the stream with [status], and returns the records logged about
  /// it.
  List<LDLogRecord> streamFailureLogs(int status) {
    final adapter = _MockLogAdapter();
    final records = <LDLogRecord>[];
    fakeAsync((async) {
      final harness = _makeHarness(
          logger: LDLogger(adapter: adapter, level: LDLogLevel.debug));
      harness.dataSource.start();
      async.flushMicrotasks();
      harness.clients[0]
          .emitError(error: SseHttpError(status, {}, recoverable: false));
      async.flushMicrotasks();
      harness.dataSource.stop();
      records.addAll(verify(() => adapter.log(captureAny()))
          .captured
          .cast<LDLogRecord>()
          .where((record) => record.message.contains('$status')));
    });
    return records;
  }

  for (final status in [401, 403]) {
    test('a $status for the stream logs an error with the hint', () {
      final records = streamFailureLogs(status);
      expect(records.map((record) => record.level), [LDLogLevel.error]);
      expect(records.single.message, contains(_credentialHint));
      expect(records.single.message, contains('Will retry in'));
    });
  }

  test('a 404 for the stream logs an error without the hint', () {
    final records = streamFailureLogs(404);
    expect(records.map((record) => record.level), [LDLogLevel.error]);
    expect(records.single.message, isNot(contains('Check that')));
    expect(records.single.message, contains('Will retry in'));
  });

  test('a 401 reconnects after the extended initial delay', () {
    fakeAsync((async) {
      final harness = _makeHarness();
      harness.dataSource.start();
      async.flushMicrotasks();
      expect(harness.clients, hasLength(1));

      harness.clients[0]
          .emitError(error: SseHttpError(401, {}, recoverable: false));
      async.flushMicrotasks();

      expect(harness.statuses, hasLength(1));
      expect(harness.statuses[0].statusCode, 401);
      expect(harness.statuses[0].shutdown, isFalse);
      expect(harness.clients[0].isClosed, isTrue);

      // The extended initial delay is 5 minutes, less up to half as jitter.
      async.elapse(const Duration(seconds: 149));
      expect(harness.clients, hasLength(1));
      async.elapse(const Duration(seconds: 151));
      expect(harness.clients, hasLength(2));
    });
  });

  test('a 503 reconnects after the normal initial delay', () {
    fakeAsync((async) {
      final harness = _makeHarness();
      harness.dataSource.start();
      async.flushMicrotasks();

      harness.clients[0]
          .emitError(error: SseHttpError(503, {}, recoverable: false));
      async.flushMicrotasks();
      expect(harness.statuses.single.statusCode, 503);

      async.elapse(const Duration(milliseconds: 499));
      expect(harness.clients, hasLength(1));
      async.elapse(const Duration(milliseconds: 501));
      expect(harness.clients, hasLength(2));
    });
  });

  test('a transport failure backs off and reports a network error', () {
    fakeAsync((async) {
      final harness = _makeHarness();
      harness.dataSource.start();
      async.flushMicrotasks();

      harness.clients[0].emitError(error: Exception('connection reset'));
      async.flushMicrotasks();
      expect(harness.statuses.single.kind, ErrorKind.networkError);
      expect(harness.statuses.single.shutdown, isFalse);

      async.elapse(const Duration(seconds: 1));
      expect(harness.clients, hasLength(2));

      // The second normal failure doubles the base delay to 2 seconds.
      harness.clients[1].emitError(error: Exception('connection reset'));
      async.flushMicrotasks();
      async.elapse(const Duration(milliseconds: 999));
      expect(harness.clients, hasLength(2));
      async.elapse(const Duration(milliseconds: 1001));
      expect(harness.clients, hasLength(3));
    });
  });

  test('a normal failure after a 401 keeps the extended delay', () {
    fakeAsync((async) {
      final harness = _makeHarness();
      harness.dataSource.start();
      async.flushMicrotasks();

      harness.clients[0]
          .emitError(error: SseHttpError(401, {}, recoverable: false));
      async.flushMicrotasks();
      async.elapse(const Duration(minutes: 5));
      expect(harness.clients, hasLength(2));

      // The second extended attempt has a base delay of 10 minutes.
      harness.clients[1].emitError(error: Exception('connection reset'));
      async.flushMicrotasks();
      async.elapse(const Duration(seconds: 299));
      expect(harness.clients, hasLength(2));
      async.elapse(const Duration(seconds: 301));
      expect(harness.clients, hasLength(3));
    });
  });

  test('stop interrupts a pending wait', () {
    fakeAsync((async) {
      final harness = _makeHarness();
      harness.dataSource.start();
      async.flushMicrotasks();

      harness.clients[0]
          .emitError(error: SseHttpError(401, {}, recoverable: false));
      async.flushMicrotasks();

      harness.dataSource.stop();
      expect(async.pendingTimers, isEmpty);

      async.elapse(const Duration(hours: 2));
      expect(harness.clients, hasLength(1));
      expect(harness.statuses, hasLength(1));
    });
  });

  test('start after stop does not connect', () {
    fakeAsync((async) {
      final harness = _makeHarness();
      harness.dataSource.start();
      async.flushMicrotasks();
      harness.dataSource.stop();
      harness.dataSource.start();
      async.elapse(const Duration(hours: 2));
      expect(harness.clients, hasLength(1));
    });
  });

  test('no status is reported for a ping poll that ends after stop', () {
    fakeAsync((async) {
      final response = Completer<http.Response>();
      final harness =
          _makeHarness(pollingClient: MockClient((request) => response.future));
      harness.dataSource.start();
      async.flushMicrotasks();

      harness.clients[0].emitEvent(MessageEvent('ping', '', null));
      async.flushMicrotasks();
      harness.dataSource.stop();
      response.complete(http.Response('', 401));
      async.flushMicrotasks();

      expect(harness.events, isEmpty);
    });
  });

  test('restart reconnects with the normal delay', () {
    fakeAsync((async) {
      final harness = _makeHarness();
      harness.dataSource.start();
      async.flushMicrotasks();
      harness.clients[0].emitEvent(MessageEvent('put', '{}', null));
      async.flushMicrotasks();

      harness.dataSource.restart();
      expect(harness.clients[0].isClosed, isTrue);

      async.elapse(const Duration(seconds: 1));
      expect(harness.clients, hasLength(2));
      expect(harness.statuses, isEmpty);
    });
  });

  test('restart during a wait does not make another connection', () {
    fakeAsync((async) {
      final harness = _makeHarness();
      harness.dataSource.start();
      async.flushMicrotasks();
      harness.clients[0].emitError(error: Exception('connection reset'));
      async.flushMicrotasks();

      harness.dataSource.restart();
      async.elapse(const Duration(seconds: 1));
      expect(harness.clients, hasLength(2));
      async.elapse(const Duration(minutes: 1));
      expect(harness.clients, hasLength(2));
    });
  });
}
