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
      json.forEach((item) =>
          arrayBuilder.addValue(LDValueSerialization.fromJson(item)));
      return arrayBuilder.build();
    }
    if (json is Map<String, dynamic>) {
      final objectBuilder = LDValueObjectBuilder();
      json.entries.forEach((entry) {
        final value = LDValueSerialization.fromJson(entry.value);
        objectBuilder.addValue(entry.key, value);
      });
      return objectBuilder.build();
    }
    if (json == null) {
      return LDValue.ofNull();
    }

    // TODO: We may want to consider an error. If we do, then we would basically
    // need to handle and log. The problem is the error would likely be a couple
    // levels deep in serialization.
    return LDValue.ofNull();
  }

  static dynamic toJson(LDValue value) {
    switch (value.type) {
      case LDValueType.NULL:
        return null;
      case LDValueType.BOOLEAN:
        return value.booleanValue();
      case LDValueType.NUMBER:
        return value.doubleValue();
      case LDValueType.STRING:
        return value.stringValue();
      case LDValueType.ARRAY:
        List<dynamic> items = [];
        for (var index = 0; index < value.length; index++) {
          var jsonValue = LDValueSerialization.toJson(value.get(index));
          items.add(jsonValue);
        }
        return items;
      case LDValueType.OBJECT:
        Map<String, dynamic> items = {};
        final objectKeys = value.keys.toList();
        for (var index = 0; index < value.length; index++) {
          var jsonKey = objectKeys[index];
          var jsonValue = LDValueSerialization.toJson(value.getFor(jsonKey));
          items[jsonKey] = jsonValue;
        }
        return items;
    }
  }
}
