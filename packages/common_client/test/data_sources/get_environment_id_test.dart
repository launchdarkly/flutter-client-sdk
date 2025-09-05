import 'package:test/test.dart';
import 'package:launchdarkly_common_client/src/data_sources/get_environment_id.dart';

void main() {
  test('returns environment ID from headers', () {
    final headers = {'x-ld-envid': 'test-env-123'};
    final result = getEnvironmentId(headers);
    expect(result, 'test-env-123');
  });

  test('returns null when header is missing', () {
    final headers = <String, String>{'other-header': 'value'};
    final result = getEnvironmentId(headers);
    expect(result, null);
  });

  test('returns null when headers are null', () {
    final result = getEnvironmentId(null);
    expect(result, null);
  });

  test('returns null when headers are empty', () {
    final headers = <String, String>{};
    final result = getEnvironmentId(headers);
    expect(result, null);
  });

  test('handles multiple values for environment id', () {
    // Services should only send a single environment ID, but if we did get
    // multiple we want it to be handled safely.
    final headers = <String, String>{'x-ld-envid': 'envid-a, envid-b'};
    final result = getEnvironmentId(headers);
    expect(result, 'envid-a');
  });

  test('handles envid is empty string', () {
    // Services shouldn't send an empty string, but we want to ensure it
    // doesn't cause any runtime issue.
    final headers = <String, String>{'x-ld-envid': ''};
    final result = getEnvironmentId(headers);
    expect(result, '');
  });
}
