import 'package:flutter_test/flutter_test.dart';
import 'package:launchdarkly_flutter_client_sdk/ld_value.dart';

void main() {
  group('Simple Types', testSimpleTypes);
  group('Array', testArray);
  group('Object', testObject);
  group('fromCodecValue', testFromCodec);
}

void testSimpleTypes() {
  test('normalize', () {
    LDValue valid = LDValue.ofString('abc');
    expect(LDValue.normalize(null), same(LDValue.ofNull()));
    expect(LDValue.normalize(LDValue.ofNull()), same(LDValue.ofNull()));
    expect(LDValue.normalize(valid), same(valid));
  });

  test('ofNull', () {
    LDValue ofNull = LDValue.ofNull();
    expect(ofNull.getType(), equals(LDValueType.NULL));
    expect(ofNull.codecValue(), isNull);
    expect(ofNull, same(LDValue.ofNull()));
    expect(ofNull == LDValue.ofNull(), isTrue);
  });

  test('ofBool', () {
    LDValue ofFalse = LDValue.ofBool(false);
    LDValue ofTrue = LDValue.ofBool(true);
    expect(ofFalse.getType(), equals(LDValueType.BOOLEAN));
    expect(ofTrue.getType(), equals(LDValueType.BOOLEAN));

    expect(ofFalse.booleanValue(), isFalse);
    expect(ofTrue.booleanValue(), isTrue);

    expect(ofFalse.codecValue(), equals(false));
    expect(ofTrue.codecValue(), equals(true));

    expect(ofFalse, same(LDValue.ofBool(false)));
    expect(ofTrue, same(LDValue.ofBool(true)));

    expect(ofFalse == LDValue.ofBool(false), isTrue);
    expect(ofFalse != LDValue.ofBool(true), isTrue);
    expect(ofTrue == LDValue.ofBool(true), isTrue);
    expect(ofTrue != LDValue.ofBool(false), isTrue);

    expect(LDValue.ofBool(null), same(LDValue.ofNull()));
  });

  test('ofNum', () {
    LDValue ofInt = LDValue.ofNum(5);
    LDValue ofDouble = LDValue.ofNum(8.75);
    expect(ofInt.getType(), equals(LDValueType.NUMBER));
    expect(ofDouble.getType(), equals(LDValueType.NUMBER));

    expect(ofInt.intValue(), 5);
    expect(ofDouble.intValue(), 8);
    expect(ofInt.doubleValue(), 5.0);
    expect(ofDouble.doubleValue(), 8.75);

    expect(ofInt.codecValue(), same(5));
    expect(ofDouble.codecValue(), same(8.75));

    expect(ofInt == LDValue.ofNum(5.0), isTrue);
    expect(ofDouble == LDValue.ofNum(8.75), isTrue);
    expect(ofInt != ofDouble, isTrue);

    expect(LDValue.ofNum(null), same(LDValue.ofNull()));
  });

  test('ofString', () {
    LDValue ofString = LDValue.ofString('abc');
    expect(ofString.getType(), equals(LDValueType.STRING));
    expect(ofString.stringValue(), equals('abc'));
    expect(ofString.codecValue(), equals('abc'));
    expect(ofString == LDValue.ofString('abc'), isTrue);
    expect(ofString != LDValue.ofString('def'), isTrue);
    expect(LDValue.ofString(null), same(LDValue.ofNull()));
  });
}

void testArray() {
  test('size', () {
    expect(LDValue.buildArray().build().size(), equals(0));
    expect(LDValue.buildArray().addNum(3).build().size(), equals(1));
    expect(LDValue.buildArray().addNum(3).addNum(2).build().size(), equals(2));
  });

  test('getType', () {
    expect(LDValue.buildArray().build().getType(), equals(LDValueType.ARRAY));
    expect(LDValue.buildArray().addBool(true).build().getType(), equals(LDValueType.ARRAY));
  });

  test('get', () {
    LDValue testArray = LDValue.buildArray().addNum(1).addBool(false).build();
    expect(testArray.get(0), equals(LDValue.ofNum(1)));
    expect(testArray.get(1), equals(LDValue.ofBool(false)));
  });

  test('values', () {
    LDValue testArray = LDValue.buildArray().addString('abc').addValue(LDValue.ofNull()).build();
    List<LDValue> listOf = List.of(testArray.values());
    expect(listOf.length, 2);
    expect(listOf[0], equals(LDValue.ofString('abc')));
    expect(listOf[1], same(LDValue.ofNull()));
  });

  test('builder add', () {
    LDValue array = LDValue.buildArray()
        .addValue(LDValue.ofNull())
        .addBool(false)
        .addNum(1.0)
        .addString('abc')
        .addValue(LDValue.buildArray().build())
        .addValue(LDValue.buildObject().build())
        .build();
    expect(array.values(),
        containsAllInOrder(
            [LDValue.ofNull()
              , LDValue.ofBool(false)
              , LDValue.ofNum(1.0)
              , LDValue.ofString('abc')
              , LDValue.buildArray().build()
              , LDValue.buildObject().build()]));
    expect(array.values().length, 6);
  });

  test('builder normalize', () {
    LDValue normalizedArray = LDValue.buildArray().addBool(null).addNum(null).addString(null).addValue(null).build();
    expect(normalizedArray.values(), containsAllInOrder([LDValue.ofNull(), LDValue.ofNull(), LDValue.ofNull(), LDValue.ofNull()]));
    expect(normalizedArray.values().length, 4);
  });

  test('builder reuse', () {
    LDValueArrayBuilder builder = LDValue.buildArray().addNum(1);
    LDValue builtFirst = builder.build();
    builder.addNum(2);
    LDValue builtSecond = builder.build();
    expect(builtFirst, equals(LDValue.buildArray().addNum(1).build()));
    expect(builtSecond, equals(LDValue.buildArray().addNum(1).addNum(2).build()));
    expect(builtSecond, isNot(same(builder.build())));
  });
}

void testObject() {
  test('size', () {
    expect(LDValue.buildObject().build().size(), equals(0));
    expect(LDValue.buildObject().addNum('a', 3).build().size(), equals(1));
    expect(LDValue.buildObject().addNum('a', 3).addNum('b', 2).build().size(), equals(2));
  });

  test('getType', () {
    expect(LDValue.buildObject().build().getType(), equals(LDValueType.OBJECT));
    expect(LDValue.buildObject().addBool('k', true).build().getType(), equals(LDValueType.OBJECT));
  });

  test('getFor', () {
    LDValue testObject = LDValue.buildObject().addNum('k1', 1).addBool('k2', false).build();
    expect(testObject.getFor('k1'), equals(LDValue.ofNum(1)));
    expect(testObject.getFor('k2'), equals(LDValue.ofBool(false)));
  });

  test('keys', () {
    LDValue testObject = LDValue.buildObject().addString('a', 'def').addValue('b', LDValue.ofNull()).build();
    expect(testObject.keys(), containsAll(['a', 'b']));
    expect(testObject.keys().length, 2);
  });

  test('values', () {
    LDValue testObject = LDValue.buildObject().addString('c', 'abc').addValue('d', LDValue.ofNull()).build();
    expect(testObject.values(), containsAll([LDValue.ofString('abc'), LDValue.ofNull()]));
    expect(testObject.values().length, 2);
  });

  test('builder add', () {
    LDValue object = LDValue.buildObject()
        .addValue('a', LDValue.ofNull())
        .addBool('b', false)
        .addNum('c', 1.0)
        .addString('d', 'abc')
        .addValue('e', LDValue.buildArray().build())
        .addValue('f', LDValue.buildObject().build())
        .build();
    expect(object.getFor('a'), same(LDValue.ofNull()));
    expect(object.getFor('b'), same(LDValue.ofBool(false)));
    expect(object.getFor('c'), equals(LDValue.ofNum(1.0)));
    expect(object.getFor('d'), equals(LDValue.ofString('abc')));
    expect(object.getFor('e'), equals(LDValue.buildArray().build()));
    expect(object.getFor('f'), equals(LDValue.buildObject().build()));
    expect(object.size(), equals(6));
  });

  test('builder normalize', () {
    LDValue normalizedObject = LDValue.buildObject()
        .addBool('a', null)
        .addNum('b', null)
        .addString('c', null)
        .addValue('d', null)
        .build();
    expect(normalizedObject.values(), containsAll([LDValue.ofNull(), LDValue.ofNull(), LDValue.ofNull(), LDValue.ofNull()]));
    expect(normalizedObject.values().length, 4);
  });

  test('builder reuse', () {
    LDValueObjectBuilder builder = LDValue.buildObject().addNum('k1', 1);
    LDValue builtFirst = builder.build();
    builder.addNum('k2', 2);
    LDValue builtSecond = builder.build();
    expect(builtFirst, equals(LDValue.buildObject().addNum('k1', 1).build()));
    expect(builtSecond, equals(LDValue.buildObject().addNum('k1', 1).addNum('k2', 2).build()));
    expect(builtSecond, isNot(same(builder.build())));
  });
}

void testFromCodec() {
  test('primitives', () {
    expect(LDValue.fromCodecValue(null), same(LDValue.ofNull()));
    expect(LDValue.fromCodecValue(false), same(LDValue.ofBool(false)));
    expect(LDValue.fromCodecValue(true), same(LDValue.ofBool(true)));
    expect(LDValue.fromCodecValue(5), equals(LDValue.ofNum(5)));
    expect(LDValue.fromCodecValue(8.75), equals(LDValue.ofNum(8.75)));
    expect(LDValue.fromCodecValue('abcd'), equals(LDValue.ofString('abcd')));

    // Invalid primitive
    expect(LDValue.fromCodecValue(DateTime.now()), same(LDValue.ofNull()));
  });

  test('primitive arrays', () {
    expect(LDValue.fromCodecValue([]), equals(LDValue.buildArray().build()));
    expect(LDValue.fromCodecValue([null]), equals(LDValue.buildArray().addValue(LDValue.ofNull()).build()));
    expect(LDValue.fromCodecValue([false, true]), equals(LDValue.buildArray().addBool(false).addBool(true).build()));
    expect(LDValue.fromCodecValue([1, 2]), equals(LDValue.buildArray().addNum(1).addNum(2).build()));
    expect(LDValue.fromCodecValue(['abc', 'def']), equals(LDValue.buildArray().addString('abc').addString('def').build()));
    expect(LDValue.fromCodecValue([null, true, 3.0, 'c']),
        equals(LDValue.buildArray().addValue(LDValue.ofNull()).addBool(true).addNum(3.0).addString('c').build()));

    // Invalid primitive in array
    expect(LDValue.fromCodecValue([DateTime.now()]), equals(LDValue.buildArray().addValue(LDValue.ofNull()).build()));
  });

  test('deep array', () {
    LDValue expected = LDValue.buildArray()
        .addValue(LDValue.buildArray().addNum(1).addNum(2).build())
        .addValue(LDValue.buildObject().addString('k', 'v').build())
        .addValue(LDValue.buildArray().addValue(LDValue.buildArray().addValue(LDValue.ofNull()).build()).build())
        .build();
    expect(LDValue.fromCodecValue([[1, 2], {'k': 'v'}, [[null]]]), equals(expected));
  });

  test('primitive objects', () {
    expect(LDValue.fromCodecValue({}), equals(LDValue.buildObject().build()));
    expect(LDValue.fromCodecValue({'n': null}), equals(LDValue.buildObject().addValue('n', LDValue.ofNull()).build()));
    expect(LDValue.fromCodecValue({'true': true, 'false': false}),
        equals(LDValue.buildObject().addBool('true', true).addBool('false', false).build()));
    expect(LDValue.fromCodecValue({'a': 1, 'b': 2}),
        equals(LDValue.buildObject().addNum('a', 1).addNum('b', 2).build()));
    expect(LDValue.fromCodecValue({'': 'abc', 'def': 'bar'}),
      equals(LDValue.buildObject().addString('', 'abc').addString('def', 'bar').build()));

    // Invalid primitive in object
    expect(LDValue.fromCodecValue({'k': DateTime.now()}), equals(LDValue.buildObject().addValue('k', LDValue.ofNull()).build()));
  });

  test('deep object', () {
    LDValue expected = LDValue.buildObject()
        .addValue('a', LDValue.buildObject().build())
        .addValue('b', LDValue.buildArray().addBool(false).addValue(LDValue.ofNull()).build())
        .addValue('c', LDValue.buildObject().addString('k', 'abc').build())
        .build();
    expect(LDValue.fromCodecValue({'a': {}, 'b': [false, null], 'c': {'k': 'abc'}}), equals(expected));
  });
}
