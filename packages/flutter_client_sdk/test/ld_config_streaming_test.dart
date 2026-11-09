import 'package:flutter_test/flutter_test.dart';
import 'package:launchdarkly_flutter_client_sdk/launchdarkly_flutter_client_sdk.dart';

void main() {
  test('eventSource is null by default', () {
    final config = LDConfig('credential', AutoEnvAttributes.disabled);

    expect(config.eventSource, isNull);
  });

  test('eventSource is stored in the configuration', () {
    final config = LDConfig('credential', AutoEnvAttributes.disabled,
        eventSource: SSEClient.http);

    expect(config.eventSource, same(SSEClient.http));
  });
}
