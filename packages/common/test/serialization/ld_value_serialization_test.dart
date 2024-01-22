import 'dart:convert';

import 'package:launchdarkly_dart_common/launchdarkly_dart_common.dart';
import 'package:test/test.dart';

void main() {
  group('given boolean values', () {
    for (var value in [true, false]) {
      test('it can serialize boolean: $value', () {
        var res = LDValueSerialization.toJson(LDValue.ofBool(value));
        expect(res, value);
      });

      test('it can deserialize boolean: $value', () {
        var res = LDValueSerialization.fromJson(jsonDecode('$value'));
        expect(res, LDValue.ofBool(value));
      });
    }
  });

  group('given numeric values', () {
    for (var value in [42, 3.145926]) {
      test('it can serialize number: $value', () {
        var res = LDValueSerialization.toJson(LDValue.ofNum(value));
        expect(res, value);
      });

      test('it can deserialize number: $value', () {
        var res = LDValueSerialization.fromJson(jsonDecode('$value'));
        expect(res, LDValue.ofNum(value));
      });
    }
  });

  group('given string values', () {
    for (var value in ['cheese', 'ham']) {
      test('it can serialize string: $value', () {
        var res = LDValueSerialization.toJson(LDValue.ofString(value));
        expect(res, value);
      });

      test('it can deserialize string: $value', () {
        var res = LDValueSerialization.fromJson(jsonDecode('"$value"'));
        expect(res, LDValue.ofString(value));
      });
    }
  });

  group('given a complex array', () {
    final allTypesArray = LDValue.buildArray()
        .addValue(LDValue.ofNull())
        .addBool(true)
        .addNum(42)
        .addString('forty-two')
        .addValue(LDValue.buildObject().addString('potato', 'cheese').build())
        .addValue(LDValue.buildArray().addString('nested').build())
        .build();

    test('it can serialize arrays', () {
      var res = LDValueSerialization.toJson(allTypesArray);
      expect(res is List<dynamic>, true);
      var list = res as List<dynamic>;
      expect(list[0] == null, true);
      expect(list[1], true);
      expect(list[2], 42);
      expect(list[3], 'forty-two');
      expect(list[4]['potato'], 'cheese');
      expect(list[5][0], 'nested');
    });

    test('it can deserialize arrays', () {
      var stringJson =
          '[null, true, 42, "forty-two", {"potato": "cheese"}, ["nested"]]';
      var value = LDValueSerialization.fromJson(jsonDecode(stringJson));

      expect(value, allTypesArray);
    });
  });

  group('given a complex object', () {
    final allTypesObject = LDValue.buildObject()
        .addValue('null', LDValue.ofNull())
        .addBool('bool', true)
        .addNum('num', 42)
        .addString('string', 'forty-two')
        .addValue('object',
            LDValue.buildObject().addString('potato', 'cheese').build())
        .addValue('array', LDValue.buildArray().addString('nested').build())
        .build();

    test('it can serialize objects', () {
      var res = LDValueSerialization.toJson(allTypesObject);
      expect(res is Map<String, dynamic>, true);
      var map = res as Map<String, dynamic>;
      expect(map['null'] == null, true);
      expect(map['bool'], true);
      expect(map['num'], 42);
      expect(map['string'], 'forty-two');
      expect(map['object']['potato'], 'cheese');
      expect(map['array'][0], 'nested');
    });

    test('it can deserialize objects', () {
      var stringJson = '{"null": null, "bool": true, "num": 42, '
          '"string": "forty-two", "object": {"potato":"cheese"}, '
          '"array": ["nested"]}';
      var value = LDValueSerialization.fromJson(jsonDecode(stringJson));

      expect(value, allTypesObject);
    });
  });
}
