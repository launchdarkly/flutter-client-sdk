// Platform-independent canonicalization tests for RFC 8785.
//
// These tests verify that JSON canonicalization produces identical results
// on both Dart VM (native) and Dart2JS (web) platforms.
//
// In CI, these tests run on both platforms:
// - VM platform: via `melos run test`
// - Chrome platform: via dedicated CI step (see .github/actions/ci/action.yml)
//
// To run locally on both platforms:
//   dart test test/serialization/canonicalize_json_platform_test.dart -p vm,chrome

import 'dart:convert';
import 'package:launchdarkly_dart_common/src/serialization/canonicalize_json.dart';
import 'package:test/test.dart';

void main() {
  group('Platform-independent canonicalization', () {
    // These tests verify that canonicalization produces identical results
    // on both Dart VM (native) and Dart2JS (web) platforms

    final testCases = <String, dynamic>{
      // Large numbers that could expose platform differences
      '1e30': 1e30,
      '1e21': 1e21,
      '1e-27': 1e-27,

      // Integer-valued doubles
      '56': 56.0,
      '42': 42,
      '0': 0.0,
      '-100': -100.0,

      // Fractional numbers
      '3.14': 3.14,
      '4.5': 4.50, // Should remove trailing zero
      '0.002': 2e-3,

      // Objects with mixed numeric types
      'object with numbers': {
        'int': 42,
        'double': 3.14,
        'large': 1e30,
        'small': 1e-27,
        'zero': 0.0,
      },

      // Arrays with various number types
      'array of numbers': [1, 2.5, 1e10, 1e-5, 0],

      // Edge cases
      'negative zero': -0.0,
      'negative large': -1e30,

      // Complex nested structure
      'complex': {
        'z': 99,
        'a': {
          'nested': 1e20,
          'values': [1, 2.5, 3.0],
        },
        'm': true,
      }
    };

    // Expected outputs (platform-independent)
    final expectedOutputs = <String, String>{
      '1e30': '1e+30',
      '1e21': '1e+21',
      '1e-27': '1e-27',
      '56': '56',
      '42': '42',
      '0': '0',
      '-100': '-100',
      '3.14': '3.14',
      '4.5': '4.5',
      '0.002': '0.002',
      'object with numbers':
          '{"double":3.14,"int":42,"large":1e+30,"small":1e-27,"zero":0}',
      'array of numbers': '[1,2.5,10000000000,0.00001,0]',
      'negative zero': '0',
      'negative large': '-1e+30',
      'complex': '{"a":{"nested":100000000000000000000,"values":[1,2.5,3]},"m":true,"z":99}',
    };

    for (var entry in testCases.entries) {
      test('${entry.key} produces platform-independent output', () {
        final result = canonicalizeJson(entry.value);
        final expected = expectedOutputs[entry.key];

        expect(result, equals(expected),
            reason:
                'Value ${entry.key} should produce the same output on all platforms');

        // Verify it's valid JSON by round-tripping
        expect(() => jsonDecode(result), returnsNormally,
            reason: 'Output should be valid JSON');
      });
    }

    test('large integer double (1.0) representation', () {
      // This test specifically checks behavior that could differ between platforms
      // On native: 1.0.toString() -> "1.0"
      // On web: 1.0.toString() -> "1"
      // Our canonicalization should always produce "1"

      final result = canonicalizeJson(1.0);
      expect(result, equals('1'),
          reason: 'Integer-valued doubles should not include decimal point');
    });

    test('scientific notation normalization', () {
      // Dart might produce "1E+30" on some platforms
      // We normalize to lowercase "1e+30"

      final result = canonicalizeJson(1e30);
      expect(result, equals('1e+30'));
      expect(result, isNot(contains('E')),
          reason: 'Should use lowercase e, not uppercase E');
    });

    test('complex structure produces deterministic output', () {
      final obj = {
        'numbers': [1e30, 56.0, 3.14],
        'nested': {
          'z': 'last',
          'a': 'first',
        },
      };

      // Should be the same on all platforms
      final result = canonicalizeJson(obj);
      expect(
          result,
          equals(
              '{"nested":{"a":"first","z":"last"},"numbers":[1e+30,56,3.14]}'));
    });

    test('lenient mode works consistently across platforms', () {
      final result1 = canonicalizeJson(double.nan, lenient: true);
      expect(result1, equals('null'));

      final result2 = canonicalizeJson(double.infinity, lenient: true);
      expect(result2, equals('null'));

      final result3 = canonicalizeJson(double.negativeInfinity, lenient: true);
      expect(result3, equals('null'));
    });
  });
}
