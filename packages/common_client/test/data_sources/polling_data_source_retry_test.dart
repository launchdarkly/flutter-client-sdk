import 'dart:async';

import 'package:fake_async/fake_async.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:launchdarkly_common_client/launchdarkly_common_client.dart';
import 'package:launchdarkly_common_client/src/config/data_source_config.dart';
import 'package:launchdarkly_common_client/src/data_sources/data_source.dart';
import 'package:launchdarkly_common_client/src/data_sources/polling_data_source.dart';
import 'package:launchdarkly_dart_common/launchdarkly_dart_common.dart'
    as ld_common;
import 'package:mocktail/mocktail.dart';
import 'package:test/test.dart';

class _MockLogAdapter extends Mock implements LDLogAdapter {}

const _credentialHint =
    'Check that the SDK credential (mobile key or client-side ID) is correct.';

const _interval = Duration(seconds: 30);

/// Holds a polling data source whose responses come from [statuses], in
/// order. The last status repeats.
final class _Harness {
  final PollingDataSource dataSource;
  final List<DataSourceEvent> events = [];

  /// The fake time of each request.
  final List<Duration> requestTimes = [];

  _Harness._(this.dataSource);

  factory _Harness(FakeAsync async, List<int> statuses) {
    late final _Harness harness;
    final client = MockClient((request) async {
      final index = harness.requestTimes.length;
      harness.requestTimes.add(async.elapsed);
      final status =
          statuses[index < statuses.length ? index : -1 + statuses.length];
      return switch (status) {
        200 => http.Response('{}', 200),
        _ => http.Response('', status),
      };
    });
    harness = _Harness._(PollingDataSource(
        credential: 'dummy-key',
        context: LDContextBuilder().kind('user', 'test').build(),
        endpoints: ServiceEndpoints(),
        logger: LDLogger(level: LDLogLevel.none),
        dataSourceConfig: PollingDataSourceConfig(),
        httpProperties: HttpProperties(),
        testingInterval: _interval,
        httpClientFactory: (properties) =>
            ld_common.HttpClient(client: client, httpProperties: properties)));
    harness.dataSource.events.listen(harness.events.add);
    return harness;
  }

  List<StatusEvent> get statuses => events.whereType<StatusEvent>().toList();

  /// The wait between request [index] and the request before it.
  Duration waitBefore(int index) =>
      requestTimes[index] - requestTimes[index - 1];
}

/// Matches a wait of one poll interval.
final _oneInterval = allOf(greaterThan(_interval - const Duration(seconds: 1)),
    lessThanOrEqualTo(_interval));

void main() {
  setUpAll(() {
    registerFallbackValue(LDLogRecord(
        level: LDLogLevel.debug,
        message: '',
        time: DateTime.now(),
        logTag: ''));
  });

  test('a network error logs one warning', () {
    final adapter = _MockLogAdapter();
    fakeAsync((async) {
      final dataSource = PollingDataSource(
          credential: 'dummy-key',
          context: LDContextBuilder().kind('user', 'test').build(),
          endpoints: ServiceEndpoints(),
          logger: LDLogger(adapter: adapter, level: LDLogLevel.debug),
          dataSourceConfig: PollingDataSourceConfig(),
          httpProperties: HttpProperties(),
          testingInterval: _interval,
          httpClientFactory: (properties) => ld_common.HttpClient(
              client: MockClient(
                  (request) async => throw http.ClientException('reset')),
              httpProperties: properties));
      dataSource.events.listen((_) {});
      dataSource.start();
      async.flushMicrotasks();
      dataSource.stop();
    });

    final warnings = verify(() => adapter.log(captureAny()))
        .captured
        .cast<LDLogRecord>()
        .where((record) => record.level == LDLogLevel.warn);
    expect(warnings, hasLength(1));
    expect(warnings.single.message, contains('Will retry in'));
  });

  /// Polls once with a response of [status], and returns the error records.
  List<LDLogRecord> pollFailureErrors(int status) {
    final adapter = _MockLogAdapter();
    fakeAsync((async) {
      final dataSource = PollingDataSource(
          credential: 'dummy-key',
          context: LDContextBuilder().kind('user', 'test').build(),
          endpoints: ServiceEndpoints(),
          logger: LDLogger(adapter: adapter, level: LDLogLevel.debug),
          dataSourceConfig: PollingDataSourceConfig(),
          httpProperties: HttpProperties(),
          testingInterval: _interval,
          httpClientFactory: (properties) => ld_common.HttpClient(
              client: MockClient((request) async => http.Response('', status)),
              httpProperties: properties));
      dataSource.events.listen((_) {});
      dataSource.start();
      async.flushMicrotasks();
      dataSource.stop();
    });
    return verify(() => adapter.log(captureAny()))
        .captured
        .cast<LDLogRecord>()
        .where((record) => record.level == LDLogLevel.error)
        .toList();
  }

  for (final status in [401, 403]) {
    test('a $status logs an error with the hint', () {
      final errors = pollFailureErrors(status);
      expect(errors.single.message, contains(_credentialHint));
      expect(errors.single.message, contains('Will retry in'));
    });
  }

  test('a 404 logs an error without the hint', () {
    final errors = pollFailureErrors(404);
    expect(errors.single.message, isNot(contains('Check that')));
    expect(errors.single.message, contains('Will retry in'));
  });

  test('a 401 keeps polling after the extended initial delay', () {
    fakeAsync((async) {
      final harness = _Harness(async, [401, 200]);
      harness.dataSource.start();
      async.flushMicrotasks();

      expect(harness.requestTimes, hasLength(1));
      expect(harness.statuses.single.statusCode, 401);
      expect(harness.statuses.single.shutdown, isFalse);

      async.elapse(const Duration(minutes: 10));
      // The extended initial delay is 5 minutes, less up to half as jitter.
      expect(
          harness.waitBefore(1),
          allOf(greaterThanOrEqualTo(const Duration(seconds: 150)),
              lessThanOrEqualTo(const Duration(minutes: 5))));
    });
  });

  test('a success after a 401 restores the poll interval', () {
    fakeAsync((async) {
      final harness = _Harness(async, [401, 200, 200]);
      harness.dataSource.start();
      async.elapse(const Duration(minutes: 10));

      expect(harness.waitBefore(2), _oneInterval);
    });
  });

  test('a normal failure waits the poll interval', () {
    fakeAsync((async) {
      final harness = _Harness(async, [503]);
      harness.dataSource.start();
      async.flushMicrotasks();
      expect(harness.statuses.single.statusCode, 503);

      async.elapse(const Duration(minutes: 3));
      for (var i = 1; i < 5; i++) {
        expect(harness.waitBefore(i), _oneInterval);
      }
    });
  });

  test('one success after a 401 keeps the extended state', () {
    fakeAsync((async) {
      final harness = _Harness(async, [401, 200, 503, 200]);
      harness.dataSource.start();
      async.elapse(const Duration(minutes: 30));

      // The second extended attempt has a base delay of 10 minutes.
      expect(
          harness.waitBefore(3),
          allOf(greaterThanOrEqualTo(const Duration(minutes: 5)),
              lessThanOrEqualTo(const Duration(minutes: 10))));
    });
  });

  test('two successes in a row reset the state', () {
    fakeAsync((async) {
      final harness = _Harness(async, [401, 200, 200, 503, 200]);
      harness.dataSource.start();
      async.elapse(const Duration(minutes: 10));

      expect(harness.waitBefore(4), _oneInterval);
    });
  });

  test('the next poll waits one interval from when the previous poll ends',
      () async {
    const interval = Duration(milliseconds: 300);
    const responseTime = Duration(milliseconds: 200);
    final clock = Stopwatch()..start();
    final requestTimes = <Duration>[];
    final completionTimes = <Duration>[];
    final dataSource = PollingDataSource(
        credential: 'dummy-key',
        context: LDContextBuilder().kind('user', 'test').build(),
        endpoints: ServiceEndpoints(),
        logger: LDLogger(level: LDLogLevel.none),
        dataSourceConfig: PollingDataSourceConfig(),
        httpProperties: HttpProperties(),
        testingInterval: interval,
        httpClientFactory: (properties) => ld_common.HttpClient(
            client: MockClient((request) async {
              requestTimes.add(clock.elapsed);
              await Future<void>.delayed(responseTime);
              completionTimes.add(clock.elapsed);
              return http.Response('{}', 200);
            }),
            httpProperties: properties));
    dataSource.events.listen((_) {});

    dataSource.start();
    await Future<void>.delayed(const Duration(milliseconds: 900));
    dataSource.stop();

    expect(requestTimes.length, greaterThanOrEqualTo(2));
    // Allow for timer resolution, but stay well above the 100 ms that a
    // start-to-start cadence gives.
    expect(requestTimes[1] - completionTimes[0],
        greaterThanOrEqualTo(const Duration(milliseconds: 280)));
  });

  test('stop interrupts a pending wait', () {
    fakeAsync((async) {
      final harness = _Harness(async, [401]);
      harness.dataSource.start();
      async.flushMicrotasks();

      harness.dataSource.stop();
      expect(async.pendingTimers, isEmpty);

      async.elapse(const Duration(hours: 2));
      expect(harness.requestTimes, hasLength(1));
    });
  });

  test('no status is reported for a poll that ends after stop', () {
    fakeAsync((async) {
      final response = Completer<http.Response>();
      final events = <DataSourceEvent>[];
      final dataSource = PollingDataSource(
          credential: 'dummy-key',
          context: LDContextBuilder().kind('user', 'test').build(),
          endpoints: ServiceEndpoints(),
          logger: LDLogger(level: LDLogLevel.none),
          dataSourceConfig: PollingDataSourceConfig(),
          httpProperties: HttpProperties(),
          testingInterval: _interval,
          httpClientFactory: (properties) => ld_common.HttpClient(
              client: MockClient((request) => response.future),
              httpProperties: properties));
      dataSource.events.listen(events.add);

      dataSource.start();
      async.flushMicrotasks();
      dataSource.stop();
      response.complete(http.Response('', 401));
      async.flushMicrotasks();

      expect(events, isEmpty);
      expect(async.pendingTimers, isEmpty);
    });
  });
}
