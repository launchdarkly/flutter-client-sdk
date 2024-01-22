import 'package:http/testing.dart';
import 'package:launchdarkly_dart_common/launchdarkly_dart_common.dart';
import 'package:test/test.dart';
import 'package:http/http.dart' as http;

void main() {
  test('it includes headers from http properties', () async {
    var methodCalled = false;
    final innerClient = MockClient((request) async {
      methodCalled = true;
      expect(request.body, '');
      expect(request.headers, {'test': 'header', 'a': 'b'});
      return http.Response('', 200);
    });

    final client = HttpClient(
        client: innerClient,
        httpProperties:
            HttpProperties(baseHeaders: {'test': 'header', 'a': 'b'}));

    await client.request(RequestMethod.get, Uri.parse('0.0.0.0'));
    expect(methodCalled, isTrue);
  });

  test('it includes combined headers from request and http properties',
      () async {
    var methodCalled = false;
    final innerClient = MockClient((request) async {
      methodCalled = true;
      expect(request.headers, {'test': 'header', 'a': 'b'});
      return http.Response('', 200);
    });

    final client = HttpClient(
        client: innerClient,
        httpProperties: HttpProperties(baseHeaders: {'test': 'header'}));

    await client.request(RequestMethod.get, Uri.parse('0.0.0.0'),
        additionalHeaders: {'a': 'b'});
    expect(methodCalled, isTrue);
  });

  test('it filters headers for the platform', () async {
    var methodCalled = false;
    final innerClient = MockClient((request) async {
      methodCalled = true;
      expect(request.body, '');
      expect(request.headers, {'a': 'b'});
      return http.Response('', 200);
    });

    final client = HttpClient(
        client: innerClient,
        forbiddenHeaders: {'test'},
        httpProperties:
            HttpProperties(baseHeaders: {'test': 'header', 'a': 'b'}));

    await client.request(RequestMethod.get, Uri.parse('0.0.0.0'));
    expect(methodCalled, isTrue);
  });

  group('given different http methods', () {
    for (var MapEntry(key: method, value: stringMethod)
        in <RequestMethod, String>{
      RequestMethod.get: 'GET',
      RequestMethod.post: 'POST',
      RequestMethod.report: 'REPORT'
    }.entries) {
      test('it uses the correct http method: $method', () async {
        var methodCalled = false;
        final innerClient = MockClient((request) async {
          methodCalled = true;
          expect(request.method, stringMethod);
          return http.Response('', 200);
        });

        final client =
            HttpClient(client: innerClient, httpProperties: HttpProperties());

        await client.request(method, Uri.parse('0.0.0.0'));
        expect(methodCalled, isTrue);
      });
    }
  });

  test('it sends the body if one is included', () async {
    var methodCalled = false;
    final innerClient = MockClient((request) async {
      methodCalled = true;
      expect(request.body, 'the-message-body');
      return http.Response('', 200);
    });

    final client =
        HttpClient(client: innerClient, httpProperties: HttpProperties());

    await client.request(RequestMethod.get, Uri.parse('0.0.0.0'),
        body: 'the-message-body');
    expect(methodCalled, isTrue);
  });

  group('given different responses', () {
    for (var expected in <http.Response>[
      http.Response('', 200),
      http.Response('', 404),
      http.Response('the-body', 200),
      http.Response('another-body', 304, headers: {'test': 'value'})
    ]) {
      test(
          'it includes the response body and headers in the response ${expected.statusCode}:${expected.body}:${expected.headers}',
          () async {
        var methodCalled = false;
        final innerClient = MockClient((request) async {
          methodCalled = true;
          return expected;
        });

        final client =
            HttpClient(client: innerClient, httpProperties: HttpProperties());

        final actual = await client.request(
            RequestMethod.get, Uri.parse('0.0.0.0'),
            body: 'the-message-body');
        expect(methodCalled, isTrue);
        expect(actual.body, expected.body);
        expect(actual.statusCode, expected.statusCode);
        expect(actual.headers, expected.headers);
      });
    }
  });
}
