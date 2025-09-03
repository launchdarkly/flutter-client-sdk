import 'package:test/test.dart';
import 'package:launchdarkly_common_client/src/data_sources/get_environment_id.dart';

void main() {
  group('getEnvironmentId', () {
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

    test('handles case-sensitive header name correctly', () {
      final headers = {'X-LD-ENVID': 'test-env-123'};
      final result = getEnvironmentId(headers);
      expect(result, null);
    });

    test('handles environment ID with special characters', () {
      final headers = {'x-ld-envid': 'env-123-abc-456'};
      final result = getEnvironmentId(headers);
      expect(result, 'env-123-abc-456');
    });
  });
}
