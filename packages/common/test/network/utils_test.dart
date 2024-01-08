import 'package:launchdarkly_dart_common/ld_common.dart';
import 'package:launchdarkly_dart_common/src/network/utils.dart';
import 'package:test/test.dart';

void main() {
  test('it joins URLs with a forward slash', () {
    expect(appendPath('this', '/that'), 'this/that');
  });

  test('it trims a trailing slash on a base URL', () {
    expect(appendPath('this', '/that'), 'this/that');
  });

  group('given globally recoverable errors', () {
    for (var status in [300, 400, 408, 429, 500]) {
      test('it reports the status is recoverable: $status', () {
        expect(isHttpGloballyRecoverable(status), isTrue);
      });
    }
  });

  group('given locally recoverable errors', () {
    for (var status in [300, 400, 408, 413, 429, 500]) {
      test('it reports the status is recoverable: $status', () {
        expect(isHttpLocallyRecoverable(status), isTrue);
      });
    }
  });

  group('given non-recoverable errors', () {
    for (var status in [401, 404, 499]) {
      test('it reports the status is not recoverable: $status', () {
        expect(isHttpGloballyRecoverable(status), isFalse);
      });
    }
  });

  test('it hashes and encodes input', () {
    expect(urlSafeSha256Hash('hashThis!'),
        'sfXg3HewbCAVNQLJzPZhnFKntWYvN0nAYyUWFGy24dQ=');
    expect(urlSafeSha256Hash('OhYeah?HashThis!!!'),
        'KzDwVRpvTuf__jfMK27M4OMpIRTecNcJoaffvAEi-as=');
  });

  test('it url safe encodes input', () {
    expect(urlSafeBase64String('{"key":"foo>bar__?"}'),
        'eyJrZXkiOiJmb28-YmFyX18_In0=');
  });

  test('it makes a header tag from application info', () {
    final info = ApplicationInfo(
        applicationId: 'id',
        applicationName: 'name',
        applicationVersionName: 'versionName');

    final result = info.asHeaderMap();
    expect(result['X-LaunchDarkly-Tags'],
        'application-id/id application-name/name application-version-name/versionName');
  });
}
