import 'dart:async';

import 'package:fake_async/fake_async.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:launchdarkly_common_client/launchdarkly_common_client.dart';
import 'package:launchdarkly_common_client/src/config/data_source_config.dart';
import 'package:launchdarkly_common_client/src/data_sources/data_source_event_handler.dart';
import 'package:launchdarkly_common_client/src/data_sources/data_source_manager.dart';
import 'package:launchdarkly_common_client/src/data_sources/data_source_status_manager.dart';
import 'package:launchdarkly_common_client/src/data_sources/polling_data_source.dart';
import 'package:launchdarkly_common_client/src/flag_manager/flag_manager.dart';
import 'package:launchdarkly_dart_common/launchdarkly_dart_common.dart'
    as ld_common;
import 'package:test/test.dart';

const _interval = Duration(seconds: 30);

const _flagPayload =
    '{"flag":{"version":2,"value":true,"variation":0,"trackEvents":false}}';

/// A persistence whose writes always fail.
final class _FailingPersistence implements Persistence {
  @override
  Future<String?> read(String namespace, String key) async => null;

  @override
  Future<void> remove(String namespace, String key) async {}

  @override
  Future<void> set(String namespace, String key, String data) async =>
      throw StateError('write failed');
}

/// Runs a data source behind a real [DataSourceManager], so that payloads go
/// through the event handler and invalid payloads cause a restart.
final class _Harness {
  final DataSourceStatusManager statusManager =
      DataSourceStatusManager(stamper: () => DateTime(1));
  final List<http.BaseRequest> requests = [];
  final List<Duration> requestTimes = [];
  late final FlagManager flagManager;
  late final DataSourceManager manager;
  final LDContext context = LDContextBuilder().kind('user', 'test').build();

  _Harness(FakeAsync async,
      FutureOr<http.Response> Function(int index, http.Request request) respond,
      {required ConnectionMode mode, Persistence? persistence}) {
    final logger = LDLogger(level: LDLogLevel.none);
    flagManager = FlagManager(
        sdkKey: 'dummy-key',
        maxCachedContexts: 5,
        logger: logger,
        persistence: persistence);
    manager = DataSourceManager(
        startingMode: mode,
        statusManager: statusManager,
        dataSourceEventHandler: DataSourceEventHandler(
            flagManager: flagManager,
            statusManager: statusManager,
            logger: logger),
        logger: logger);
    final client = MockClient((request) async {
      final index = requests.length;
      requests.add(request);
      requestTimes.add(async.elapsed);
      return await respond(index, request);
    });
    ld_common.HttpClient httpClientFactory(HttpProperties properties) =>
        ld_common.HttpClient(client: client, httpProperties: properties);
    manager.setFactories({
      const FDv2Polling(): (context) => PollingDataSource(
          credential: 'dummy-key',
          context: context,
          endpoints: ServiceEndpoints(),
          logger: logger,
          dataSourceConfig: PollingDataSourceConfig(),
          httpProperties: HttpProperties(),
          testingInterval: _interval,
          httpClientFactory: httpClientFactory),
    });
    manager.identify(context, Completer<void>()..future.ignore());
  }

  bool get flagValue =>
      flagManager.get('flag')?.flag?.detail.value.booleanValue() ?? false;

  /// The wait between request [index] and the request before it.
  Duration waitBefore(int index) =>
      requestTimes[index] - requestTimes[index - 1];
}

http.Response _ok(String body, String etag) =>
    http.Response(body, 200, headers: {'etag': etag});

bool _hasEtag(http.BaseRequest request) =>
    request.headers.containsKey('if-none-match');

void main() {
  group('polling', () {
    test('a retry after an unusable payload fetches fresh data', () {
      fakeAsync((async) {
        final harness =
            _Harness(async, mode: ConnectionMode.polling, (index, request) {
          if (index == 0) {
            return _ok('not a payload', '"e1"');
          }
          return _hasEtag(request)
              ? http.Response('', 304)
              : _ok(_flagPayload, '"e2"');
        });
        async.elapse(const Duration(minutes: 2));

        expect(harness.requests.length, greaterThanOrEqualTo(2));
        expect(_hasEtag(harness.requests[1]), isFalse);
        expect(harness.flagValue, isTrue);
        expect(harness.statusManager.status.state, DataSourceState.valid);
        harness.manager.stop();
      });
    });

    /// Responds to request `i` with `statuses[i]`. A status of 0 is a 200
    /// with a body that is not a flag payload.
    http.Response Function(int, http.Request) bySequence(List<int> statuses) =>
        (index, request) => switch (statuses[
                index < statuses.length ? index : statuses.length - 1]) {
              0 => _ok('not a payload', '"e$index"'),
              200 => _ok(_flagPayload, '"e$index"'),
              final status => http.Response('', status),
            };

    test('an unusable payload counts as a failure', () {
      fakeAsync((async) {
        final harness = _Harness(
            async, mode: ConnectionMode.polling, bySequence([401, 0, 200]));
        async.elapse(const Duration(minutes: 30));

        // The second extended attempt has a base delay of 10 minutes.
        expect(
            harness.waitBefore(2),
            allOf(greaterThanOrEqualTo(const Duration(minutes: 5)),
                lessThanOrEqualTo(const Duration(minutes: 10))));
        harness.manager.stop();
      });
    });

    test('an unusable payload does not count toward the reset', () {
      fakeAsync((async) {
        final harness = _Harness(
            async,
            mode: ConnectionMode.polling,
            bySequence([401, 200, 0, 200, 503, 200]));
        async.elapse(const Duration(hours: 2));

        // The third extended attempt has a base delay of 20 minutes.
        expect(
            harness.waitBefore(5),
            allOf(greaterThanOrEqualTo(const Duration(minutes: 10)),
                lessThanOrEqualTo(const Duration(minutes: 20))));
        harness.manager.stop();
      });
    });

    test('a payload that cannot be stored counts as a failure', () {
      fakeAsync((async) {
        final harness = _Harness(
            async,
            mode: ConnectionMode.polling,
            persistence: _FailingPersistence(),
            (index, request) => index == 0
                ? http.Response('', 401)
                : _ok(_flagPayload, '"e$index"'));
        async.elapse(const Duration(minutes: 30));

        // The second extended attempt has a base delay of 10 minutes.
        expect(
            harness.waitBefore(2),
            allOf(greaterThanOrEqualTo(const Duration(minutes: 5)),
                lessThanOrEqualTo(const Duration(minutes: 10))));
        harness.manager.stop();
      });
    });

    test('a 304 after a failure restores the valid status', () {
      fakeAsync((async) {
        final harness =
            _Harness(async, mode: ConnectionMode.polling, (index, request) {
          return switch (index) {
            0 => _ok(_flagPayload, '"e1"'),
            1 => http.Response('', 503),
            _ => http.Response('', 304),
          };
        });
        async.flushMicrotasks();
        expect(harness.statusManager.status.state, DataSourceState.valid);

        async.elapse(_interval);
        expect(harness.statusManager.status.state, DataSourceState.interrupted);

        async.elapse(_interval);
        expect(harness.requests, hasLength(3));
        expect(harness.statusManager.status.state, DataSourceState.valid);
        expect(harness.flagValue, isTrue);
        harness.manager.stop();
      });
    });
  });
}
