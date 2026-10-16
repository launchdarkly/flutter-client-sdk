import 'dart:async';
import 'dart:math' as math;

import 'package:fake_async/fake_async.dart';
import 'package:launchdarkly_common_client/launchdarkly_common_client.dart';
import 'package:launchdarkly_common_client/src/config/data_source_config.dart';
import 'package:launchdarkly_common_client/src/data_sources/data_source_event_handler.dart';
import 'package:launchdarkly_common_client/src/data_sources/data_source_manager.dart';
import 'package:launchdarkly_common_client/src/data_sources/data_source_status_manager.dart';
import 'package:launchdarkly_common_client/src/data_sources/streaming_data_source.dart';
import 'package:launchdarkly_common_client/src/flag_manager/flag_manager.dart';
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

/// A persistence whose writes wait for [gate] and then fail.
final class _GatedFailingPersistence implements Persistence {
  final Completer<void> gate = Completer<void>();

  @override
  Future<String?> read(String namespace, String key) async => null;

  @override
  Future<void> remove(String namespace, String key) async {}

  @override
  Future<void> set(String namespace, String key, String data) async {
    await gate.future;
    throw StateError('write failed');
  }
}

/// Runs a streaming data source behind a real [DataSourceManager].
final class _Harness {
  final List<TestSseClient> clients = [];
  late final DataSourceManager manager;

  _Harness(FakeAsync async, {Persistence? persistence}) {
    final logger = LDLogger(level: LDLogLevel.none);
    final statusManager = DataSourceStatusManager();
    final flagManager = FlagManager(
        sdkKey: 'dummy-key',
        maxCachedContexts: 5,
        logger: logger,
        persistence: persistence);
    manager = DataSourceManager(
        statusManager: statusManager,
        dataSourceEventHandler: DataSourceEventHandler(
            flagManager: flagManager,
            statusManager: statusManager,
            logger: logger),
        logger: logger);
    manager.setFactories({
      const FDv2Streaming(): (context) => StreamingDataSource(
          credential: 'dummy-key',
          context: context,
          endpoints: ServiceEndpoints(),
          logger: logger,
          dataSourceConfig: StreamingDataSourceConfig(),
          pollingDataSourceConfig: PollingDataSourceConfig(),
          httpProperties: HttpProperties(),
          retryState: RetryState.streaming(
              random: _NoJitter(), clock: () => async.elapsed),
          clientFactory: (uri, properties, body, method, logger) {
            final client = SSEClient.testClient(uri, {});
            clients.add(client);
            return client;
          }),
    });
    manager.identify(LDContextBuilder().kind('user', 'test').build(),
        Completer<void>()..future.ignore());
  }
}

void main() {
  test('a late restart from a replaced connection is ignored', () {
    fakeAsync((async) {
      final persistence = _GatedFailingPersistence();
      final harness = _Harness(async, persistence: persistence);
      async.flushMicrotasks();
      expect(harness.clients, hasLength(1));

      // Connection 1 delivers a payload. Storing it waits on the gate.
      harness.clients[0].emitEvent(MessageEvent('put', '{}', null));
      async.flushMicrotasks();

      // Connection 1 fails, and connection 2 opens after 1 second.
      harness.clients[0].emitError(error: Exception('connection reset'));
      async.flushMicrotasks();
      async.elapse(const Duration(seconds: 1));
      expect(harness.clients, hasLength(2));

      // The payload from connection 1 now fails to store, which asks for a
      // restart.
      persistence.gate.complete();
      async.flushMicrotasks();

      expect(harness.clients[1].isClosed, isFalse);
      expect(harness.clients, hasLength(2));

      // Only one failure is recorded, so the next failure waits 2 seconds
      // and not 4.
      harness.clients[1].emitError(error: Exception('connection reset'));
      async.flushMicrotasks();
      async.elapse(const Duration(milliseconds: 1999));
      expect(harness.clients, hasLength(2));
      async.elapse(const Duration(milliseconds: 1));
      expect(harness.clients, hasLength(3));
      harness.manager.stop();
    });
  });

  test('a restart from the current connection restarts it', () {
    fakeAsync((async) {
      final harness = _Harness(async);
      async.flushMicrotasks();

      harness.clients[0].emitEvent(MessageEvent('put', 'not a payload', null));
      async.flushMicrotasks();

      expect(harness.clients[0].isClosed, isTrue);
      async.elapse(const Duration(seconds: 1));
      expect(harness.clients, hasLength(2));
      expect(harness.clients[1].isClosed, isFalse);
      harness.manager.stop();
    });
  });
}
