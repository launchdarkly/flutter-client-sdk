// ignore_for_file: close_sinks

import 'package:launchdarkly_event_source_client/launchdarkly_event_source_client.dart';
import 'package:test/test.dart';

void main() {
  group('default HTTP SSE client', () {
    test('reports SSECapability.requestHeaders as supported', () {
      final client = SSEClient(Uri.parse('https://example.test'), {'put'});
      try {
        expect(client.hasCapability(SSECapability.requestHeaders), isTrue);
        expect(client.hasCapability(SSECapability.customMethod), isTrue);
        expect(client.hasCapability(SSECapability.httpErrors), isTrue);
      } finally {
        client.close();
      }
    });
  });

  group('SSEClient.http', () {
    test('reports every HTTP capability as supported', () {
      final client = SSEClient.http(Uri.parse('https://example.test'), {'put'});
      try {
        expect(client.hasCapability(SSECapability.requestHeaders), isTrue);
        expect(client.hasCapability(SSECapability.customMethod), isTrue);
        expect(client.hasCapability(SSECapability.httpErrors), isTrue);
      } finally {
        client.close();
      }
    });
  });

  group('TestSseClient', () {
    test(
        'defaults to supporting SSECapability.requestHeaders so existing '
        'streaming tests behave like the production HTTP client', () {
      final client = SSEClient.testClient(Uri.parse('/x'), {'put'});
      try {
        expect(client.hasCapability(SSECapability.requestHeaders), isTrue);
      } finally {
        client.close();
      }
    });

    test('defaults to the capabilities of the production HTTP client', () {
      final client = SSEClient.testClient(Uri.parse('/x'), {'put'});
      try {
        expect(client.hasCapability(SSECapability.customMethod), isTrue);
        expect(client.hasCapability(SSECapability.httpErrors), isTrue);
      } finally {
        client.close();
      }
    });

    test('honors an empty capability set to simulate the browser EventSource',
        () {
      final client = SSEClient.testClient(
        Uri.parse('/x'),
        {'put'},
        capabilities: const {},
      );
      try {
        expect(client.hasCapability(SSECapability.requestHeaders), isFalse);
        expect(client.hasCapability(SSECapability.customMethod), isFalse);
        expect(client.hasCapability(SSECapability.httpErrors), isFalse);
      } finally {
        client.close();
      }
    });

    test('honors an explicit capability set', () {
      final client = SSEClient.testClient(
        Uri.parse('/x'),
        {'put'},
        capabilities: const {SSECapability.requestHeaders},
      );
      try {
        expect(client.hasCapability(SSECapability.requestHeaders), isTrue);
      } finally {
        client.close();
      }
    });
  });
}
