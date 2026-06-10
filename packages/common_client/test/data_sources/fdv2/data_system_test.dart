import 'dart:async';
import 'dart:collection';
import 'dart:convert';

import 'package:launchdarkly_common_client/src/config/data_system_config.dart';
import 'package:launchdarkly_common_client/src/config/service_endpoints.dart';
import 'package:launchdarkly_common_client/src/data_sources/data_source.dart';
import 'package:launchdarkly_common_client/src/data_sources/data_source_status_manager.dart';
import 'package:launchdarkly_common_client/src/data_sources/fdv2/data_system.dart';
import 'package:launchdarkly_common_client/src/data_sources/fdv2/mode_definition.dart';
import 'package:launchdarkly_common_client/src/data_sources/fdv2/orchestrator.dart';
import 'package:launchdarkly_common_client/src/fdv2_connection_mode.dart';
import 'package:launchdarkly_dart_common/launchdarkly_dart_common.dart'
    hide ServiceEndpoints;
import 'package:launchdarkly_event_source_client/launchdarkly_event_source_client.dart';
import 'package:test/test.dart';

/// Captures every SSE client the data system constructs along with the
/// URI provider used for its connection attempts.
final class CapturingSseFactory {
  final List<TestSseClient> clients = [];
  final List<Uri Function()> uriProviders = [];

  SSEClient call({
    required Uri Function() uriProvider,
    required HttpProperties httpProperties,
    required String? body,
    required SseHttpMethod method,
    required EventSourceLogger logger,
  }) {
    uriProviders.add(uriProvider);
    final client = SSEClient.testClient(uriProvider(), const {});
    clients.add(client);
    return client;
  }
}

void emitFullPayload(TestSseClient sse, {required String state}) {
  sse.emitEvent(OpenEvent(headers: UnmodifiableMapView(const {})));
  sse.emitEvent(MessageEvent(
      'server-intent',
      jsonEncode({
        'payloads': [
          {'id': 'p1', 'target': 1, 'intentCode': 'xfer-full', 'reason': 'test'}
        ]
      }),
      null));
  sse.emitEvent(MessageEvent(
      'put-object',
      jsonEncode({
        'kind': 'flag-eval',
        'key': 'flag-a',
        'version': 1,
        'object': {'value': true, 'variation': 0},
      }),
      null));
  sse.emitEvent(MessageEvent(
      'payload-transferred', jsonEncode({'state': state, 'version': 1}), null));
}

void main() {
  final context = LDContextBuilder().kind('user', 'user-key').build();

  ({FDv2DataSystem dataSystem, CapturingSseFactory sse}) makeDataSystem() {
    final sse = CapturingSseFactory();
    final dataSystem = FDv2DataSystem(
      config: const DataSystemConfig(customConnectionModes: {
        // Synchronizer only, so connection behavior is fully driven by
        // the captured SSE clients.
        'streaming': ModeDefinition(
          initializers: [],
          synchronizers: [StreamingSynchronizer()],
        ),
      }),
      credential: 'the-credential',
      logger: LDLogger(level: LDLogLevel.none),
      httpProperties: HttpProperties(),
      serviceEndpoints: ServiceEndpoints.custom(
          polling: 'https://poll.test', streaming: 'https://stream.test'),
      withReasons: false,
      defaultPollingInterval: const Duration(seconds: 300),
      statusManager: DataSourceStatusManager(),
      sseClientFactory: sse.call,
    );
    return (dataSystem: dataSystem, sse: sse);
  }

  test('produces a factory for each non-offline connection mode', () {
    final (:dataSystem, sse: _) = makeDataSystem();
    final factories = dataSystem.buildFactories();

    expect(
        factories.keys,
        containsAll([
          const FDv2Streaming(),
          const FDv2Polling(),
          const FDv2Background()
        ]));
    expect(factories[const FDv2Streaming()]!.call(context),
        isA<FDv2DataSourceOrchestrator>());
  });

  test('emits payload events from the configured streaming synchronizer',
      () async {
    final (:dataSystem, :sse) = makeDataSystem();
    final source = dataSystem.buildFactories()[const FDv2Streaming()]!(context);

    final events = <DataSourceEvent>[];
    final subscription = source.events.listen(events.add);
    source.start();
    await Future<void>.delayed(Duration.zero);

    emitFullPayload(sse.clients.single, state: 'state-1');
    await Future<void>.delayed(Duration.zero);

    expect(events.whereType<PayloadEvent>(), hasLength(1));

    source.stop();
    await subscription.cancel();
  });

  test('the selector persists across data sources for the same context',
      () async {
    final (:dataSystem, :sse) = makeDataSystem();
    final factory = dataSystem.buildFactories()[const FDv2Streaming()]!;

    final first = factory(context);
    final subscription = first.events.listen((_) {});
    first.start();
    await Future<void>.delayed(Duration.zero);
    emitFullPayload(sse.clients.single, state: 'state-1');
    await Future<void>.delayed(Duration.zero);
    first.stop();
    await subscription.cancel();

    // A connection-mode switch constructs a new data source for the
    // same context instance; its connection carries the held selector.
    final second = factory(context);
    final secondSubscription = second.events.listen((_) {});
    second.start();
    await Future<void>.delayed(Duration.zero);

    expect(sse.uriProviders, hasLength(2));
    expect(sse.uriProviders.last().queryParameters['basis'], equals('state-1'));

    second.stop();
    await secondSubscription.cancel();
  });

  test('the selector resets for a new context instance', () async {
    final (:dataSystem, :sse) = makeDataSystem();
    final factory = dataSystem.buildFactories()[const FDv2Streaming()]!;

    final first = factory(context);
    final subscription = first.events.listen((_) {});
    first.start();
    await Future<void>.delayed(Duration.zero);
    emitFullPayload(sse.clients.single, state: 'state-1');
    await Future<void>.delayed(Duration.zero);
    first.stop();
    await subscription.cancel();

    // An identify produces a freshly decorated context instance; the
    // selector belongs to a single context and must not carry over.
    final newContext = LDContextBuilder().kind('user', 'user-key').build();
    final second = factory(newContext);
    final secondSubscription = second.events.listen((_) {});
    second.start();
    await Future<void>.delayed(Duration.zero);

    expect(
        sse.uriProviders.last().queryParameters.containsKey('basis'), isFalse);

    second.stop();
    await secondSubscription.cancel();
  });
}
