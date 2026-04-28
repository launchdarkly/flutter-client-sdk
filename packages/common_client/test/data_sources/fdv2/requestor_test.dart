import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:launchdarkly_common_client/src/config/service_endpoints.dart';
import 'package:launchdarkly_common_client/src/data_sources/fdv2/requestor.dart';
import 'package:launchdarkly_common_client/src/data_sources/fdv2/selector.dart';
import 'package:launchdarkly_dart_common/launchdarkly_dart_common.dart'
    hide ServiceEndpoints;
import 'package:test/test.dart';

import 'support/capturing_log_adapter.dart';

FDv2Requestor makeRequestor(
  MockClient innerClient, {
  bool usePost = false,
  bool withReasons = false,
  String contextEncoded = 'eyJrZXkiOiJ0ZXN0In0=',
  String contextJson = '{"key":"test"}',
  HttpProperties? httpProperties,
}) {
  return FDv2Requestor(
    logger: LDLogger(),
    endpoints: ServiceEndpoints.custom(polling: 'https://example.test'),
    contextEncoded: contextEncoded,
    contextJson: contextJson,
    usePost: usePost,
    withReasons: withReasons,
    httpProperties: httpProperties ?? HttpProperties(),
    httpClientFactory: (props) =>
        HttpClient(client: innerClient, httpProperties: props),
  );
}

void main() {
  group('GET requests', () {
    test('builds polling GET URL with encoded context in path', () async {
      late Uri capturedUri;
      late String capturedMethod;
      final mock = MockClient((request) async {
        capturedUri = request.url;
        capturedMethod = request.method;
        return http.Response('{}', 200);
      });

      final requestor = makeRequestor(mock, contextEncoded: 'ENC123');
      await requestor.request();

      expect(capturedMethod, equals('GET'));
      expect(capturedUri.path, equals('/sdk/poll/eval/ENC123'));
      expect(capturedUri.host, equals('example.test'));
    });

    test('does not send a body on GET', () async {
      late String capturedBody;
      final mock = MockClient((request) async {
        capturedBody = request.body;
        return http.Response('{}', 200);
      });
      final requestor = makeRequestor(mock);
      await requestor.request();

      expect(capturedBody, isEmpty);
    });
  });

  group('POST requests', () {
    test('builds polling POST URL without context in path', () async {
      late Uri capturedUri;
      late String capturedMethod;
      final mock = MockClient((request) async {
        capturedUri = request.url;
        capturedMethod = request.method;
        return http.Response('{}', 200);
      });

      final requestor = makeRequestor(mock, usePost: true);
      await requestor.request();

      expect(capturedMethod, equals('POST'));
      expect(capturedUri.path, equals('/sdk/poll/eval'));
    });

    test('sends the context JSON as the request body', () async {
      late String capturedBody;
      final mock = MockClient((request) async {
        capturedBody = request.body;
        return http.Response('{}', 200);
      });

      final requestor = makeRequestor(
        mock,
        usePost: true,
        contextJson: '{"key":"alice"}',
      );
      await requestor.request();

      expect(capturedBody, equals('{"key":"alice"}'));
    });

    test('sets content-type header on POST', () async {
      late http.BaseRequest capturedRequest;
      final mock = MockClient((request) async {
        capturedRequest = request;
        return http.Response('{}', 200);
      });

      final requestor = makeRequestor(mock, usePost: true);
      await requestor.request();

      expect(
        capturedRequest.headers,
        containsPair('content-type', 'application/json'),
      );
    });
  });

  group('query parameters', () {
    test('omits basis when selector is empty', () async {
      late Uri capturedUri;
      final mock = MockClient((request) async {
        capturedUri = request.url;
        return http.Response('{}', 200);
      });

      final requestor = makeRequestor(mock);
      await requestor.request();

      expect(capturedUri.queryParameters.containsKey('basis'), isFalse);
    });

    test('includes basis when selector is non-empty', () async {
      late Uri capturedUri;
      final mock = MockClient((request) async {
        capturedUri = request.url;
        return http.Response('{}', 200);
      });

      final requestor = makeRequestor(mock);
      await requestor.request(
          basis: Selector(state: '(p:abc:42)', version: 42));

      expect(capturedUri.queryParameters['basis'], equals('(p:abc:42)'));
    });

    test('includes withReasons=true when configured', () async {
      late Uri capturedUri;
      final mock = MockClient((request) async {
        capturedUri = request.url;
        return http.Response('{}', 200);
      });

      final requestor = makeRequestor(mock, withReasons: true);
      await requestor.request();

      expect(capturedUri.queryParameters['withReasons'], equals('true'));
    });

    test('omits withReasons when not configured', () async {
      late Uri capturedUri;
      final mock = MockClient((request) async {
        capturedUri = request.url;
        return http.Response('{}', 200);
      });

      final requestor = makeRequestor(mock);
      await requestor.request();

      expect(capturedUri.queryParameters.containsKey('withReasons'), isFalse);
    });
  });

  group('etag handling', () {
    test('does not send if-none-match on the first request', () async {
      Map<String, String>? capturedHeaders;
      final mock = MockClient((request) async {
        capturedHeaders = request.headers;
        return http.Response('{}', 200);
      });

      final requestor = makeRequestor(mock);
      await requestor.request();

      expect(capturedHeaders!.containsKey('if-none-match'), isFalse);
    });

    test('sends if-none-match on subsequent requests', () async {
      var requestNumber = 0;
      Map<String, String>? secondRequestHeaders;
      final mock = MockClient((request) async {
        requestNumber++;
        if (requestNumber == 1) {
          return http.Response('{}', 200, headers: {'etag': 'abc-123'});
        }
        secondRequestHeaders = request.headers;
        return http.Response('{}', 200);
      });

      final requestor = makeRequestor(mock);
      await requestor.request();
      await requestor.request();

      expect(
        secondRequestHeaders,
        containsPair('if-none-match', 'abc-123'),
      );
    });

    test('updates etag when a new one is returned', () async {
      var requestNumber = 0;
      Map<String, String>? thirdRequestHeaders;
      final mock = MockClient((request) async {
        requestNumber++;
        if (requestNumber == 1) {
          return http.Response('{}', 200, headers: {'etag': 'abc-123'});
        }
        if (requestNumber == 2) {
          return http.Response('{}', 200, headers: {'etag': 'xyz-456'});
        }
        thirdRequestHeaders = request.headers;
        return http.Response('{}', 200);
      });

      final requestor = makeRequestor(mock);
      await requestor.request();
      await requestor.request();
      await requestor.request();

      expect(
        thirdRequestHeaders,
        containsPair('if-none-match', 'xyz-456'),
      );
    });
  });

  group('response shape', () {
    test('returns status, headers, and body', () async {
      final mock = MockClient((request) async {
        return http.Response('{"key":"value"}', 200,
            headers: {'x-ld-envid': 'env-1'});
      });

      final requestor = makeRequestor(mock);
      final response = await requestor.request();

      expect(response.status, equals(200));
      expect(response.headers, containsPair('x-ld-envid', 'env-1'));
      expect(response.body, equals('{"key":"value"}'));
    });

    test('propagates non-success status codes', () async {
      final mock = MockClient((request) async {
        return http.Response('error', 500);
      });

      final requestor = makeRequestor(mock);
      final response = await requestor.request();

      expect(response.status, equals(500));
      expect(response.body, equals('error'));
    });
  });

  group('errors', () {
    test('throws on network error', () async {
      final mock = MockClient((request) async {
        throw Exception('connection refused');
      });

      final requestor = makeRequestor(mock);

      expect(
        () => requestor.request(),
        throwsException,
      );
    });
  });

  group('etag is only persisted on 200', () {
    test('etag returned on 4xx is not sent on next request', () async {
      var requestNumber = 0;
      Map<String, String>? secondRequestHeaders;
      final mock = MockClient((request) async {
        requestNumber++;
        if (requestNumber == 1) {
          return http.Response('error', 400, headers: {'etag': 'poisoned'});
        }
        secondRequestHeaders = request.headers;
        return http.Response('{}', 200);
      });

      final requestor = makeRequestor(mock);
      await requestor.request();
      await requestor.request();

      expect(secondRequestHeaders!.containsKey('if-none-match'), isFalse);
    });

    test('etag returned on 5xx is not sent on next request', () async {
      var requestNumber = 0;
      Map<String, String>? secondRequestHeaders;
      final mock = MockClient((request) async {
        requestNumber++;
        if (requestNumber == 1) {
          return http.Response('error', 500, headers: {'etag': 'poisoned'});
        }
        secondRequestHeaders = request.headers;
        return http.Response('{}', 200);
      });

      final requestor = makeRequestor(mock);
      await requestor.request();
      await requestor.request();

      expect(secondRequestHeaders!.containsKey('if-none-match'), isFalse);
    });

    test(
        '304 does not overwrite the previously stored etag '
        '(it confirms the existing one)', () async {
      var requestNumber = 0;
      Map<String, String>? thirdRequestHeaders;
      final mock = MockClient((request) async {
        requestNumber++;
        if (requestNumber == 1) {
          return http.Response('{}', 200, headers: {'etag': 'first'});
        }
        if (requestNumber == 2) {
          // 304 returned without an etag header -- the SDK should still
          // remember "first" from the prior 200 response.
          return http.Response('', 304);
        }
        thirdRequestHeaders = request.headers;
        return http.Response('{}', 200);
      });

      final requestor = makeRequestor(mock);
      await requestor.request();
      await requestor.request();
      await requestor.request();

      expect(thirdRequestHeaders, containsPair('if-none-match', 'first'));
    });
  });

  group('custom polling URL with embedded query parameters', () {
    test(
        'preserves query parameters from the base URL '
        'and appends our own', () async {
      late Uri capturedUri;
      final mock = MockClient((request) async {
        capturedUri = request.url;
        return http.Response('{}', 200);
      });

      final requestor = FDv2Requestor(
        logger: LDLogger(),
        endpoints: ServiceEndpoints.custom(
            polling: 'https://relay.example.com/prefix?token=abc123'),
        contextEncoded: 'CTX',
        contextJson: '{"key":"x"}',
        usePost: false,
        withReasons: true,
        httpProperties: HttpProperties(),
        httpClientFactory: (props) =>
            HttpClient(client: mock, httpProperties: props),
      );
      await requestor.request(basis: Selector(state: 'sel-1', version: 1));

      expect(capturedUri.host, equals('relay.example.com'));
      expect(capturedUri.path, equals('/prefix/sdk/poll/eval/CTX'));
      expect(capturedUri.queryParameters['token'], equals('abc123'));
      expect(capturedUri.queryParameters['withReasons'], equals('true'));
      expect(capturedUri.queryParameters['basis'], equals('sel-1'));
    });
  });

  group('basis and withReasons with POST', () {
    test('sends basis as query parameter even on POST', () async {
      late Uri capturedUri;
      final mock = MockClient((request) async {
        capturedUri = request.url;
        return http.Response('{}', 200);
      });

      final requestor = makeRequestor(mock, usePost: true);
      await requestor.request(basis: Selector(state: 'sel-2', version: 2));

      expect(capturedUri.queryParameters['basis'], equals('sel-2'));
    });

    test('sends withReasons=true as query parameter on POST', () async {
      late Uri capturedUri;
      final mock = MockClient((request) async {
        capturedUri = request.url;
        return http.Response('{}', 200);
      });

      final requestor = makeRequestor(mock, usePost: true, withReasons: true);
      await requestor.request();

      expect(capturedUri.queryParameters['withReasons'], equals('true'));
    });
  });

  group('selector edge cases', () {
    test('basis is omitted when state is empty even if isNotEmpty', () async {
      // Defensive: a Selector(state: '', version: 1) constructs as
      // isEmpty=false. The requestor should still not send basis=.
      late Uri capturedUri;
      final mock = MockClient((request) async {
        capturedUri = request.url;
        return http.Response('{}', 200);
      });

      final requestor = makeRequestor(mock);
      await requestor.request(basis: Selector(state: '', version: 1));

      expect(capturedUri.queryParameters.containsKey('basis'), isFalse);
    });
  });

  group('debug logging does not leak the encoded context', () {
    test('the context segment of the URL is not logged', () async {
      final captured = CapturingLogAdapter();
      final logger = LDLogger(adapter: captured, level: LDLogLevel.debug);
      final mock = MockClient((request) async {
        return http.Response('{}', 200);
      });

      final requestor = FDv2Requestor(
        logger: logger,
        endpoints: ServiceEndpoints.custom(polling: 'https://example.test'),
        contextEncoded: 'SECRET-ENCODED-CONTEXT',
        contextJson: '{"key":"x"}',
        usePost: false,
        withReasons: false,
        httpProperties: HttpProperties(),
        httpClientFactory: (props) =>
            HttpClient(client: mock, httpProperties: props),
      );
      await requestor.request();

      for (final message in captured.messages) {
        expect(message, isNot(contains('SECRET-ENCODED-CONTEXT')));
      }
    });
  });

  group('etag edge cases', () {
    test('empty-string etag is not stored', () async {
      var requestNumber = 0;
      Map<String, String>? secondHeaders;
      final mock = MockClient((request) async {
        requestNumber++;
        if (requestNumber == 1) {
          return http.Response('{}', 200, headers: {'etag': ''});
        }
        secondHeaders = request.headers;
        return http.Response('{}', 200);
      });

      final requestor = makeRequestor(mock);
      await requestor.request();
      await requestor.request();

      expect(secondHeaders!.containsKey('if-none-match'), isFalse);
    });

    test('304 with a new etag does NOT overwrite the stored etag', () async {
      // Pinning current behavior: a 304 response confirms the ETag the
      // client already sent; if the server attaches a different ETag we
      // ignore it and continue to use the original. Updating on 304 would
      // mean trusting an unverified value.
      var requestNumber = 0;
      Map<String, String>? thirdHeaders;
      final mock = MockClient((request) async {
        requestNumber++;
        if (requestNumber == 1) {
          return http.Response('{}', 200, headers: {'etag': 'first'});
        }
        if (requestNumber == 2) {
          return http.Response('', 304, headers: {'etag': 'rotated'});
        }
        thirdHeaders = request.headers;
        return http.Response('{}', 200);
      });

      final requestor = makeRequestor(mock);
      await requestor.request();
      await requestor.request();
      await requestor.request();

      expect(thirdHeaders, containsPair('if-none-match', 'first'));
    });
  });

  group('base URL trailing slash', () {
    test('does not produce a double-slash in the merged path', () async {
      late Uri capturedUri;
      final mock = MockClient((request) async {
        capturedUri = request.url;
        return http.Response('{}', 200);
      });

      final requestor = FDv2Requestor(
        logger: LDLogger(),
        endpoints: ServiceEndpoints.custom(
            polling: 'https://relay.example.com/prefix/'),
        contextEncoded: 'CTX',
        contextJson: '{"k":"v"}',
        usePost: false,
        withReasons: false,
        httpProperties: HttpProperties(),
        httpClientFactory: (props) =>
            HttpClient(client: mock, httpProperties: props),
      );
      await requestor.request();

      expect(capturedUri.path, equals('/prefix/sdk/poll/eval/CTX'));
    });
  });

  group('base URL with duplicate-key query parameters', () {
    test('preserves all values for repeated keys', () async {
      late Uri capturedUri;
      final mock = MockClient((request) async {
        capturedUri = request.url;
        return http.Response('{}', 200);
      });

      final requestor = FDv2Requestor(
        logger: LDLogger(),
        endpoints: ServiceEndpoints.custom(
            polling: 'https://relay.example.com/?tag=a&tag=b'),
        contextEncoded: 'CTX',
        contextJson: '{"k":"v"}',
        usePost: false,
        withReasons: false,
        httpProperties: HttpProperties(),
        httpClientFactory: (props) =>
            HttpClient(client: mock, httpProperties: props),
      );
      await requestor.request();

      expect(capturedUri.queryParametersAll['tag'], equals(['a', 'b']));
    });
  });
}
