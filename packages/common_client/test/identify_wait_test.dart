import 'dart:async';
import 'dart:convert';

import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:launchdarkly_common_client/launchdarkly_common_client.dart';
import 'package:launchdarkly_common_client/src/config/data_source_config.dart';
import 'package:launchdarkly_common_client/src/data_sources/data_source.dart';
import 'package:launchdarkly_common_client/src/data_sources/data_source_status.dart';
import 'package:launchdarkly_common_client/src/data_sources/polling_data_source.dart';
import 'package:launchdarkly_common_client/src/data_sources/streaming_data_source.dart';
import 'package:launchdarkly_common_client/src/persistence/persistence.dart'
    show encodePersistenceKey;
import 'package:launchdarkly_dart_common/launchdarkly_dart_common.dart'
    as ld_common;
import 'package:launchdarkly_event_source_client/launchdarkly_event_source_client.dart';
import 'package:test/test.dart';

import 'mock_persistence.dart';

final class _TestConfig extends LDCommonConfig {
  _TestConfig(super.sdkCredential, super.autoEnvAttributes,
      {super.dataSourceConfig});
}

const _step = Duration(milliseconds: 20);

String _payloadFor(String key) => '{"flagA":{"version":1,"value":"$key",'
    '"variation":0,"reason":{"kind":"OFF"}}}';

LDContext _user(String key) => LDContextBuilder().kind('user', key).build();

/// Reads the user key from a polling request. The context is the last path
/// segment, base64url encoded.
String _userKeyOf(http.Request request) {
  final encoded = request.url.pathSegments.last;
  final context = jsonDecode(utf8.decode(base64Url.decode(encoded)));
  return context['key'] as String;
}

/// Makes a client that polls every step. Each context gets the statuses in
/// [statusesByKey] in order, and the last status repeats. A 200 response
/// carries a flag whose value is the user key.
LDCommonClient _pollingClient(Map<String, List<int>> statusesByKey,
    {Persistence? persistence}) {
  final requestsByKey = <String, int>{};
  final httpClient = MockClient((request) async {
    final key = _userKeyOf(request);
    final statuses = statusesByKey[key] ?? const [200];
    final index = requestsByKey[key] ?? 0;
    requestsByKey[key] = index + 1;
    final status =
        statuses[index < statuses.length ? index : statuses.length - 1];
    return status == 200
        ? http.Response(_payloadFor(key), 200)
        : http.Response('', status);
  });
  return LDCommonClient(
      _TestConfig('the-sdk-key', AutoEnvAttributes.disabled,
          dataSourceConfig:
              DataSourceConfig(initialConnectionMode: ConnectionMode.polling)),
      CommonPlatform(persistence: persistence ?? MockPersistence()),
      _user('start'),
      DiagnosticSdkData(name: '', version: ''),
      dataSourceFactories: (config, logger, properties) {
    PollingDataSource polling(LDContext context) => PollingDataSource(
        credential: 'the-sdk-key',
        context: context,
        endpoints: ServiceEndpoints(),
        logger: logger,
        dataSourceConfig: PollingDataSourceConfig(),
        httpProperties: properties,
        testingInterval: _step,
        httpClientFactory: (props) =>
            ld_common.HttpClient(client: httpClient, httpProperties: props));
    return {
      ConnectionMode.streaming: polling,
      ConnectionMode.polling: polling,
    };
  });
}

/// A data source that sends [script] in order. Each entry waits for its
/// delay and then sends its event.
final class _ScriptedDataSource implements DataSource {
  final List<(Duration, DataSourceEvent)> script;
  final StreamController<DataSourceEvent> _controller = StreamController();
  final List<Timer> _timers = [];

  _ScriptedDataSource(this.script);

  @override
  Stream<DataSourceEvent> get events => _controller.stream;

  @override
  void restart({int? generation}) {}

  @override
  void start() {
    var at = Duration.zero;
    for (final (delay, event) in script) {
      at += delay;
      _timers.add(Timer(at, () {
        if (!_controller.isClosed) {
          _controller.add(event);
        }
      }));
    }
  }

  @override
  void stop() {
    for (final timer in _timers) {
      timer.cancel();
    }
    _controller.close();
  }
}

/// Waits until [condition] is true, or fails after a time limit.
Future<void> _eventually(bool Function() condition) async {
  final deadline = DateTime.now().add(const Duration(seconds: 2));
  while (!condition()) {
    if (DateTime.now().isAfter(deadline)) {
      fail('the condition did not become true');
    }
    await Future<void>.delayed(_step);
  }
}

void main() {
  test('a polling failure fails the identify, and then the flags recover',
      () async {
    final client = _pollingClient({
      'a': [503, 200],
    });
    expect(await client.start(), isTrue);

    expect(await client.identify(_user('a')), isA<IdentifyError>());

    // The data source keeps polling, so the flags and the status recover
    // without another identify.
    await _eventually(() => client.stringVariation('flagA', 'default') == 'a');
    await _eventually(
        () => client.dataSourceStatus.state == DataSourceState.valid);
    await client.close();
  });

  test('start returns false after a failure, and then the flags recover',
      () async {
    final client = _pollingClient({
      'start': [503, 200],
    });
    expect(await client.start(), isFalse);

    await _eventually(
        () => client.stringVariation('flagA', 'default') == 'start');
    await _eventually(
        () => client.dataSourceStatus.state == DataSourceState.valid);
    await client.close();
  });

  test('a 401 fails the identify, and later data updates the flags', () async {
    // A 401 makes the data source wait at least 2.5 minutes before it tries
    // again, so a scripted source stands in for the later data.
    final client = LDCommonClient(
        _TestConfig('the-sdk-key', AutoEnvAttributes.disabled),
        CommonPlatform(persistence: MockPersistence()),
        _user('b'),
        DiagnosticSdkData(name: '', version: ''),
        dataSourceFactories: (config, logger, properties) {
      DataSource source(LDContext context) => _ScriptedDataSource([
            (_step, StatusEvent(ErrorKind.errorResponse, 401, 'unauthorized')),
            (_step * 3, DataEvent('put', _payloadFor('b'))),
          ]);
      return {
        ConnectionMode.streaming: source,
        ConnectionMode.polling: source,
      };
    });
    expect(await client.start(), isFalse);

    await _eventually(() => client.stringVariation('flagA', 'default') == 'b');
    expect(client.dataSourceStatus.state, DataSourceState.valid);
    await client.close();
  });

  test(
      'a stream failure fails start, and then the reconnected stream updates '
      'the flags', () async {
    final sseClients = <TestSseClient>[];
    final client = LDCommonClient(
        _TestConfig('the-sdk-key', AutoEnvAttributes.disabled),
        CommonPlatform(persistence: MockPersistence()),
        _user('c'),
        DiagnosticSdkData(name: '', version: ''),
        dataSourceFactories: (config, logger, properties) {
      StreamingDataSource streaming(LDContext context) => StreamingDataSource(
          credential: 'the-sdk-key',
          context: context,
          endpoints: ServiceEndpoints(),
          logger: logger,
          dataSourceConfig: StreamingDataSourceConfig(),
          pollingDataSourceConfig: PollingDataSourceConfig(),
          httpProperties: properties,
          clientFactory: (uri, properties, body, method, logger) {
            final sse = SSEClient.testClient(uri, {});
            sseClients.add(sse);
            // The first connection fails. The next one sends data.
            if (sseClients.length == 1) {
              Timer(_step, () => sse.emitError(error: Exception('reset')));
            } else {
              Timer(
                  _step,
                  () => sse
                      .emitEvent(MessageEvent('put', _payloadFor('c'), null)));
            }
            return sse;
          });
      return {
        ConnectionMode.streaming: streaming,
        ConnectionMode.polling: streaming,
      };
    });
    expect(await client.start(), isFalse);

    // The data source reconnects after up to 1 second.
    await _eventually(() => client.stringVariation('flagA', 'default') == 'c');
    expect(sseClients, hasLength(2));
    expect(client.dataSourceStatus.state, DataSourceState.valid);
    await client.close();
  });

  group('a context with cached flags', () {
    /// A persistence that holds cached flags for [key]. The cached value of
    /// flagA is 'cached'.
    MockPersistence seeded(String key) => MockPersistence()
      ..storage['LaunchDarkly_${encodePersistenceKey('the-sdk-key')}'] = {
        encodePersistenceKey(key): _payloadFor('cached'),
      };

    /// Runs [body] in a zone, and returns the errors that reach the zone.
    Future<List<Object>> uncaughtErrors(Future<void> Function() body) async {
      final errors = <Object>[];
      final done = Completer<void>();
      runZonedGuarded(() {
        body().then(done.complete, onError: done.completeError);
      }, (error, stack) => errors.add(error));
      await done.future;
      return errors;
    }

    test(
        'a stream failure after the cache load reaches no zone, and then the '
        'stream recovers', () async {
      final errors = await uncaughtErrors(() async {
        final sseClients = <TestSseClient>[];
        final client = LDCommonClient(
            _TestConfig('the-sdk-key', AutoEnvAttributes.disabled),
            CommonPlatform(persistence: seeded('d')),
            _user('d'),
            DiagnosticSdkData(name: '', version: ''),
            dataSourceFactories: (config, logger, properties) {
          StreamingDataSource streaming(LDContext context) =>
              StreamingDataSource(
                  credential: 'the-sdk-key',
                  context: context,
                  endpoints: ServiceEndpoints(),
                  logger: logger,
                  dataSourceConfig: StreamingDataSourceConfig(),
                  pollingDataSourceConfig: PollingDataSourceConfig(),
                  httpProperties: properties,
                  clientFactory: (uri, properties, body, method, logger) {
                    final sse = SSEClient.testClient(uri, {});
                    sseClients.add(sse);
                    // The first connection fails before any payload. The
                    // next one sends data.
                    if (sseClients.length == 1) {
                      Timer(
                          _step,
                          () => sse.emitError(
                              error:
                                  SseHttpError(503, {}, recoverable: false)));
                    } else {
                      Timer(
                          _step,
                          () => sse.emitEvent(
                              MessageEvent('put', _payloadFor('d'), null)));
                    }
                    return sse;
                  });
          return {
            ConnectionMode.streaming: streaming,
            ConnectionMode.polling: streaming,
          };
        });

        expect(await client.start(), isTrue);
        expect(client.stringVariation('flagA', 'default'), 'cached');

        // A failure during initialization keeps the state at initializing,
        // and the status reports the error.
        await _eventually(
            () => client.dataSourceStatus.lastError?.statusCode == 503);

        await _eventually(
            () => client.stringVariation('flagA', 'default') == 'd');
        expect(client.dataSourceStatus.state, DataSourceState.valid);
        await client.close();
      });
      expect(errors, isEmpty);
    });

    test(
        'a polling failure after the cache load reaches no zone, and then '
        'polling recovers', () async {
      final errors = await uncaughtErrors(() async {
        final client = _pollingClient({
          'start': [503, 200],
        }, persistence: seeded('start'));

        expect(await client.start(), isTrue);
        expect(client.stringVariation('flagA', 'default'), 'cached');

        await _eventually(
            () => client.dataSourceStatus.lastError?.statusCode == 503);
        await _eventually(
            () => client.stringVariation('flagA', 'default') == 'start');
        expect(client.dataSourceStatus.state, DataSourceState.valid);
        await client.close();
      });
      expect(errors, isEmpty);
    });
  });
}
