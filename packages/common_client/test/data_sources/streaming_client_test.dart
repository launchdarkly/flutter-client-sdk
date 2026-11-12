@TestOn('vm')
library;

import 'package:launchdarkly_common_client/launchdarkly_common_client.dart';
import 'package:launchdarkly_common_client/src/data_sources/streaming_client.dart';
import 'package:test/test.dart';

// The web behavior is in streaming_client_web_test.dart.
void main() {
  group('streamingCustomMethodSupported', () {
    test(
        'is true with and without a supplied builder, because the default '
        'client is HTTP-based', () {
      expect(streamingCustomMethodSupported(eventSource: null), isTrue);
      expect(
          streamingCustomMethodSupported(eventSource: SSEClient.new), isTrue);
      expect(
          streamingCustomMethodSupported(eventSource: SSEClient.http), isTrue);
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
