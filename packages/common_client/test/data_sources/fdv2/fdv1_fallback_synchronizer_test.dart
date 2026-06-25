import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:launchdarkly_common_client/src/config/service_endpoints.dart';
import 'package:launchdarkly_common_client/src/data_sources/fdv2/fdv1_fallback_synchronizer.dart';
import 'package:launchdarkly_common_client/src/data_sources/fdv2/mode_definition.dart';
import 'package:launchdarkly_common_client/src/data_sources/fdv2/payload.dart';
import 'package:launchdarkly_common_client/src/data_sources/fdv2/selector.dart';
import 'package:launchdarkly_common_client/src/data_sources/fdv2/source_factory_context.dart';
import 'package:launchdarkly_common_client/src/data_sources/fdv2/source_result.dart';
import 'package:launchdarkly_dart_common/launchdarkly_dart_common.dart'
    hide ServiceEndpoints;
import 'package:test/test.dart';

SourceFactoryContext _ctx(MockClient client) =>
    SourceFactoryContext.fromClientConfig(
      context: LDContextBuilder().kind('user', 'bob').build(),
      logger: LDLogger(level: LDLogLevel.none),
      httpProperties: HttpProperties(),
      serviceEndpoints: ServiceEndpoints(),
      withReasons: false,
      defaultPollingInterval: const Duration(seconds: 300),
      cachedFlagsReader: (_) async => null,
      credential: 'the-credential',
      httpClientFactory: (props) =>
          HttpClient(client: client, httpProperties: props),
    );

Future<FDv2SourceResult> _firstResult(MockClient client) {
  final synchronizer = createFdv1FallbackSynchronizerFactory(
          const Fdv1FallbackConfig(), _ctx(client))
      .create(() => Selector.empty);
  final result = synchronizer.results.first;
  return result.whenComplete(synchronizer.close);
}

void main() {
  test('translates an FDv1 flag map into a full change set with no selector',
      () async {
    final mock = MockClient((_) async => http.Response(
        '{"flagA":{"version":3,"value":true,"variation":0,'
        '"reason":{"kind":"OFF"}}}',
        200));

    final result = await _firstResult(mock);

    expect(result, isA<ChangeSetResult>());
    final changeSetResult = result as ChangeSetResult;
    expect(changeSetResult.changeSet.type, PayloadType.full);
    expect(changeSetResult.changeSet.selector.isEmpty, isTrue,
        reason: 'FDv1 carries no selector');
    expect(changeSetResult.changeSet.updates.keys, contains('flagA'));
    expect(changeSetResult.fdv1Fallback, isFalse,
        reason: 'the fallback tier must never re-assert the directive');
  });

  test('a 304 response becomes a no-op none change set', () async {
    final mock = MockClient((_) async => http.Response('', 304));

    final result = await _firstResult(mock);

    expect(result, isA<ChangeSetResult>());
    expect((result as ChangeSetResult).changeSet.type, PayloadType.none);
    expect(result.fdv1Fallback, isFalse);
  });

  test('a server error surfaces as interrupted without re-triggering fallback',
      () async {
    final mock = MockClient((_) async => http.Response('', 503));

    final result = await _firstResult(mock);

    expect(result, isA<StatusResult>());
    expect((result as StatusResult).state, SourceState.interrupted);
    expect(result.fdv1Fallback, isFalse);
  });

  test('a fresh synchronizer instance does not inherit a prior ETag', () async {
    final requests = <http.Request>[];
    final mock = MockClient((req) async {
      requests.add(req);
      return http.Response(
        '{"flagA":{"version":1,"value":true,"variation":0,'
        '"reason":{"kind":"OFF"}}}',
        200,
        headers: {'etag': 'etag-from-first-connection'},
      );
    });
    final factory = createFdv1FallbackSynchronizerFactory(
        const Fdv1FallbackConfig(), _ctx(mock));

    // First instance polls and receives an ETag.
    final first = factory.create(() => Selector.empty);
    await first.results.first;
    first.close();

    // A second instance (a new connection) must poll without if-none-match;
    // were the ETag shared, it could receive a 304 for a request it never
    // made and silently keep stale data.
    final second = factory.create(() => Selector.empty);
    await second.results.first;
    second.close();

    expect(requests, hasLength(2));
    expect(requests[0].headers.containsKey('if-none-match'), isFalse);
    expect(requests[1].headers.containsKey('if-none-match'), isFalse,
        reason: 'the ETag is scoped to a single requestor instance');
  });
}
