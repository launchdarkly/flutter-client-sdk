import 'dart:math' as math;

import 'package:fake_async/fake_async.dart';
import 'package:launchdarkly_common_client/launchdarkly_common_client.dart';
import 'package:launchdarkly_common_client/src/config/data_source_config.dart';
import 'package:launchdarkly_common_client/src/data_sources/streaming_data_source.dart';
import 'package:launchdarkly_dart_common/launchdarkly_dart_common.dart'
    show RetryState;
import 'package:launchdarkly_event_source_client/launchdarkly_event_source_client.dart';
import 'package:test/test.dart';

/// A random source that removes no jitter.
final class _NoJitter implements math.Random {
  @override
  double nextDouble() => 0;

  @override
  bool nextBool() => false;

  @override
  int nextInt(int max) => 0;
}

(StreamingDataSource, List<TestSseClient>) _makeDataSource(FakeAsync async) {
  final clients = <TestSseClient>[];
  final dataSource = StreamingDataSource(
      credential: 'dummy-key',
      context: LDContextBuilder().kind('user', 'test').build(),
      endpoints: ServiceEndpoints(),
      logger: LDLogger(level: LDLogLevel.none),
      dataSourceConfig: StreamingDataSourceConfig(),
      pollingDataSourceConfig: PollingDataSourceConfig(),
      httpProperties: HttpProperties(),
      retryState:
          RetryState.streaming(random: _NoJitter(), clock: () => async.elapsed),
      clientFactory: (uri, properties, body, method, logger) {
        final client = SSEClient.testClient(uri, {});
        clients.add(client);
        return client;
      });
  dataSource.events.listen((_) {});
  return (dataSource, clients);
}

/// Fails the first stream with a 401, then opens a second stream that
/// receives a payload.
void _failThenReceive(FakeAsync async, List<TestSseClient> clients) {
  clients[0].emitError(error: SseHttpError(401, {}, recoverable: false));
  async.flushMicrotasks();
  async.elapse(const Duration(minutes: 5));
  expect(clients, hasLength(2));
  clients[1].emitEvent(MessageEvent('put', '{}', null));
  async.flushMicrotasks();
}

void main() {
  test('60 seconds of healthy streaming resets the retry state', () {
    fakeAsync((async) {
      final (dataSource, clients) = _makeDataSource(async);
      dataSource.start();
      async.flushMicrotasks();
      _failThenReceive(async, clients);

      async.elapse(const Duration(seconds: 60));
      clients[1].emitError(error: Exception('connection reset'));
      async.flushMicrotasks();

      async.elapse(const Duration(seconds: 1));
      expect(clients, hasLength(3));
    });
  });

  test('a stream that fails before 60 seconds keeps the retry state', () {
    fakeAsync((async) {
      final (dataSource, clients) = _makeDataSource(async);
      dataSource.start();
      async.flushMicrotasks();
      _failThenReceive(async, clients);

      async.elapse(const Duration(seconds: 59));
      clients[1].emitError(error: Exception('connection reset'));
      async.flushMicrotasks();

      async.elapse(const Duration(minutes: 9));
      expect(clients, hasLength(2));
      async.elapse(const Duration(minutes: 1));
      expect(clients, hasLength(3));
    });
  });

  test('a stream with no payload does not count as healthy', () {
    fakeAsync((async) {
      final (dataSource, clients) = _makeDataSource(async);
      dataSource.start();
      async.flushMicrotasks();
      clients[0].emitError(error: SseHttpError(401, {}, recoverable: false));
      async.flushMicrotasks();
      async.elapse(const Duration(minutes: 5));

      async.elapse(const Duration(minutes: 2));
      clients[1].emitError(error: Exception('connection reset'));
      async.flushMicrotasks();

      async.elapse(const Duration(minutes: 9));
      expect(clients, hasLength(2));
    });
  });
}
