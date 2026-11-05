@TestOn('browser')
library;

import 'dart:async';

import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:launchdarkly_common_client/launchdarkly_common_client.dart';
import 'package:launchdarkly_common_client/src/config/data_source_config.dart';
import 'package:launchdarkly_common_client/src/data_sources/data_source_status_manager.dart';
import 'package:launchdarkly_common_client/src/data_sources/fdv2/data_system.dart';
import 'package:launchdarkly_common_client/src/data_sources/streaming_client.dart';
import 'package:launchdarkly_common_client/src/data_sources/streaming_data_source.dart';
import 'package:launchdarkly_dart_common/launchdarkly_dart_common.dart'
    as ld_common;
import 'package:launchdarkly_event_source_client/launchdarkly_event_source_client.dart';
import 'package:test/test.dart';

// These tests cover the decisions the SDK makes only on web. Run them with
// `dart test test/data_sources/streaming_client_web_test.dart -p chrome`.

typedef _Call = ({
  Uri uri,
  Map<String, String> headers,
  String? body,
  SseHttpMethod method
});

/// A builder that records its arguments and returns a test client. Events
/// on [source] reach the data source through the client.
SseClientBuilder _recording(List<_Call> calls, {Stream<Event>? source}) =>
    (uri, eventTypes,
        {required headers,
        required body,
        required httpMethod,
        required logger,
        required uriProvider}) {
      calls.add((uri: uri, headers: headers, body: body, method: httpMethod));
      return SSEClient.testClient(uri, eventTypes, sourceStream: source);
    };

void main() {
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

  group('FDv1 with useReport', () {
    StreamingDataSource makeDataSource(List<_Call> calls,
            {bool useHttpStreamingOnWeb = false,
            Stream<Event>? source,
            MockClient? httpClient}) =>
        StreamingDataSource(
            credential: 'the-credential',
            context: LDContextBuilder().kind('user', 'test').build(),
            endpoints: ServiceEndpoints(),
            logger: LDLogger(level: LDLogLevel.none),
            dataSourceConfig: StreamingDataSourceConfig(useReport: true),
            pollingDataSourceConfig: PollingDataSourceConfig(useReport: true),
            httpProperties:
                HttpProperties(baseHeaders: {'X-LaunchDarkly-Tags': 'a/b'}),
            useHttpStreamingOnWeb: useHttpStreamingOnWeb,
            clientBuilder: _recording(calls, source: source),
            httpClientFactory: httpClient == null
                ? null
                : (properties) => ld_common.HttpClient(
                    client: httpClient, httpProperties: properties));

    test('the browser EventSource streams with GET and the context in the URI',
        () {
      final calls = <_Call>[];
      final dataSource = makeDataSource(calls);

      dataSource.start();

      expect(calls.single.method, SseHttpMethod.get);
      expect(calls.single.body, isNull);
      expect(calls.single.uri.path, startsWith('/eval/the-credential/'));
      expect(calls.single.headers, isNot(contains('X-LaunchDarkly-Tags')));
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
      dataSource.stop();
    });

    test('a ping poll keeps REPORT when the stream falls back to GET',
        () async {
      // A GET on the REPORT polling path would carry no context.
      final pollRequests = <http.Request>[];
      final httpClient = MockClient((request) async {
        pollRequests.add(request);
        return http.Response('{}', 200);
      });
      final source = StreamController<Event>();
      final calls = <_Call>[];
      final dataSource =
          makeDataSource(calls, source: source.stream, httpClient: httpClient);

      dataSource.start();
      source.add(const MessageEvent('ping', '', null));
      await Future<void>.delayed(const Duration(milliseconds: 50));

      expect(calls.single.method, SseHttpMethod.get);
      expect(pollRequests, hasLength(1));
      expect(pollRequests.single.method, 'REPORT');
      expect(pollRequests.single.url.path, '/sdk/evalx/the-credential/context');
      expect(pollRequests.single.body, '{"key":"test","kind":"user"}');
      dataSource.stop();
      await source.close();
    });
  });
}
