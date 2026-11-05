import 'package:launchdarkly_common_client/launchdarkly_common_client.dart';
import 'package:launchdarkly_common_client/src/data_sources/streaming_data_source.dart';
import 'package:launchdarkly_common_client/src/ld_common_client.dart'
    show defaultDataSourceFactories;
import 'package:launchdarkly_event_source_client/launchdarkly_event_source_client.dart';
import 'package:test/test.dart';

final class TestConfig extends LDCommonConfig {
  TestConfig(super.sdkCredential, super.autoEnvAttributes,
      {super.useHttpStreamingOnWeb});
}

void main() {
  group('defaultDataSourceFactories', () {
    StreamingDataSource streamingSourceFor(TestConfig config) {
      final factories = defaultDataSourceFactories(
          config, LDLogger(level: LDLogLevel.none), HttpProperties());
      final context = LDContextBuilder().kind('user', 'test').build();
      final source = switch (factories[ConnectionMode.streaming]) {
        final factory? => factory(context),
        null => fail('no streaming factory'),
      };
      return source as StreamingDataSource;
    }

    test('the streaming source uses the default SSE client without the option',
        () {
      final source =
          streamingSourceFor(TestConfig('key', AutoEnvAttributes.disabled));

      expect(source.clientBuilder, same(SSEClient.new));
    });

    test('the streaming source uses the HTTP SSE client with the option', () {
      final source = streamingSourceFor(TestConfig(
          'key', AutoEnvAttributes.disabled,
          useHttpStreamingOnWeb: true));

      expect(source.clientBuilder, same(SSEClient.http));
    });
  });
}
