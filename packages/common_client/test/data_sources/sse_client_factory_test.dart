import 'package:launchdarkly_common_client/launchdarkly_common_client.dart';
import 'package:launchdarkly_common_client/src/data_sources/sse_client_factory.dart';
import 'package:test/test.dart';

void main() {
  group('streamingRequestHeaders', () {
    final properties = HttpProperties(baseHeaders: {
      'X-LaunchDarkly-Tags': 'application-id/app',
      'x-launchdarkly-user-agent': 'agent',
    });

    test('keeps every header when the platform accepts the tags header', () {
      // The test platform is not web, so the service accepts the header.
      expect(
          streamingRequestHeaders(properties, customFactory: true),
          equals({
            'X-LaunchDarkly-Tags': 'application-id/app',
            'x-launchdarkly-user-agent': 'agent',
          }));
    });

    test('keeps every header when no custom factory is set', () {
      expect(streamingRequestHeaders(properties, customFactory: false),
          equals(properties.baseHeaders));
    });
  });
}
