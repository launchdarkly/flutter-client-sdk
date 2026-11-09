@TestOn('browser')
library;

import 'dart:async';
import 'dart:collection';

import 'package:launchdarkly_common_client/launchdarkly_common_client.dart';
import 'package:launchdarkly_common_client/src/config/data_source_config.dart';
import 'package:launchdarkly_common_client/src/data_sources/data_source.dart';
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

/// A client that replays a scripted event stream.
class _ScriptedClient implements SSEClient {
  @override
  final Stream<Event> stream;

  _ScriptedClient(this.stream);

  @override
  Future<void> close() async {}

  @override
  void restart() {}

  @override
  bool hasCapability(SSECapability capability) => true;
}

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

  group('streamingCustomMethodSupported', () {
    test('is false for the default client, the browser EventSource', () {
      expect(streamingCustomMethodSupported(eventSource: null), isFalse);
    });

    test('is false for an explicit SSEClient.new, which is the same client',
        () {
      expect(
          streamingCustomMethodSupported(eventSource: SSEClient.new), isFalse);
    });

    test('is true with a supplied builder', () {
      expect(
          streamingCustomMethodSupported(eventSource: SSEClient.http), isTrue);
    });
  });

  group('FDv2 with usePost', () {
    FDv2DataSystem makeDataSystem({SseClientBuilder? eventSource}) =>
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
          eventSource: eventSource,
        );

    test(
        'the browser EventSource cannot POST, so the streaming entries are '
        'dropped', () {
      final definition =
          makeDataSystem().resolvedDefinition(ConnectionModeId.streaming);

      expect(
          definition.synchronizers.whereType<StreamingSynchronizer>(), isEmpty);
    });

    test('an explicit SSEClient.new also drops the streaming entries', () {
      final definition = makeDataSystem(eventSource: SSEClient.new)
          .resolvedDefinition(ConnectionModeId.streaming);

      expect(
          definition.synchronizers.whereType<StreamingSynchronizer>(), isEmpty);
    });

    test('a supplied client keeps the streaming entries', () {
      final definition = makeDataSystem(eventSource: SSEClient.http)
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
    // The recording builder stands in for the default client when
    // [streamingReportSupported] is false, and for a supplied client when it
    // is null.
    StreamingDataSource makeDataSource(List<_Call> calls,
            {bool? streamingReportSupported, LDLogger? logger}) =>
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
            eventSource: _recording(calls),
            streamingReportSupported: streamingReportSupported);

    test('warns once when the stream falls back to GET', () {
      final adapter = MockLogAdapter();
      when(() => adapter.log(any())).thenReturn(null);

      makeDataSource(<_Call>[],
          streamingReportSupported: false,
          logger: LDLogger(adapter: adapter, level: LDLogLevel.warn));

      final records =
          verify(() => adapter.log(captureAny())).captured.cast<LDLogRecord>();
      expect(records, hasLength(1));
      expect(records.single.level, LDLogLevel.warn);
      expect(records.single.message, contains('REPORT'));
    });

    test('warns when an explicit SSEClient.new falls back to GET', () {
      final adapter = MockLogAdapter();
      when(() => adapter.log(any())).thenReturn(null);

      // The data source is not started, so no browser EventSource opens.
      StreamingDataSource(
          credential: 'the-credential',
          context: LDContextBuilder().kind('user', 'test').build(),
          endpoints: ServiceEndpoints(),
          logger: LDLogger(adapter: adapter, level: LDLogLevel.warn),
          dataSourceConfig: StreamingDataSourceConfig(useReport: true),
          pollingDataSourceConfig: PollingDataSourceConfig(useReport: true),
          httpProperties: HttpProperties(),
          eventSource: SSEClient.new);

      final records =
          verify(() => adapter.log(captureAny())).captured.cast<LDLogRecord>();
      expect(records.single.message, contains('REPORT'));
    });

    test('does not warn with a supplied client', () {
      final adapter = MockLogAdapter();
      when(() => adapter.log(any())).thenReturn(null);

      makeDataSource(<_Call>[],
          logger: LDLogger(adapter: adapter, level: LDLogLevel.debug));

      verifyNever(() => adapter.log(any()));
    });

    test('the default client streams with GET and the context in the URI', () {
      final calls = <_Call>[];
      final dataSource = makeDataSource(calls, streamingReportSupported: false);

      dataSource.start();

      expect(calls.single.method, SseHttpMethod.get);
      expect(calls.single.body, isNull);
      expect(calls.single.uri.path, startsWith('/eval/the-credential/'));
      expect(calls.single.headers, isNot(contains('X-LaunchDarkly-Tags')));
      expect(calls.single.headers,
          containsPair('x-launchdarkly-user-agent', 'ua'));
      dataSource.stop();
    });

    test('a supplied client streams with REPORT and the context in the body',
        () {
      final calls = <_Call>[];
      final dataSource = makeDataSource(calls);

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

  group('FDv1 environment ID', () {
    test(
        'falls back to the client-side ID when the connection headers lack '
        'the environment ID header', () async {
      final events = StreamController<Event>();
      final dataSource = StreamingDataSource(
          credential: 'the-credential',
          context: LDContextBuilder().kind('user', 'test').build(),
          endpoints: ServiceEndpoints(),
          logger: LDLogger(level: LDLogLevel.none),
          dataSourceConfig: StreamingDataSourceConfig(),
          pollingDataSourceConfig: PollingDataSourceConfig(),
          httpProperties: HttpProperties(),
          eventSource: (uri, eventTypes,
                  {required headers,
                  required body,
                  required httpMethod,
                  required logger,
                  uriProvider}) =>
              _ScriptedClient(events.stream));
      final firstData =
          dataSource.events.firstWhere((event) => event is DataEvent);

      dataSource.start();
      // The browser exposes only the headers the CORS policy allows.
      events.sink.add(OpenEvent(
          headers: UnmodifiableMapView({'content-type': 'text/event-stream'})));
      events.sink.add(MessageEvent('put', '{}', null));

      expect((await firstData as DataEvent).environmentId, 'the-credential');
      dataSource.stop();
      await events.close();
    });
  });
}
