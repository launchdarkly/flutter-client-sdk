import 'dart:convert';

import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:launchdarkly_common_client/src/config/service_endpoints.dart';
import 'package:launchdarkly_common_client/src/data_sources/fdv2/payload.dart';
import 'package:launchdarkly_common_client/src/data_sources/fdv2/polling_base.dart';
import 'package:launchdarkly_common_client/src/data_sources/fdv2/requestor.dart';
import 'package:launchdarkly_common_client/src/data_sources/fdv2/source_result.dart';
import 'package:launchdarkly_dart_common/launchdarkly_dart_common.dart'
    hide ServiceEndpoints;
import 'package:test/test.dart';

FDv2PollingBase makePollingBase(
  MockClient innerClient, {
  DateTime Function()? now,
}) {
  final requestor = FDv2Requestor(
    logger: LDLogger(),
    endpoints: ServiceEndpoints.custom(polling: 'https://example.test'),
    contextEncoded: 'CTX',
    contextJson: '{"key":"test"}',
    usePost: false,
    withReasons: false,
    httpProperties: HttpProperties(),
    httpClientFactory: (props) =>
        HttpClient(client: innerClient, httpProperties: props),
  );
  return FDv2PollingBase(
    logger: LDLogger(),
    requestor: requestor,
    now: now,
  );
}

/// Builds a complete xfer-full FDv2 events collection JSON body with a
/// single put-object for `flag-eval`.
String buildXferFullBody({
  String state = 'sel-1',
  int targetVersion = 1,
  int payloadVersion = 1,
  String flagKey = 'my-flag',
}) {
  return jsonEncode({
    'events': [
      {
        'event': 'server-intent',
        'data': {
          'payloads': [
            {
              'id': 'p1',
              'target': targetVersion,
              'intentCode': 'xfer-full',
              'reason': 'test',
            }
          ]
        }
      },
      {
        'event': 'put-object',
        'data': {
          'kind': 'flag-eval',
          'key': flagKey,
          'version': payloadVersion,
          'object': {
            'value': true,
            'version': payloadVersion,
            'variation': 0,
            'trackEvents': false,
          },
        }
      },
      {
        'event': 'payload-transferred',
        'data': {
          'state': state,
          'version': payloadVersion,
        }
      },
    ]
  });
}

void main() {
  group('200 response with valid payload', () {
    test('produces a ChangeSetResult with the parsed payload', () async {
      final mock = MockClient((request) async {
        return http.Response(
            buildXferFullBody(state: 'sel-99', payloadVersion: 99), 200);
      });

      final base = makePollingBase(mock);
      final result = await base.pollOnce();

      expect(result, isA<ChangeSetResult>());
      final cs = result as ChangeSetResult;
      expect(cs.payload.type, equals(PayloadType.full));
      expect(cs.payload.selector.state, equals('sel-99'));
      expect(cs.payload.selector.version, equals(99));
      expect(cs.payload.updates, hasLength(1));
      expect(cs.payload.updates[0].key, equals('my-flag'));
      expect(cs.persist, isTrue);
    });

    test('propagates the x-ld-envid header to the result', () async {
      final mock = MockClient((request) async {
        return http.Response(buildXferFullBody(), 200,
            headers: {'x-ld-envid': 'env-abc'});
      });

      final base = makePollingBase(mock);
      final result = await base.pollOnce();

      expect((result as ChangeSetResult).environmentId, equals('env-abc'));
    });

    test('sets freshness to the result of the now function', () async {
      final fixedNow = DateTime.utc(2026, 4, 16, 12, 0, 0);
      final mock = MockClient((request) async {
        return http.Response(buildXferFullBody(), 200);
      });

      final base = makePollingBase(mock, now: () => fixedNow);
      final result = await base.pollOnce();

      expect((result as ChangeSetResult).freshness, equals(fixedNow));
    });
  });

  group('304 Not Modified', () {
    test('produces a ChangeSetResult with PayloadType.none', () async {
      final mock = MockClient((request) async {
        return http.Response('', 304);
      });

      final base = makePollingBase(mock);
      final result = await base.pollOnce();

      expect(result, isA<ChangeSetResult>());
      final cs = result as ChangeSetResult;
      expect(cs.payload.type, equals(PayloadType.none));
      expect(cs.payload.updates, isEmpty);
      expect(cs.persist, isTrue);
    });
  });

  group('FDv1 fallback', () {
    test(
        'returns terminalError with fdv1Fallback=true when '
        'x-ld-fd-fallback is true', () async {
      final mock = MockClient((request) async {
        return http.Response('', 200, headers: {'x-ld-fd-fallback': 'true'});
      });

      final base = makePollingBase(mock);
      final result = await base.pollOnce();

      expect(result, isA<StatusResult>());
      final status = result as StatusResult;
      expect(status.state, equals(SourceState.terminalError));
      expect(status.fdv1Fallback, isTrue);
    });

    test('does not engage fallback when header is missing', () async {
      final mock = MockClient((request) async {
        return http.Response(buildXferFullBody(), 200);
      });

      final base = makePollingBase(mock);
      final result = await base.pollOnce();

      expect(result, isA<ChangeSetResult>());
      expect(result.fdv1Fallback, isFalse);
    });
  });

  group('HTTP error classification', () {
    test('400 is interrupted (recoverable)', () async {
      final mock = MockClient((request) async {
        return http.Response('bad request', 400);
      });

      final base = makePollingBase(mock);
      final result = await base.pollOnce();

      final status = result as StatusResult;
      expect(status.state, equals(SourceState.interrupted));
      expect(status.statusCode, equals(400));
    });

    test('408 is interrupted', () async {
      final mock = MockClient((request) async {
        return http.Response('timeout', 408);
      });

      final base = makePollingBase(mock);
      final result = await base.pollOnce();

      expect((result as StatusResult).state, equals(SourceState.interrupted));
    });

    test('429 is interrupted', () async {
      final mock = MockClient((request) async {
        return http.Response('rate limited', 429);
      });

      final base = makePollingBase(mock);
      final result = await base.pollOnce();

      expect((result as StatusResult).state, equals(SourceState.interrupted));
    });

    test('401 is terminalError', () async {
      final mock = MockClient((request) async {
        return http.Response('unauthorized', 401);
      });

      final base = makePollingBase(mock);
      final result = await base.pollOnce();

      expect((result as StatusResult).state, equals(SourceState.terminalError));
    });

    test('403 is terminalError', () async {
      final mock = MockClient((request) async {
        return http.Response('forbidden', 403);
      });

      final base = makePollingBase(mock);
      final result = await base.pollOnce();

      expect((result as StatusResult).state, equals(SourceState.terminalError));
    });

    test('500 is interrupted (5xx is recoverable)', () async {
      final mock = MockClient((request) async {
        return http.Response('server error', 500);
      });

      final base = makePollingBase(mock);
      final result = await base.pollOnce();

      expect((result as StatusResult).state, equals(SourceState.interrupted));
    });
  });

  group('network failures', () {
    test('returns interrupted when the requestor throws', () async {
      final mock = MockClient((request) async {
        throw Exception('connection refused');
      });

      final base = makePollingBase(mock);
      final result = await base.pollOnce();

      expect((result as StatusResult).state, equals(SourceState.interrupted));
    });
  });

  group('malformed bodies', () {
    test('returns interrupted when body is not valid JSON', () async {
      final mock = MockClient((request) async {
        return http.Response('not json', 200);
      });

      final base = makePollingBase(mock);
      final result = await base.pollOnce();

      expect((result as StatusResult).state, equals(SourceState.interrupted));
    });

    test('returns interrupted when body is JSON but not an object', () async {
      final mock = MockClient((request) async {
        return http.Response('[1, 2, 3]', 200);
      });

      final base = makePollingBase(mock);
      final result = await base.pollOnce();

      expect((result as StatusResult).state, equals(SourceState.interrupted));
    });

    test('returns interrupted when no payload-transferred is present',
        () async {
      final body = jsonEncode({
        'events': [
          {
            'event': 'server-intent',
            'data': {
              'payloads': [
                {
                  'id': 'p1',
                  'target': 1,
                  'intentCode': 'xfer-full',
                  'reason': 'test',
                }
              ]
            }
          }
        ]
      });
      final mock = MockClient((request) async {
        return http.Response(body, 200);
      });

      final base = makePollingBase(mock);
      final result = await base.pollOnce();

      expect((result as StatusResult).state, equals(SourceState.interrupted));
    });
  });

  group('protocol-level outcomes', () {
    test('goodbye event produces a goodbye StatusResult', () async {
      final body = jsonEncode({
        'events': [
          {
            'event': 'server-intent',
            'data': {
              'payloads': [
                {
                  'id': 'p1',
                  'target': 1,
                  'intentCode': 'xfer-full',
                  'reason': 'test',
                }
              ]
            }
          },
          {
            'event': 'goodbye',
            'data': {'reason': 'maintenance'}
          },
        ]
      });
      final mock = MockClient((request) async {
        return http.Response(body, 200);
      });

      final base = makePollingBase(mock);
      final result = await base.pollOnce();

      expect((result as StatusResult).state, equals(SourceState.goodbye));
    });

    test('server error event produces interrupted', () async {
      final body = jsonEncode({
        'events': [
          {
            'event': 'server-intent',
            'data': {
              'payloads': [
                {
                  'id': 'p1',
                  'target': 1,
                  'intentCode': 'xfer-full',
                  'reason': 'test',
                }
              ]
            }
          },
          {
            'event': 'error',
            'data': {'payload_id': 'p1', 'reason': 'oops'}
          },
        ]
      });
      final mock = MockClient((request) async {
        return http.Response(body, 200);
      });

      final base = makePollingBase(mock);
      final result = await base.pollOnce();

      expect((result as StatusResult).state, equals(SourceState.interrupted));
    });

    test('intent-none on a 200 produces a none change set', () async {
      final body = jsonEncode({
        'events': [
          {
            'event': 'server-intent',
            'data': {
              'payloads': [
                {
                  'id': 'p1',
                  'target': 7,
                  'intentCode': 'none',
                  'reason': 'up-to-date',
                }
              ]
            }
          },
        ]
      });
      final mock = MockClient((request) async {
        return http.Response(body, 200);
      });

      final base = makePollingBase(mock);
      final result = await base.pollOnce();

      expect(result, isA<ChangeSetResult>());
      final cs = result as ChangeSetResult;
      expect(cs.payload.type, equals(PayloadType.none));
      expect(cs.payload.updates, isEmpty);
    });

    test('heartbeat-only response is interrupted', () async {
      final body = jsonEncode({
        'events': [
          {'event': 'heart-beat', 'data': {}}
        ]
      });
      final mock = MockClient((request) async {
        return http.Response(body, 200);
      });

      final base = makePollingBase(mock);
      final result = await base.pollOnce();

      expect((result as StatusResult).state, equals(SourceState.interrupted));
    });
  });

  group('malformed event shapes (do not throw)', () {
    test('non-Map element in events array produces interrupted', () async {
      final body = jsonEncode({
        'events': [42]
      });
      final mock = MockClient((request) async {
        return http.Response(body, 200);
      });

      final base = makePollingBase(mock);
      final result = await base.pollOnce();

      expect((result as StatusResult).state, equals(SourceState.interrupted));
    });

    test('non-Map element in payloads array produces interrupted', () async {
      final body = jsonEncode({
        'events': [
          {
            'event': 'server-intent',
            'data': {
              'payloads': ['not-an-object']
            }
          }
        ]
      });
      final mock = MockClient((request) async {
        return http.Response(body, 200);
      });

      final base = makePollingBase(mock);
      final result = await base.pollOnce();

      expect((result as StatusResult).state, equals(SourceState.interrupted));
    });

    test('object field of put-object that is not a Map produces interrupted',
        () async {
      final body = jsonEncode({
        'events': [
          {
            'event': 'server-intent',
            'data': {
              'payloads': [
                {
                  'id': 'p1',
                  'target': 1,
                  'intentCode': 'xfer-full',
                  'reason': 'test',
                }
              ]
            }
          },
          {
            'event': 'put-object',
            'data': {
              'kind': 'flag-eval',
              'key': 'k',
              'version': 1,
              'object': 'not-a-map',
            }
          },
        ]
      });
      final mock = MockClient((request) async {
        return http.Response(body, 200);
      });

      final base = makePollingBase(mock);
      final result = await base.pollOnce();

      // Either interrupted (if the cast throws) or interrupted (if the
      // event is silently skipped and no payload-transferred follows).
      // Both outcomes are acceptable; the contract is "do not throw".
      expect((result as StatusResult).state, equals(SourceState.interrupted));
    });
  });

  group('FDv1 fallback precedence', () {
    test('fallback header takes precedence over a 200 with valid payload',
        () async {
      final mock = MockClient((request) async {
        return http.Response(buildXferFullBody(), 200,
            headers: {'x-ld-fd-fallback': 'true'});
      });

      final base = makePollingBase(mock);
      final result = await base.pollOnce();

      expect(result, isA<StatusResult>());
      final status = result as StatusResult;
      expect(status.state, equals(SourceState.terminalError));
      expect(status.fdv1Fallback, isTrue);
    });

    test('fallback header takes precedence over a 304', () async {
      final mock = MockClient((request) async {
        return http.Response('', 304, headers: {'x-ld-fd-fallback': 'true'});
      });

      final base = makePollingBase(mock);
      final result = await base.pollOnce();

      expect((result as StatusResult).state, equals(SourceState.terminalError));
      expect(result.fdv1Fallback, isTrue);
    });

    test('fallback header is matched case-insensitively', () async {
      final mock = MockClient((request) async {
        return http.Response('', 200, headers: {'x-ld-fd-fallback': 'TRUE'});
      });

      final base = makePollingBase(mock);
      final result = await base.pollOnce();

      expect((result as StatusResult).state, equals(SourceState.terminalError));
      expect(result.fdv1Fallback, isTrue);
    });

    test('fallback header value other than true is ignored', () async {
      final mock = MockClient((request) async {
        return http.Response(buildXferFullBody(), 200,
            headers: {'x-ld-fd-fallback': 'false'});
      });

      final base = makePollingBase(mock);
      final result = await base.pollOnce();

      expect(result, isA<ChangeSetResult>());
      expect(result.fdv1Fallback, isFalse);
    });
  });

  group('error message sanitization', () {
    test('exception message is not echoed verbatim into the result', () async {
      const sensitive = '203.0.113.5:443 cert CN=internal.example.com';
      final mock = MockClient((request) async {
        throw Exception(sensitive);
      });

      final base = makePollingBase(mock);
      final result = await base.pollOnce();

      final status = result as StatusResult;
      expect(status.state, equals(SourceState.interrupted));
      expect(status.message, isNotNull);
      expect(status.message, isNot(contains(sensitive)));
    });
  });
}
