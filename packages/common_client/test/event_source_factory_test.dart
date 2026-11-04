import 'dart:async';

import 'package:launchdarkly_common_client/launchdarkly_common_client.dart';
import 'package:test/test.dart';

import 'mock_eventprocessor.dart';

final class _TestConfig extends LDCommonConfig {
  _TestConfig(super.sdkCredential, super.autoEnvAttributes,
      {super.dataSystem, super.eventSourceFactory, super.serviceEndpoints});
}

LDCommonClient _makeClient(LDCommonConfig config) => LDCommonClient(
    config,
    CommonPlatform(),
    LDContextBuilder().kind('user', 'bob').build(),
    DiagnosticSdkData(name: '', version: ''),
    eventProcessorFactory: ({
      required allAttributesPrivate,
      required analyticsEventsPath,
      required client,
      required diagnosticEventsPath,
      required diagnosticRecordingInterval,
      diagnosticsManager,
      required endpoints,
      required eventCapacity,
      required flushInterval,
      required globalPrivateAttributes,
      required indexEvents,
      required logger,
    }) =>
        MockEventProcessor());

void main() {
  // The streaming endpoint is unreachable so a test never leaves the machine.
  final endpoints = ServiceEndpoints.custom(
      polling: 'http://localhost:1',
      streaming: 'http://localhost:1',
      events: 'http://localhost:1');

  Future<List<SSEClientRequest>> startAndCollect(
      LDCommonConfig Function(SSEClientFactory factory) makeConfig) async {
    final requests = <SSEClientRequest>[];
    final firstRequest = Completer<void>();
    final client = _makeClient(makeConfig((request) {
      requests.add(request);
      if (!firstRequest.isCompleted) {
        firstRequest.complete();
      }
      return SSEClient.testClient(request.uriProvider(), request.eventTypes);
    }));
    unawaited(client.start());
    // Streaming starts after the identify that start performs.
    await firstRequest.future.timeout(const Duration(seconds: 5));
    await client.close();
    return requests;
  }

  test('the FDv1 streaming data source uses the configured factory', () async {
    final requests = await startAndCollect((factory) => _TestConfig(
        'client-side-id', AutoEnvAttributes.disabled,
        serviceEndpoints: endpoints, eventSourceFactory: factory));

    expect(requests, isNotEmpty);
    expect(requests.first.eventTypes, containsAll(['put', 'patch', 'delete']));
  });

  test('the FDv2 streaming data source uses the configured factory', () async {
    final requests = await startAndCollect(
        (factory) => _TestConfig('client-side-id', AutoEnvAttributes.disabled,
            serviceEndpoints: endpoints,
            dataSystem: DataSystemConfig(connectionModes: {
              ConnectionModeId.streaming: const ModeDefinition(
                  initializers: [], synchronizers: [StreamingSynchronizer()]),
            }),
            eventSourceFactory: factory));

    expect(requests, isNotEmpty);
    expect(requests.first.eventTypes, contains('server-intent'));
  });
}
