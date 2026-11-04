@TestOn('browser')
library;

import 'package:launchdarkly_common_client/launchdarkly_common_client.dart';
import 'package:launchdarkly_common_client/src/config/data_source_config.dart';
import 'package:launchdarkly_common_client/src/data_sources/data_source_status_manager.dart';
import 'package:launchdarkly_common_client/src/data_sources/fdv2/data_system.dart';
import 'package:launchdarkly_common_client/src/data_sources/sse_client_factory.dart';
import 'package:launchdarkly_common_client/src/data_sources/streaming_data_source.dart';
import 'package:test/test.dart';

// These tests cover the decisions the SDK makes only on web. Run them with
// `dart test test/data_sources/sse_client_factory_web_test.dart -p chrome`.

/// A client with every capability, like `SSEClient.http`.
SSEClient _httpCapableClient(SSEClientRequest request) =>
    SSEClient.testClient(request.uriProvider(), request.eventTypes);

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

  group('FDv2 with usePost', () {
    FDv2DataSystem makeDataSystem({SSEClientFactory? factory}) =>
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
          sseClientFactory: factory,
        );

    test('the default client cannot POST, so the streaming entries are dropped',
        () {
      final definition =
          makeDataSystem().resolvedDefinition(ConnectionModeId.streaming);

      expect(
          definition.synchronizers.whereType<StreamingSynchronizer>(), isEmpty);
    });

    test('a custom client keeps the streaming entries', () {
      final definition = makeDataSystem(factory: _httpCapableClient)
          .resolvedDefinition(ConnectionModeId.streaming);

      expect(definition.synchronizers.whereType<StreamingSynchronizer>(),
          isNotEmpty);
    });
  });

  group('FDv1 with useReport', () {
    test('a custom client that can send REPORT streams with REPORT', () {
      final requests = <SSEClientRequest>[];
      final dataSource = StreamingDataSource(
          credential: 'the-credential',
          context: LDContextBuilder().kind('user', 'test').build(),
          endpoints: ServiceEndpoints(),
          logger: LDLogger(level: LDLogLevel.none),
          dataSourceConfig: StreamingDataSourceConfig(useReport: true),
          pollingDataSourceConfig: PollingDataSourceConfig(useReport: true),
          httpProperties:
              HttpProperties(baseHeaders: {'X-LaunchDarkly-Tags': 'a/b'}),
          clientFactory: (request) {
            requests.add(request);
            return _httpCapableClient(request);
          });

      dataSource.start();

      expect(requests.single.method, SseHttpMethod.report);
      expect(requests.single.body, '{"key":"test","kind":"user"}');
      expect(requests.single.headers, isNot(contains('X-LaunchDarkly-Tags')));
      dataSource.stop();
    });
  });
}
