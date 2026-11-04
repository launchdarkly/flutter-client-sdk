@TestOn('vm')
library;

import 'package:launchdarkly_common_client/launchdarkly_common_client.dart';
import 'package:launchdarkly_common_client/src/data_sources/sse_client_factory.dart';
import 'package:test/test.dart';

// The web behavior is in sse_client_factory_web_test.dart.
void main() {
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
