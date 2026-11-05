import 'package:flutter_test/flutter_test.dart';
import 'package:launchdarkly_flutter_client_sdk/launchdarkly_flutter_client_sdk.dart';

void main() {
  test('useHttpStreamingOnWeb is off by default', () {
    final config = LDConfig('credential', AutoEnvAttributes.disabled);

    expect(config.useHttpStreamingOnWeb, isFalse);
  });

  test('useHttpStreamingOnWeb is stored in the configuration', () {
    final config = LDConfig('credential', AutoEnvAttributes.disabled,
        useHttpStreamingOnWeb: true);

    expect(config.useHttpStreamingOnWeb, isTrue);
  });
}
