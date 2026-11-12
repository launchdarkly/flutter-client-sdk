import 'package:launchdarkly_common_client/launchdarkly_common_client.dart';
import 'package:launchdarkly_common_client/src/data_sources/streaming_data_source.dart';
import 'package:launchdarkly_common_client/src/ld_common_client.dart'
    show defaultDataSourceFactories;
import 'package:test/test.dart';

final class TestConfig extends LDCommonConfig {
  TestConfig(super.sdkCredential, super.autoEnvAttributes, {super.eventSource});
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

      expect(source.eventSource, same(SSEClient.new));
    });

    test('the streaming source uses the supplied SSE client builder', () {
      final source = streamingSourceFor(TestConfig(
          'key', AutoEnvAttributes.disabled,
          eventSource: SSEClient.http));

      expect(source.eventSource, same(SSEClient.http));
    });
  });
}
