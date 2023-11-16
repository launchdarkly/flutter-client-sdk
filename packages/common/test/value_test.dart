import 'dart:math';

import 'package:test/test.dart';
import 'package:launchdarkly_dart_common/ld_common.dart';

void main() {
  group('null values', () {
    final nullValue = LDValue.ofNull();

    test('is of correct type', () {
      expect(nullValue.type, LDValueType.nullType);
    });

    test('can compare values', () {
      expect(nullValue, LDValue.ofNull());
    });

    test('null values are not equal to other types', () {
      expect(nullValue, isNot(equals(LDValue.ofNum(0))));
      expect(nullValue, isNot(equals(LDValue.ofBool(false))));
      expect(nullValue, isNot(equals(LDValue.ofString(''))));
      expect(nullValue, isNot(equals(LDValue.buildArray().build())));
      expect(nullValue, isNot(equals(LDValue.buildObject().build())));
    });

    test('has equal hash codes', () {
      expect(LDValue.ofNull(), LDValue.ofNull());
    });
  });

  group('boolean values', () {
    final trueValue = LDValue.ofBool(true);
    final falseValue = LDValue.ofBool(false);
    test('values are of correct type', () {
      expect(trueValue.type, LDValueType.boolean);
      expect(falseValue.type, LDValueType.boolean);
    });

    test('contains the correct boolean value', () {
      expect(trueValue.booleanValue(), true);
      expect(falseValue.booleanValue(), false);
    });

    test('can compare values', () {
      final secondTrueValue = LDValue.ofBool(true);
      final secondFalseValue = LDValue.ofBool(false);

      expect(trueValue, trueValue);
      expect(falseValue, falseValue);

      expect(trueValue, isNot(equals(falseValue)));
      expect(falseValue, isNot(equals(trueValue)));

      expect(trueValue, secondTrueValue);
      expect(falseValue, secondFalseValue);
    });

    test('can get hash codes', () {
      expect(trueValue.hashCode, LDValue.ofBool(true).hashCode);
      expect(falseValue.hashCode, LDValue.ofBool(false).hashCode);

      expect(trueValue.hashCode, isNot(equals(falseValue.hashCode)));
    });
  });

  group('number values', () {
    final whole = LDValue.ofNum(42);
    final fractional = LDValue.ofNum(pi);

    test('is of the correct type', () {
      expect(whole.type, LDValueType.number);
      expect(fractional.type, LDValueType.number);
    });

    test('contains the correct numeric values', () {
      expect(whole.intValue(), 42);
      expect(whole.doubleValue(), 42);

      expect(fractional.intValue(), 3);
      expect(fractional.doubleValue(), closeTo(pi, 1e-12));
    });

    test('can compare values', () {
      expect(whole, LDValue.ofNum(42));
      expect(fractional, LDValue.ofNum(pi));

      expect(whole, isNot(equals(fractional)));
    });

    test('can get hash codes', () {
      expect(whole.hashCode, LDValue.ofNum(42).hashCode);
      expect(fractional.hashCode, LDValue.ofNum(pi).hashCode);

      expect(whole.hashCode, isNot(equals(fractional.hashCode)));
    });
  });

  group('string values', () {
    final stringValue = LDValue.ofString('value1');

    test('is the correct type', () {
      expect(stringValue.type, LDValueType.string);
    });

    test('contains the correct value', () {
      expect(stringValue.stringValue(), 'value1');
    });

    test('can compare string values', () {
      expect(stringValue, stringValue);
      expect(LDValue.ofString('a'), LDValue.ofString('a'));
      expect(LDValue.ofString('a'), isNot(equals(LDValue.ofString('b'))));
    });

    test('can get hash codes', () {
      expect(stringValue.hashCode, stringValue.hashCode);
      expect(LDValue.ofString('a').hashCode, LDValue.ofString('a').hashCode);
      expect(LDValue.ofString('a').hashCode,
          isNot(equals(LDValue.ofString('b').hashCode)));
    });
  });

  group('array values', () {
    final emptyArray = LDValue.buildArray().build();

    final allTypesArray = LDValue.buildArray()
        .addValue(LDValue.ofNull())
        .addBool(true)
        .addNum(42)
        .addString('forty-two')
        .addValue(LDValue.buildObject().addString('potato', 'cheese').build())
        .addValue(LDValue.buildArray().addString('nested').build())
        .build();

    final secondAllTypes = LDValue.buildArray()
        .addValue(LDValue.ofNull())
        .addBool(true)
        .addNum(42)
        .addString('forty-two')
        .addValue(LDValue.buildObject().addString('potato', 'cheese').build())
        .addValue(LDValue.buildArray().addString('nested').build())
        .build();

    test('is of correct type', () {
      expect(emptyArray.type, LDValueType.array);
      expect(allTypesArray.type, LDValueType.array);
    });

    test('can get by index', () {
      expect(allTypesArray.get(0), LDValue.ofNull());
      expect(allTypesArray.get(1), LDValue.ofBool(true));
      expect(allTypesArray.get(2), LDValue.ofNum(42));
      expect(allTypesArray.get(3), LDValue.ofString('forty-two'));
      expect(allTypesArray.get(4),
          LDValue.buildObject().addString('potato', 'cheese').build());
      expect(allTypesArray.get(5),
          LDValue.buildArray().addString('nested').build());
    });

    test('can get all values', () {
      expect(
          allTypesArray.values,
          containsAllInOrder([
            LDValue.ofNull(),
            LDValue.ofBool(true),
            LDValue.ofNum(42),
            LDValue.ofString('forty-two'),
            LDValue.buildObject().addString('potato', 'cheese').build(),
            LDValue.buildArray().addString('nested').build()
          ]));
    });

    test('can get the size of an array', () {
      expect(emptyArray.length, 0);
      expect(allTypesArray.length, 6);
    });

    test('can compare values', () {
      expect(emptyArray, LDValueArrayBuilder().build());
      expect(allTypesArray, secondAllTypes);
      expect(allTypesArray, isNot(equals(emptyArray)));
    });

    test('can get hash codes', () {
      expect(emptyArray.hashCode, LDValueArrayBuilder().build().hashCode);
      expect(allTypesArray.hashCode, secondAllTypes.hashCode);
      expect(allTypesArray.hashCode, isNot(equals(emptyArray.hashCode)));
    });
  });

  group('object values', () {
    final emptyObject = LDValue.buildObject().build();

    final allTypesObject = LDValue.buildObject()
        .addValue('null', LDValue.ofNull())
        .addBool('bool', true)
        .addNum('num', 42)
        .addString('string', 'forty-two')
        .addValue('object',
            LDValue.buildObject().addString('potato', 'cheese').build())
        .addValue('array', LDValue.buildArray().addString('nested').build())
        .build();

    final secondAllTypesObject = LDValue.buildObject()
        .addValue('null', LDValue.ofNull())
        .addBool('bool', true)
        .addNum('num', 42)
        .addString('string', 'forty-two')
        .addValue('object',
            LDValue.buildObject().addString('potato', 'cheese').build())
        .addValue('array', LDValue.buildArray().addString('nested').build())
        .build();

    test('is of correct type', () {
      expect(emptyObject.type, LDValueType.object);
      expect(allTypesObject.type, LDValueType.object);
    });

    test('can get by key', () {
      expect(allTypesObject.getFor('null'), LDValue.ofNull());
      expect(allTypesObject.getFor('bool'), LDValue.ofBool(true));
      expect(allTypesObject.getFor('num'), LDValue.ofNum(42));
      expect(allTypesObject.getFor('string'), LDValue.ofString('forty-two'));
      expect(allTypesObject.getFor('object'),
          LDValue.buildObject().addString('potato', 'cheese').build());
      expect(allTypesObject.getFor('array'),
          LDValue.buildArray().addString('nested').build());
    });

    test('can get all values', () {
      expect(
          allTypesObject.values,
          containsAllInOrder([
            LDValue.ofNull(),
            LDValue.ofBool(true),
            LDValue.ofNum(42),
            LDValue.ofString('forty-two'),
            LDValue.buildObject().addString('potato', 'cheese').build(),
            LDValue.buildArray().addString('nested').build()
          ]));
    });

    test('can get all keys', () {
      expect(
          allTypesObject.keys,
          containsAllInOrder(
              ['null', 'bool', 'num', 'string', 'object', 'array']));
    });

    test('can get the size of an object', () {
      expect(emptyObject.length, 0);
      expect(allTypesObject.length, 6);
    });

    test('can compare values', () {
      expect(emptyObject, LDValueObjectBuilder().build());
      expect(allTypesObject, secondAllTypesObject);
      expect(allTypesObject, isNot(equals(emptyObject)));
    });

    test('can get hash codes', () {
      expect(emptyObject.hashCode, LDValueObjectBuilder().build().hashCode);
      expect(allTypesObject.hashCode, secondAllTypesObject.hashCode);
      expect(allTypesObject.hashCode, isNot(equals(emptyObject.hashCode)));
    });
  });

  test('empty hash codes are not equal', () {
    expect(LDValueObjectBuilder().build().hashCode,
        isNot(equals(LDValueArrayBuilder().build().hashCode)));
  });
}
