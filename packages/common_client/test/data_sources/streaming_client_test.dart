@TestOn('vm')
library;

import 'package:launchdarkly_common_client/launchdarkly_common_client.dart';
import 'package:launchdarkly_common_client/src/data_sources/streaming_client.dart';
import 'package:launchdarkly_event_source_client/launchdarkly_event_source_client.dart';
import 'package:test/test.dart';

// The web behavior is in streaming_client_web_test.dart.
void main() {
  group('sseClientBuilderFor', () {
    test('selects the default client without the option', () {
      expect(sseClientBuilderFor(useHttpStreamingOnWeb: false), SSEClient.new);
    });

    test('selects the HTTP client with the option', () {
      expect(sseClientBuilderFor(useHttpStreamingOnWeb: true), SSEClient.http);
    });
  });

  group('streamingCustomMethodSupported', () {
    test(
        'is true with and without the option, because the default client '
        'is HTTP-based', () {
      expect(
          streamingCustomMethodSupported(useHttpStreamingOnWeb: false), isTrue);
      expect(
          streamingCustomMethodSupported(useHttpStreamingOnWeb: true), isTrue);
    });
  });

  group('streamingRequestHeaders', () {
    final properties = HttpProperties(baseHeaders: {
      'X-LaunchDarkly-Tags': 'application-id/app',
      'x-launchdarkly-user-agent': 'agent',
    });

    test('keeps every header, because the service accepts the tags header', () {
      expect(
          streamingRequestHeaders(properties), equals(properties.baseHeaders));
    });
  });
}
