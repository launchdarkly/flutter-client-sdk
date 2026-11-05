@TestOn('browser')
library;

import 'package:launchdarkly_common_client/launchdarkly_common_client.dart';
import 'package:launchdarkly_common_client/src/config/data_source_config.dart';
import 'package:launchdarkly_common_client/src/data_sources/data_source_status_manager.dart';
import 'package:launchdarkly_common_client/src/data_sources/fdv2/data_system.dart';
import 'package:launchdarkly_common_client/src/data_sources/fdv2/entry_factories.dart';
import 'package:launchdarkly_common_client/src/data_sources/fdv2/selector.dart';
import 'package:launchdarkly_common_client/src/data_sources/fdv2/source_factory_context.dart';
import 'package:launchdarkly_common_client/src/data_sources/streaming_client.dart';
import 'package:launchdarkly_common_client/src/data_sources/streaming_data_source.dart';
import 'package:launchdarkly_event_source_client/launchdarkly_event_source_client.dart';
import 'package:mocktail/mocktail.dart';
import 'package:test/test.dart';

class MockLogAdapter extends Mock implements LDLogAdapter {}

// These tests cover the decisions the SDK makes only on web. Run them with
// `dart test test/data_sources/streaming_client_web_test.dart -p chrome`.

typedef _Call = ({
  Uri uri,
  Map<String, String> headers,
  String? body,
  SseHttpMethod method
});

/// A builder that records its arguments and returns a test client.
SseClientBuilder _recording(List<_Call> calls) => (uri, eventTypes,
        {required headers,
        required body,
        required httpMethod,
        required logger,
        uriProvider}) {
      calls.add((uri: uri, headers: headers, body: body, method: httpMethod));
      return SSEClient.testClient(uri, eventTypes);
    };

void main() {
  setUpAll(() {
    registerFallbackValue(LDLogRecord(
        level: LDLogLevel.debug,
        message: '',
        time: DateTime.now(),
        logTag: ''));
  });

  group('streamingRequestHeaders', () {
    test('removes the tags header and keeps the others', () {
      final properties = HttpProperties(baseHeaders: {
        'X-LaunchDarkly-Tags': 'application-id/app',
        'x-launchdarkly-user-agent': 'agent',
      });

      final headers = streamingRequestHeaders(properties);

      expect(headers, equals({'x-launchdarkly-user-agent': 'agent'}));
      expect(() => headers['a'] = 'b', throwsUnsupportedError);
    });

    test('matches the tags header without regard to case', () {
      final properties =
          HttpProperties(baseHeaders: {'x-launchdarkly-tags': 'a/b'});

      expect(streamingRequestHeaders(properties), isEmpty);
    });
  });

  group('sseClientBuilderFor', () {
    test('selects the browser EventSource without the option', () {
      expect(sseClientBuilderFor(useHttpStreamingOnWeb: false), SSEClient.new);
    });

    test('selects the HTTP client with the option', () {
      expect(sseClientBuilderFor(useHttpStreamingOnWeb: true), SSEClient.http);
    });
  });

  group('streamingCustomMethodSupported', () {
    test('is false for the browser EventSource', () {
      expect(streamingCustomMethodSupported(useHttpStreamingOnWeb: false),
          isFalse);
    });

    test('is true with the HTTP client', () {
      expect(
          streamingCustomMethodSupported(useHttpStreamingOnWeb: true), isTrue);
    });
  });

  group('FDv2 with usePost', () {
    FDv2DataSystem makeDataSystem({bool useHttpStreamingOnWeb = false}) =>
        FDv2DataSystem(
          config: const DataSystemConfig(usePost: true),
          credential: 'the-credential',
          logger: LDLogger(level: LDLogLevel.none),
          httpProperties: HttpProperties(),
          serviceEndpoints: ServiceEndpoints(),
          withReasons: false,
          defaultPollingInterval: const Duration(seconds: 300),
          statusManager: DataSourceStatusManager(),
          cachedFlagsReader: (_) async => null,
          useHttpStreamingOnWeb: useHttpStreamingOnWeb,
        );

    test(
        'the browser EventSource cannot POST, so the streaming entries are '
        'dropped', () {
      final definition =
          makeDataSystem().resolvedDefinition(ConnectionModeId.streaming);

      expect(
          definition.synchronizers.whereType<StreamingSynchronizer>(), isEmpty);
    });

    test('the HTTP client keeps the streaming entries', () {
      final definition = makeDataSystem(useHttpStreamingOnWeb: true)
          .resolvedDefinition(ConnectionModeId.streaming);

      expect(definition.synchronizers.whereType<StreamingSynchronizer>(),
          isNotEmpty);
    });
  });

  group('FDv2 streaming headers', () {
    test('the stream drops the tags header and keeps the others', () {
      final calls = <_Call>[];
      final ctx = SourceFactoryContext.fromClientConfig(
        credential: 'the-credential',
        context: LDContextBuilder().kind('user', 'test').build(),
        logger: LDLogger(level: LDLogLevel.none),
        httpProperties: HttpProperties(baseHeaders: {
          'X-LaunchDarkly-Tags': 'a/b',
          'x-launchdarkly-user-agent': 'ua',
        }),
        serviceEndpoints: ServiceEndpoints(),
        withReasons: false,
        usePost: false,
        defaultPollingInterval: const Duration(seconds: 300),
        cachedFlagsReader: (_) async => null,
      );

      createSynchronizerFactoryFromEntry(StreamingSynchronizer(), ctx,
              sseClientBuilder: _recording(calls))
          .create(() => Selector.empty)
          .close();

      expect(calls.single.headers, isNot(contains('X-LaunchDarkly-Tags')));
      expect(calls.single.headers,
          containsPair('x-launchdarkly-user-agent', 'ua'));
    });
  });

  group('FDv1 with useReport', () {
    StreamingDataSource makeDataSource(List<_Call> calls,
            {bool useHttpStreamingOnWeb = false, LDLogger? logger}) =>
        StreamingDataSource(
            credential: 'the-credential',
            context: LDContextBuilder().kind('user', 'test').build(),
            endpoints: ServiceEndpoints(),
            logger: logger ?? LDLogger(level: LDLogLevel.none),
            dataSourceConfig: StreamingDataSourceConfig(useReport: true),
            pollingDataSourceConfig: PollingDataSourceConfig(useReport: true),
            httpProperties: HttpProperties(baseHeaders: {
              'X-LaunchDarkly-Tags': 'a/b',
              'x-launchdarkly-user-agent': 'ua',
            }),
            useHttpStreamingOnWeb: useHttpStreamingOnWeb,
            clientBuilder: _recording(calls));

    test('warns once when the stream falls back to GET', () {
      final adapter = MockLogAdapter();
      when(() => adapter.log(any())).thenReturn(null);

      makeDataSource(<_Call>[],
          logger: LDLogger(adapter: adapter, level: LDLogLevel.warn));

      final records =
          verify(() => adapter.log(captureAny())).captured.cast<LDLogRecord>();
      expect(records, hasLength(1));
      expect(records.single.level, LDLogLevel.warn);
      expect(records.single.message, contains('REPORT'));
    });

    test('does not warn with the HTTP client', () {
      final adapter = MockLogAdapter();
      when(() => adapter.log(any())).thenReturn(null);

      makeDataSource(<_Call>[],
          useHttpStreamingOnWeb: true,
          logger: LDLogger(adapter: adapter, level: LDLogLevel.debug));

      verifyNever(() => adapter.log(any()));
    });

    test('the browser EventSource streams with GET and the context in the URI',
        () {
      final calls = <_Call>[];
      final dataSource = makeDataSource(calls);

      dataSource.start();

      expect(calls.single.method, SseHttpMethod.get);
      expect(calls.single.body, isNull);
      expect(calls.single.uri.path, startsWith('/eval/the-credential/'));
      expect(calls.single.headers, isNot(contains('X-LaunchDarkly-Tags')));
      expect(calls.single.headers,
          containsPair('x-launchdarkly-user-agent', 'ua'));
      dataSource.stop();
    });

    test('the HTTP client streams with REPORT and the context in the body', () {
      final calls = <_Call>[];
      final dataSource = makeDataSource(calls, useHttpStreamingOnWeb: true);

      dataSource.start();

      expect(calls.single.method, SseHttpMethod.report);
      expect(calls.single.body, '{"key":"test","kind":"user"}');
      expect(calls.single.uri.path, '/eval/the-credential');
      expect(calls.single.headers, isNot(contains('X-LaunchDarkly-Tags')));
      expect(calls.single.headers,
          containsPair('x-launchdarkly-user-agent', 'ua'));
      dataSource.stop();
    });
  });
}
