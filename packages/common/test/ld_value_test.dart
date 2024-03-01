import 'package:launchdarkly_dart_common/launchdarkly_dart_common.dart';
import 'package:test/test.dart';

// Most of the testing of LDValue is handled in ld_value_serialization_test
// and ld_context_test.

class Dummy {}

void main() {
  group('LDValues can be created using ofDynamic', () {
    test('ofDynamic produces LDValue.ofNull when given a type it cannot convert',
            () {
          expect(LDValue.ofDynamic(Dummy()), LDValue.ofNull());
        });

    test(
        'List containing values which cannot be converted are replaced with null',
            () {
          final converted = LDValue.ofDynamic(['test', true, Dummy(), 42]);
          expect(converted.length, 4);
          expect(converted.get(0).stringValue(), 'test');
          expect(converted.get(1).booleanValue(), isTrue);
          expect(converted.get(2).type, LDValueType.nullType);
          expect(converted.get(3).intValue(), 42);
        });

    test('Map containing values which cannot be converted are replaced with null',
            () {
          final converted = LDValue.ofDynamic(
              {'string': 'test', 'bool': true, 'dummy': Dummy(), 'int': 42});

          expect(converted.length, 4);
          expect(converted.getFor('string').stringValue(), 'test');
          expect(converted.getFor('bool').booleanValue(), isTrue);
          expect(converted.getFor('dummy').type, LDValueType.nullType);
          expect(converted.getFor('int').intValue(), 42);
        });

    test('Map containing keys which are not strings cannot be converted', () {
      final converted = LDValue.ofDynamic(
          {'string': 'test', 'bool': true, 17: 'dummy', 'int': 42});

      expect(converted, LDValue.ofNull());
    });
  });

  group('LDValues can be converted to dynamics', () {
    test('Numerics can be converted', () {
      int intValue = 12;
      double doubleValue = 42.42;
      final intLDValue = LDValue.ofNum(intValue);
      final doubleLDValue = LDValue.ofNum(doubleValue);

      expect(intLDValue.intValue(), intValue);
      expect(intLDValue.doubleValue(), 12.0);
      expect(doubleLDValue.doubleValue(), doubleValue);
      expect(doubleLDValue.intValue(), 42);
    });
  });

}
