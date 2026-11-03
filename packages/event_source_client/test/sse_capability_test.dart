// ignore_for_file: close_sinks

import 'package:launchdarkly_event_source_client/launchdarkly_event_source_client.dart';
import 'package:test/test.dart';

const _httpCapabilities = [
  SSECapability.requestHeaders,
  SSECapability.customMethod,
  SSECapability.httpErrors,
];

void expectCapabilities(SSEClient client, {required bool supported}) {
  for (final capability in _httpCapabilities) {
    expect(client.hasCapability(capability), supported,
        reason: capability.toString());
  }
}

void main() {
  // On web the default client is the browser EventSource, which has none of
  // these capabilities.
  group('default HTTP SSE client', () {
    test('reports every HTTP capability as supported', () {
      final client = SSEClient(Uri.parse('https://example.test'), {'put'});
      try {
        expectCapabilities(client, supported: true);
      } finally {
        client.close();
      }
    }, testOn: 'vm');
  });

  group('SSEClient.http', () {
    test('reports every HTTP capability as supported', () {
      final client = SSEClient.http(Uri.parse('https://example.test'), {'put'});
      try {
        expectCapabilities(client, supported: true);
      } finally {
        client.close();
      }
    });
  });

  group('TestSseClient', () {
    test(
        'defaults to the capabilities of the production HTTP client so '
        'existing streaming tests behave like it', () {
      final client = SSEClient.testClient(Uri.parse('/x'), {'put'});
      try {
        expectCapabilities(client, supported: true);
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
        expectCapabilities(client, supported: false);
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
        expect(client.hasCapability(SSECapability.customMethod), isFalse);
      } finally {
        client.close();
      }
    });
  });
}
