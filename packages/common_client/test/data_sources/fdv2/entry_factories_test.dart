import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:launchdarkly_common_client/src/config/service_endpoints.dart';
import 'package:launchdarkly_common_client/src/data_sources/fdv2/built_in_modes.dart';
import 'package:launchdarkly_common_client/src/data_sources/fdv2/cache_initializer.dart';
import 'package:launchdarkly_common_client/src/data_sources/fdv2/entry_factories.dart';
import 'package:launchdarkly_common_client/src/data_sources/fdv2/source_factory_context.dart';
import 'package:launchdarkly_common_client/src/data_sources/fdv2/mode_definition.dart'
    hide CacheInitializer;
import 'package:launchdarkly_common_client/src/data_sources/fdv2/payload.dart';
import 'package:launchdarkly_common_client/src/data_sources/fdv2/polling_synchronizer.dart';
import 'package:launchdarkly_common_client/src/data_sources/fdv2/streaming_synchronizer.dart';
import 'package:launchdarkly_common_client/src/data_sources/fdv2/selector.dart';
import 'package:launchdarkly_common_client/src/data_sources/fdv2/source_result.dart';
import 'package:launchdarkly_event_source_client/launchdarkly_event_source_client.dart';
import 'package:launchdarkly_dart_common/launchdarkly_dart_common.dart'
    hide ServiceEndpoints;
import 'package:test/test.dart';

LDContext _context() => LDContextBuilder().kind('user', 'test-key').build();

Selector _selectorGetter() => Selector.empty;

SourceFactoryContext _testContext({
  CachedFlagsReader? reader,
  Duration? defaultPollingInterval,
}) {
  return SourceFactoryContext.fromClientConfig(
    credential: 'test-credential',
    context: _context(),
    logger: LDLogger(level: LDLogLevel.error),
    httpProperties: HttpProperties(),
    serviceEndpoints: ServiceEndpoints.custom(polling: 'https://example.test'),
    withReasons: false,
    defaultPollingInterval:
        defaultPollingInterval ?? const Duration(seconds: 300),
    cachedFlagsReader: reader ?? ((_) async => null),
  );
}

void main() {
  group('mergeServiceEndpoints', () {
    test('returns base when override is null', () {
      final base = ServiceEndpoints.custom(
        polling: 'https://poll.example',
        streaming: 'https://stream.example',
      );
      expect(mergeServiceEndpoints(base, null), same(base));
    });

    test('overrides polling when entry provides pollingBaseUri', () {
      final base = ServiceEndpoints.custom(
        polling: 'https://poll.example',
        streaming: 'https://stream.example',
      );
      final merged = mergeServiceEndpoints(
        base,
        EndpointConfig(pollingBaseUri: Uri.parse('https://custom.poll/')),
      );
      expect(merged.polling, 'https://custom.poll/');
      expect(merged.streaming, base.streaming);
    });
  });

  group('buildInitializerFactories', () {
    test('offline mode is cache only', () {
      final ctx = _testContext();
      final list =
          buildInitializerFactories(BuiltInModes.offline.initializers, ctx);
      expect(list, hasLength(1));
      expect(list.single.isCache, isTrue);
      final init = list.single.create(_selectorGetter);
      expect(init, isA<CacheInitializer>());
    });

    test('polling mode initializer factories are cache only', () {
      final ctx = _testContext();
      final list =
          buildInitializerFactories(BuiltInModes.polling.initializers, ctx);
      expect(list, hasLength(1));
      expect(list.single.isCache, isTrue);
      expect(list.single.create(_selectorGetter), isA<CacheInitializer>());
    });

    test('polling mode synchronizer factories are polling', () {
      final ctx =
          _testContext(defaultPollingInterval: const Duration(seconds: 1));
      final list =
          buildSynchronizerFactories(BuiltInModes.polling.synchronizers, ctx);
      expect(list, hasLength(1));
      final sync = list.single.create(_selectorGetter);
      expect(sync, isA<FDv2PollingSynchronizer>());
      sync.close();
    });

    test('each create() returns a new initializer instance', () {
      final ctx = _testContext();
      final factory = buildInitializerFactories(
        BuiltInModes.offline.initializers,
        ctx,
      ).single;
      final a = factory.create(_selectorGetter);
      final b = factory.create(_selectorGetter);
      expect(identical(a, b), isFalse);
    });
  });

  group('createSynchronizerFactoryFromEntry', () {
    test('builds factory whose create returns FDv2PollingSynchronizer', () {
      final ctx =
          _testContext(defaultPollingInterval: const Duration(seconds: 1));
      final factory = createSynchronizerFactoryFromEntry(
        PollingSynchronizer(pollInterval: const Duration(seconds: 42)),
        ctx,
      );
      final sync = factory.create(_selectorGetter);
      expect(sync, isA<FDv2PollingSynchronizer>());
      sync.close();
    });

    test('builds factory whose create returns FDv2StreamingSynchronizer', () {
      final ctx = _testContext();
      final factory =
          createSynchronizerFactoryFromEntry(StreamingSynchronizer(), ctx);
      final sync = factory.create(_selectorGetter);
      expect(sync, isA<FDv2StreamingSynchronizer>());
      sync.close();
    });

    test(
        'streaming URI carries the auth query parameters and the current '
        'basis', () {
      final ctx = SourceFactoryContext(
        context: _context(),
        credential: 'the-client-side-id',
        authQueryParameters: const {'auth': 'the-client-side-id'},
        logger: LDLogger(level: LDLogLevel.error),
        httpProperties: HttpProperties(),
        serviceEndpoints: ServiceEndpoints.custom(
            polling: 'https://poll.test', streaming: 'https://stream.test'),
        contextJson: '{"key":"test","kind":"user"}',
        withReasons: false,
        defaultPollingInterval: const Duration(seconds: 300),
        cachedFlagsReader: (_) async => null,
      );

      var selector = Selector.empty;
      late Uri Function() capturedUriProvider;
      final factory = createSynchronizerFactoryFromEntry(
        StreamingSynchronizer(),
        ctx,
        sseClientFactory: ({
          required Uri Function() uriProvider,
          required HttpProperties httpProperties,
          required String? body,
          required SseHttpMethod method,
          required EventSourceLogger logger,
        }) {
          capturedUriProvider = uriProvider;
          return SSEClient.testClient(uriProvider(), const {});
        },
      );
      final sync = factory.create(() => selector);

      final initialUri = capturedUriProvider();
      expect(initialUri.host, equals('stream.test'));
      expect(initialUri.path, startsWith('/sdk/stream/eval/'));
      expect(initialUri.queryParameters['auth'], equals('the-client-side-id'));
      expect(initialUri.queryParameters.containsKey('basis'), isFalse);

      selector = const Selector(state: '(p:abc:1)', version: 1);
      final reconnectUri = capturedUriProvider();
      expect(
          reconnectUri.queryParameters['auth'], equals('the-client-side-id'));
      expect(reconnectUri.queryParameters['basis'], equals('(p:abc:1)'));

      sync.close();
    });
  });

  group('createInitializerFactoryFromEntry', () {
    test('streaming initializer is unsupported', () {
      final ctx = _testContext();
      expect(
        () => createInitializerFactoryFromEntry(StreamingInitializer(), ctx),
        throwsA(isA<UnsupportedError>()),
      );
    });

    test('polling request carries the auth query parameters', () async {
      late Uri capturedUri;
      final mock = MockClient((request) async {
        capturedUri = request.url;
        return http.Response('{"events":[]}', 200);
      });
      final ctx = SourceFactoryContext(
        context: _context(),
        credential: 'the-client-side-id',
        authQueryParameters: const {'auth': 'the-client-side-id'},
        logger: LDLogger(level: LDLogLevel.error),
        httpProperties: HttpProperties(),
        serviceEndpoints:
            ServiceEndpoints.custom(polling: 'https://example.test'),
        contextJson: '{"key":"test","kind":"user"}',
        withReasons: false,
        defaultPollingInterval: const Duration(seconds: 300),
        cachedFlagsReader: (_) async => null,
        httpClientFactory: (props) =>
            HttpClient(client: mock, httpProperties: props),
      );

      final factory =
          createInitializerFactoryFromEntry(PollingInitializer(), ctx);
      final init = factory.create(_selectorGetter);
      await init.run();

      expect(capturedUri.queryParameters,
          containsPair('auth', 'the-client-side-id'));
    });
  });

  test('cache initializer from factory.create runs with reader', () async {
    final ctx = _testContext(
      reader: (_) async => null,
    );
    final factory = buildInitializerFactories(
      BuiltInModes.offline.initializers,
      ctx,
    ).single;
    final init = factory.create(_selectorGetter) as CacheInitializer;
    final result = await init.run();
    expect(result, isA<ChangeSetResult>());
    final cs = result as ChangeSetResult;
    expect(cs.payload.type, PayloadType.none);
  });
}
