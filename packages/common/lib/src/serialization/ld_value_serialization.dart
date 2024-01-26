import '../ld_value.dart';

final class LDValueSerialization {
  static LDValue fromJson(dynamic json) {
    if (json is bool) {
      return LDValue.ofBool(json);
    }
    if (json is num) {
      return LDValue.ofNum(json);
    }
    if (json is String) {
      return LDValue.ofString(json);
    }
    if (json is List<dynamic>) {
      final arrayBuilder = LDValueArrayBuilder();
      for (var item in json) {
        arrayBuilder.addValue(LDValueSerialization.fromJson(item));
      }
      return arrayBuilder.build();
    }
    if (json is Map<String, dynamic>) {
      final objectBuilder = LDValueObjectBuilder();
      for (var entry in json.entries) {
        final value = LDValueSerialization.fromJson(entry.value);
        objectBuilder.addValue(entry.key, value);
      }
      return objectBuilder.build();
    }
    if (json == null) {
      return LDValue.ofNull();
    }

    return LDValue.ofNull();
  }

  static dynamic toJson(LDValue value) {
    switch (value.type) {
      case LDValueType.nullType:
        return null;
      case LDValueType.boolean:
        return value.booleanValue();
      case LDValueType.number:
        return value.doubleValue();
      case LDValueType.string:
        return value.stringValue();
      case LDValueType.array:
        List<dynamic> items = [];
        for (var index = 0; index < value.length; index++) {
          var jsonValue = LDValueSerialization.toJson(value.get(index));
          items.add(jsonValue);
        }
        return items;
      case LDValueType.object:
        Map<String, dynamic> items = {};
        final objectKeys = value.keys.toList(growable: false);
        for (var index = 0; index < value.length; index++) {
          var jsonKey = objectKeys[index];
          var jsonValue = LDValueSerialization.toJson(value.getFor(jsonKey));
          items[jsonKey] = jsonValue;
        }
        return items;
    }
  }
}
