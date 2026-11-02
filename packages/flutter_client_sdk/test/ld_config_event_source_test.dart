import 'package:flutter_test/flutter_test.dart';
import 'package:launchdarkly_flutter_client_sdk/launchdarkly_flutter_client_sdk.dart';

void main() {
  test('eventSourceFactory is not set by default', () {
    final config = LDConfig('credential', AutoEnvAttributes.disabled);

    expect(config.eventSourceFactory, isNull);
  });

  test('eventSourceFactory is stored in the configuration', () {
    SSEClient factory(SSEClientRequest request) =>
        SSEClient.http(request.uriProvider(), request.eventTypes,
            headers: request.headers,
            body: request.body,
            httpMethod: request.method,
            logger: request.logger,
            uriProvider: request.uriProvider);

    final config = LDConfig('credential', AutoEnvAttributes.disabled,
        eventSourceFactory: factory);

    expect(config.eventSourceFactory, same(factory));
  });
}
