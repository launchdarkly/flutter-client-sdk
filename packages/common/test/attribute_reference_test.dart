import 'package:test/test.dart';
import 'package:launchdarkly_dart_common/ld_common.dart';

void main() {
  group('given invalid attribute references', () {
    final references = [
      '/',
      '',
      '//',
      '/toast/', // Should not have trailing slash.
      '/~2' // Only ~1 and ~2 are valid escape sequences
    ];
    for (final ref in references) {
      test('the created reference should be invalid for "$ref"', () {
        expect(AttributeReference(ref).valid, false);
      });
    }
  });

  group('given valid attribute references', () {
    final testVectors = {
      '/a/b': ['a', 'b'],
      '/~1~0~1': ['/~/'],
      '/a/~1b/~0c': ['a', '/b', '~c'],
      '/a': ['a'],
      'a': ['a'],
      'a~1b~0c': ['a~1b~0c'],
      '/~01': ['~1'],
      'a/b': ['a/b']
    };

    for (final vector in testVectors.entries) {
      test('it produces the expected components for "${vector.key}"', () {
        expect(AttributeReference(vector.key).components, vector.value);
      });
    }
  });

  group('given literals', () {
    final testVectors = {
      '/a/b': ['/a/b', '/~1a~1b'],
      '/~1~0~1': ['/~1~0~1', '/~1~01~00~01'],
      '/a/~1b/~0c': ['/a/~1b/~0c', '/~1a~1~01b~1~00c'],
      '/a': ['/a', '/~1a'],
      'a': ['a', 'a'],
      'a~1b~0c': ['a~1b~0c', 'a~1b~0c'],
      '/~01': ['/~01', '/~1~001'],
      'a/b': ['a/b', 'a/b']
    };

    for (final vector in testVectors.entries) {
      final attrRef = AttributeReference.fromLiteral(vector.key);
      test('it produces the expected components for "${vector.key}"', () {
        expect(attrRef.components[0], vector.value[0]);
        expect(attrRef.components.length, 1);
      });

      test('it produces the expected redactionName for "${vector.key}"', () {
        expect(attrRef.redactionName, vector.value[1]);
      });
    }
  });

  test('it finds two references equal when they are', () {
    final abc = AttributeReference('/a/b/c');
    final abc2 = AttributeReference('/a/b/c');
    expect(abc, abc2);
  });

  test('it finds two references equal when they are', () {
    final abc = AttributeReference('/a/b/c');
    final abc2 = AttributeReference('/a/b/c');
    expect(abc, abc2);

    final obscure = AttributeReference.fromLiteral('/~1~0~1');
    final obscure2 = AttributeReference('/~1~01~00~01');
    expect(obscure, obscure2);
  });

  test('finds components in different orders not equal', () {
    final abc = AttributeReference('/a/b/c');
    final bac = AttributeReference('/b/a/c');
    expect(abc, isNot(equals(bac)));
  });

  group('given components', () {
    final testVectors = {
      '/a/b': ['a', 'b'],
      '/~1~0~1': ['/~/'],
      '/a/~1b/~0c': ['a', '/b', '~c'],
      '/a': ['a'],
      '/a~01b~00c': ['a~1b~0c'],
      '/~01': ['~1'],
      '/a~1b': ['a/b']
    };

    for (final vector in testVectors.entries) {
      test('it produces the expected redaction string for "${vector.value}"', () {
        expect(AttributeReference.fromComponents(vector.value).redactionName, vector.key);
      });
    }
  });
}
