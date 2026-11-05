import 'package:launchdarkly_event_source_client/launchdarkly_event_source_client.dart';
import 'package:launchdarkly_event_source_client/src/http_sse_headers.dart';
import 'package:test/test.dart';

// The web case runs with `dart test test/http_sse_headers_test.dart -p chrome`.
void main() {
  test('on web, sends accept and cache-control and no user-agent', () {
    final headers = httpSseClientHeaders({'authorization': 'key'});

    expect(headers, {
      'accept': 'text/event-stream',
      'cache-control': 'no-cache',
      'authorization': 'key',
    });
  }, testOn: 'browser');

  test('on other platforms, sends the default headers', () {
    final headers = httpSseClientHeaders({'authorization': 'key'});

    expect(headers, {...SSEClient.defaultHeaders, 'authorization': 'key'});
  }, testOn: 'vm');

  test('a caller header replaces a default header', () {
    final headers = httpSseClientHeaders({'accept': 'application/json'});

    expect(headers['accept'], 'application/json');
  });
}
