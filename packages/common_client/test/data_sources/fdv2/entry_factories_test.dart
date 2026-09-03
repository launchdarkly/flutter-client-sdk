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
  bool usePost = false,
}) {
  return SourceFactoryContext.fromClientConfig(
    credential: 'test-credential',
    context: _context(),
    logger: LDLogger(level: LDLogLevel.error),
    httpProperties: HttpProperties(),
    serviceEndpoints: ServiceEndpoints.custom(polling: 'https://example.test'),
    withReasons: false,
    usePost: usePost,
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
        additionalQueryParameters: const {'auth': 'the-client-side-id'},
        logger: LDLogger(level: LDLogLevel.error),
        httpProperties: HttpProperties(),
        serviceEndpoints: ServiceEndpoints.custom(
            polling: 'https://poll.test', streaming: 'https://stream.test'),
        contextJson: '{"key":"test","kind":"user"}',
        withReasons: false,
        usePost: false,
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

    test(
        'streaming URI preserves repeated query keys on the base URL across '
        'reconnects', () {
      final ctx = SourceFactoryContext(
        context: _context(),
        credential: 'cid',
        logger: LDLogger(level: LDLogLevel.error),
        httpProperties: HttpProperties(),
        serviceEndpoints: ServiceEndpoints.custom(
            polling: 'https://poll.test',
            streaming: 'https://relay.test/?tag=a&tag=b'),
        contextJson: '{"key":"test","kind":"user"}',
        withReasons: false,
        usePost: false,
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

      // A relay-style base URL with a repeated key must round-trip both
      // values, matching the polling requestor -- and on every reconnect,
      // since the provider rebuilds the URI each time.
      expect(
          capturedUriProvider().queryParametersAll['tag'], equals(['a', 'b']));
      selector = const Selector(state: '(p:abc:1)', version: 1);
      expect(
          capturedUriProvider().queryParametersAll['tag'], equals(['a', 'b']));

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
        additionalQueryParameters: const {'auth': 'the-client-side-id'},
        logger: LDLogger(level: LDLogLevel.error),
        httpProperties: HttpProperties(),
        serviceEndpoints:
            ServiceEndpoints.custom(polling: 'https://example.test'),
        contextJson: '{"key":"test","kind":"user"}',
        withReasons: false,
        usePost: false,
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
    expect(cs.changeSet.type, PayloadType.none);
  });

  group('usePost', () {
    SourceFactoryContext factoryContext(
        {required bool usePost, http.Client? mock}) {
      return SourceFactoryContext(
        context: _context(),
        credential: 'the-credential',
        logger: LDLogger(level: LDLogLevel.error),
        httpProperties: HttpProperties(),
        serviceEndpoints: ServiceEndpoints.custom(
            polling: 'https://poll.test', streaming: 'https://stream.test'),
        contextJson: '{"key":"test","kind":"user"}',
        withReasons: false,
        usePost: usePost,
        defaultPollingInterval: const Duration(seconds: 300),
        cachedFlagsReader: (_) async => null,
        httpClientFactory: mock == null
            ? null
            : (props) => HttpClient(client: mock, httpProperties: props),
      );
    }

    Future<http.Request> pollOnce({required bool usePost}) async {
      late http.Request captured;
      final mock = MockClient((request) async {
        captured = request;
        return http.Response('{"events":[]}', 200);
      });
      final init = createInitializerFactoryFromEntry(PollingInitializer(),
              factoryContext(usePost: usePost, mock: mock))
          .create(_selectorGetter);
      await init.run();
      return captured;
    }

    test('the polling request sends POST with the context in the body',
        () async {
      final request = await pollOnce(usePost: true);

      expect(request.method, equals('POST'));
      expect(request.url.path, equals('/sdk/poll/eval'));
      expect(request.body, equals('{"key":"test","kind":"user"}'));
      expect(request.headers['content-type'], startsWith('application/json'));
    });

    test(
        'the polling request sends GET with the context in the path by default',
        () async {
      final request = await pollOnce(usePost: false);

      expect(request.method, equals('GET'));
      expect(request.url.path, startsWith('/sdk/poll/eval/'));
      expect(request.body, isEmpty);
    });

    ({SseHttpMethod method, String? body, Uri uri}) connectStream(
        {required bool usePost}) {
      late SseHttpMethod capturedMethod;
      String? capturedBody;
      late Uri Function() capturedUriProvider;
      final factory = createSynchronizerFactoryFromEntry(
        StreamingSynchronizer(),
        factoryContext(usePost: usePost),
        sseClientFactory: ({
          required Uri Function() uriProvider,
          required HttpProperties httpProperties,
          required String? body,
          required SseHttpMethod method,
          required EventSourceLogger logger,
        }) {
          capturedMethod = method;
          capturedBody = body;
          capturedUriProvider = uriProvider;
          return SSEClient.testClient(uriProvider(), const {});
        },
      );
      factory.create(_selectorGetter).close();
      return (
        method: capturedMethod,
        body: capturedBody,
        uri: capturedUriProvider()
      );
    }

    test('the streaming connection uses POST with the context as the body', () {
      final connection = connectStream(usePost: true);

      expect(connection.method, equals(SseHttpMethod.post));
      expect(connection.body, equals('{"key":"test","kind":"user"}'));
      expect(connection.uri.path, equals('/sdk/stream/eval'));
    });

    test(
        'the streaming connection uses GET with the context in the path by default',
        () {
      final connection = connectStream(usePost: false);

      expect(connection.method, equals(SseHttpMethod.get));
      expect(connection.body, isNull);
      expect(connection.uri.path, startsWith('/sdk/stream/eval/'));
    });
  });
}
