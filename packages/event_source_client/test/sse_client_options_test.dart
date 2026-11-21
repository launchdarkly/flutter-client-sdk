import 'package:launchdarkly_event_source_client/launchdarkly_event_source_client.dart';
import 'package:test/test.dart';

void main() {
  test('copyWith replaces the given fields and keeps the others', () {
    final options = SseClientOptions(
        uri: Uri.parse('https://example.test'),
        eventTypes: {'put'},
        headers: {'a': 'b'},
        body: 'body',
        httpMethod: SseHttpMethod.report);

    // Replace two fields.
    final copy = options.copyWith(
        uri: Uri.parse('https://other.test'), autoReconnect: false);
    // The copy has the new values, and the original values of the rest.
    expect(copy.uri, Uri.parse('https://other.test'));
    expect(copy.autoReconnect, isFalse);
    expect(copy.eventTypes, {'put'});
    expect(copy.headers, {'a': 'b'});
    expect(copy.body, 'body');
    expect(copy.httpMethod, SseHttpMethod.report);
    expect(copy.connectTimeout, SSEClient.defaultConnectTimeout);
    expect(copy.readTimeout, SSEClient.defaultReadTimeout);
  });
}
