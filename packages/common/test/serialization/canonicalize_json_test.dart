import 'dart:convert';
import 'dart:io';
import 'package:test/test.dart';
import 'package:launchdarkly_dart_common/src/serialization/canonicalize_json.dart';

void main() {
  group('canonicalize_json', () {
    // Test with data files from testdata directory
    final testInputDir =
        Directory('test/serialization/testdata/input');
    final testOutputDir =
        Directory('test/serialization/testdata/output');

    if (testInputDir.existsSync()) {
      final testFiles = testInputDir
          .listSync()
          .whereType<File>()
          .where((file) => file.path.endsWith('.json'))
          .toList();

      for (var inputFile in testFiles) {
        final filename = inputFile.uri.pathSegments.last;
        test('should correctly canonicalize $filename', () {
          final outputFile = File('${testOutputDir.path}/$filename');

          final inputData = jsonDecode(inputFile.readAsStringSync());
          final expectedOutput = outputFile.readAsStringSync();

          final result = canonicalizeJson(inputData);

          expect(result, equals(expectedOutput));
        });
      }
    }

    test('handles basic arrays', () {
      final input = [];
      const expected = '[]';
      final result = canonicalizeJson(input);
      expect(result, equals(expected));
    });

    test('handles arrays of null/undefined', () {
      final input = [null, null];
      const expected = '[null,null]';
      final result = canonicalizeJson(input);
      expect(result, equals(expected));
    });

    test('handles objects with numeric keys', () {
      final input = {
        1: 'one',
        2: 'two',
      };
      const expected = '{"1":"one","2":"two"}';
      final result = canonicalizeJson(input);
      expect(result, equals(expected));
    });

    test('handles objects with string numeric keys', () {
      final input = {
        '1': 'one',
        '2': 'two',
      };
      const expected = '{"1":"one","2":"two"}';
      final result = canonicalizeJson(input);
      expect(result, equals(expected));
    });

    test('should throw an error for objects with cycles', () {
      final a = <String, dynamic>{};
      final b = <String, dynamic>{'a': a};
      a['b'] = b;

      expect(() => canonicalizeJson(a), throwsArgumentError);
    });

    test('handles nested objects with sorted keys', () {
      final input = {
        'z': 1,
        'a': 2,
        'm': {'z': 3, 'a': 4}
      };
      const expected = '{"a":2,"m":{"a":4,"z":3},"z":1}';
      final result = canonicalizeJson(input);
      expect(result, equals(expected));
    });

    test('handles mixed types in arrays', () {
      final input = [1, 'string', true, null, {'key': 'value'}];
      const expected = '[1,"string",true,null,{"key":"value"}]';
      final result = canonicalizeJson(input);
      expect(result, equals(expected));
    });

    test('handles empty objects', () {
      final input = {};
      const expected = '{}';
      final result = canonicalizeJson(input);
      expect(result, equals(expected));
    });

    test('handles basic types', () {
      expect(canonicalizeJson(42), equals('42'));
      expect(canonicalizeJson(3.14), equals('3.14'));
      expect(canonicalizeJson('hello'), equals('"hello"'));
      expect(canonicalizeJson(true), equals('true'));
      expect(canonicalizeJson(false), equals('false'));
      expect(canonicalizeJson(null), equals('null'));
    });

    test('handles unicode strings', () {
      final input = {'emoji': '😀', 'text': 'Hello'};
      final result = canonicalizeJson(input);
      final decoded = jsonDecode(result);
      expect(decoded['emoji'], equals('😀'));
      expect(decoded['text'], equals('Hello'));
    });

    test('handles numbers with scientific notation', () {
      final input = {'num': 1e10};
      final result = canonicalizeJson(input);
      expect(result, contains('10000000000'));
    });

    test('handles nested arrays', () {
      final input = [
        [1, 2],
        [3, 4]
      ];
      const expected = '[[1,2],[3,4]]';
      final result = canonicalizeJson(input);
      expect(result, equals(expected));
    });

    group('RFC 8785 compliance', () {
      test('throws error for NaN in strict mode', () {
        expect(
            () => canonicalizeJson(double.nan), throwsA(isA<ArgumentError>()));

        expect(() => canonicalizeJson({'value': double.nan}),
            throwsA(isA<ArgumentError>()));
      });

      test('throws error for positive Infinity in strict mode', () {
        expect(() => canonicalizeJson(double.infinity),
            throwsA(isA<ArgumentError>()));

        expect(() => canonicalizeJson({'value': double.infinity}),
            throwsA(isA<ArgumentError>()));
      });

      test('throws error for negative Infinity in strict mode', () {
        expect(() => canonicalizeJson(double.negativeInfinity),
            throwsA(isA<ArgumentError>()));

        expect(() => canonicalizeJson({'value': double.negativeInfinity}),
            throwsA(isA<ArgumentError>()));
      });

      test('replaces NaN with null in lenient mode', () {
        expect(canonicalizeJson(double.nan, lenient: true), equals('null'));

        expect(canonicalizeJson({'value': double.nan}, lenient: true),
            equals('{"value":null}'));

        expect(canonicalizeJson([double.nan, 1, 2], lenient: true),
            equals('[null,1,2]'));
      });

      test('replaces positive Infinity with null in lenient mode', () {
        expect(
            canonicalizeJson(double.infinity, lenient: true), equals('null'));

        expect(canonicalizeJson({'value': double.infinity}, lenient: true),
            equals('{"value":null}'));

        expect(canonicalizeJson([1, double.infinity, 2], lenient: true),
            equals('[1,null,2]'));
      });

      test('replaces negative Infinity with null in lenient mode', () {
        expect(canonicalizeJson(double.negativeInfinity, lenient: true),
            equals('null'));

        expect(
            canonicalizeJson({'value': double.negativeInfinity}, lenient: true),
            equals('{"value":null}'));

        expect(canonicalizeJson([1, 2, double.negativeInfinity], lenient: true),
            equals('[1,2,null]'));
      });

      test('uses lowercase e for scientific notation', () {
        // Test very large number
        final result = canonicalizeJson(1.0e30);
        expect(result, contains('e'));
        expect(result, isNot(contains('E')));

        // Test very small number
        final result2 = canonicalizeJson(1.0e-27);
        expect(result2, contains('e'));
        expect(result2, isNot(contains('E')));
      });

      test('large integer-valued doubles use scientific notation', () {
        // Per RFC 8785/ECMA-262: integers with magnitude >= 10^21 must use
        // scientific notation, not plain decimal (even if they could be
        // represented as integers)

        // 1e30 is an integer value, but must use scientific notation
        expect(canonicalizeJson(1e30), equals('1e+30'));

        // At the 10^21 threshold
        expect(canonicalizeJson(1e21), equals('1e+21'));

        // Just below the threshold should work as integer (if representable)
        // Note: actual behavior depends on double precision limits
        final largeInt = 999999999999999.0; // Well below 10^21
        expect(canonicalizeJson(largeInt), equals('999999999999999'));
      });

      test('properly escapes control characters', () {
        // ASCII control characters should use lowercase hex escapes
        final input = {
          'tab': '\t',
          'newline': '\n',
          'carriage': '\r',
          'null': '\u0000',
          'backspace': '\b',
          'formfeed': '\f'
        };
        final result = canonicalizeJson(input);

        // Verify common escape sequences are used
        expect(result, contains(r'\t'));
        expect(result, contains(r'\n'));
        expect(result, contains(r'\r'));
        expect(result, contains(r'\b'));
        expect(result, contains(r'\f'));
      });

      test('properly escapes quote and backslash', () {
        final input = {
          'quote': '"hello"',
          'backslash': 'path\\to\\file',
          'both': 'say "hi" at c:\\temp'
        };
        final result = canonicalizeJson(input);

        expect(result, contains(r'\"'));
        expect(result, contains(r'\\'));
      });

      test('preserves Unicode characters as-is (no normalization)', () {
        // RFC 8785 requires preserving Unicode "as is"
        final input = {
          'emoji': '😀',
          'accented': 'café',
          'japanese': '日本語',
          'combined': 'A\u030a' // A with combining ring above
        };
        final result = canonicalizeJson(input);
        final decoded = jsonDecode(result);

        // Characters should round-trip correctly
        expect(decoded['emoji'], equals('😀'));
        expect(decoded['accented'], equals('café'));
        expect(decoded['japanese'], equals('日本語'));
        expect(decoded['combined'], equals('A\u030a'));
      });

      test('no whitespace between tokens', () {
        final input = {'a': 1, 'b': [2, 3], 'c': {'d': 4}};
        final result = canonicalizeJson(input);

        // Should not contain spaces, newlines, or tabs
        expect(result, isNot(contains(' ')));
        expect(result, isNot(contains('\n')));
        expect(result, isNot(contains('\t')));
      });

      test('lexicographic key ordering', () {
        final input = {
          'aa': 1,
          'a': 2,
          '': 3,
          'ab': 4,
          'b': 5,
        };
        final result = canonicalizeJson(input);

        // Keys should appear in order: "", "a", "aa", "ab", "b"
        final emptyPos = result.indexOf('""');
        final aPos = result.indexOf('"a"');
        final aaPos = result.indexOf('"aa"');
        final abPos = result.indexOf('"ab"');
        final bPos = result.indexOf('"b"');

        expect(emptyPos, lessThan(aPos));
        expect(aPos, lessThan(aaPos));
        expect(aaPos, lessThan(abPos));
        expect(abPos, lessThan(bPos));
      });
    });
  });
}
