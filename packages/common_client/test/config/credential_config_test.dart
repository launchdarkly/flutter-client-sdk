import 'package:launchdarkly_common_client/src/config/defaults/io_config.dart'
    as io;
import 'package:launchdarkly_common_client/src/config/defaults/js_config.dart'
    as js;
import 'package:test/test.dart';

void main() {
  group('io CredentialConfig', () {
    final config = io.CredentialConfig();

    test('base headers carry the user agent and the credential', () {
      expect(
          config.baseHeaders('the-mobile-key', 'Sdk/1.0'),
          equals({
            'user-agent': 'Sdk/1.0',
            'authorization': 'the-mobile-key',
          }));
    });

    test('no auth query parameters; every transport supports headers', () {
      expect(config.authQueryParameters('the-mobile-key'), isEmpty);
    });

    test(
        'no environment ID fallback; a mobile key does not identify an '
        'environment', () {
      expect(config.environmentIdFallback('the-mobile-key'), isNull);
    });
  });

  group('web CredentialConfig', () {
    final config = js.CredentialConfig();

    test(
        'base headers carry the vendor user agent and no authorization '
        'header', () {
      expect(
          config.baseHeaders('the-client-side-id', 'Sdk/1.0'),
          equals({
            'x-launchdarkly-user-agent': 'Sdk/1.0',
          }),
          reason: 'the events service CORS configuration does not permit '
              'the authorization header from browsers');
    });

    test('auth query parameter for transports that cannot send headers', () {
      expect(config.authQueryParameters('the-client-side-id'),
          equals({'auth': 'the-client-side-id'}));
    });

    test('the client-side ID serves as the environment ID fallback', () {
      expect(config.environmentIdFallback('the-client-side-id'),
          equals('the-client-side-id'));
    });
  });
}
