library ld_value;

enum LDValueType {
  NULL, BOOLEAN, NUMBER, STRING, ARRAY, OBJECT
}

abstract class LDValue {
  const LDValue._const();
  LDValueType getType();
  dynamic codecValue();
  bool booleanValue() => false;
  int intValue() => 0;
  double doubleValue() => 0;
  num numValue() => 0;
  String stringValue() => "";
  int size() => 0;
  Iterable<String> keys() => [];
  Iterable<LDValue> values() => [];
  LDValue get(int index) => _LDValueNull.INSTANCE;
  LDValue getFor(String key) => _LDValueNull.INSTANCE;

  static LDValue normalize(LDValue value) => value ?? ofNull();
  static LDValue ofNull() => _LDValueNull.INSTANCE;
  static LDValue ofBool(bool value) => _LDValueBool.fromBool(value);
  static LDValue ofNum(num value) => _LDValueNumber.fromNum(value);
  static LDValue ofString(String value) => _LDValueString.fromString(value);
  static ArrayBuilder buildArray() => ArrayBuilder();
  static ObjectBuilder buildObject() => ObjectBuilder();

  static LDValue fromCodecValue(dynamic value) {
    if (value == null) {
      return LDValue.ofNull();
    }
    if (value is bool) {
      return LDValue.ofBool(value);
    }
    if (value is num) {
      return LDValue.ofNum(value);
    }
    if (value is String) {
      return LDValue.ofString(value);
    }
    if (value is List) {
      var builder = ArrayBuilder();
      value.forEach((element) {
        builder.addValue(LDValue.fromCodecValue(element));
      });
      return builder.build();
    }
    if (value is Map) {
      var builder = ObjectBuilder();
      value.forEach((key, value) {
        builder.addValue(key, LDValue.fromCodecValue(value));
      });
      return builder.build();
    }
    return LDValue.ofNull();
  }
}

class ArrayBuilder {
  List<LDValue> _builder = new List();
  bool _copyOnWrite = false;

  ArrayBuilder addValue(LDValue value) {
    if (_copyOnWrite) {
      _builder = new List.from(_builder);
      _copyOnWrite = false;
    }
    _builder.add(LDValue.normalize(value));
    return this;
  }

  ArrayBuilder addBool(bool value) => addValue(LDValue.ofBool(value));
  ArrayBuilder addNum(num value) => addValue(LDValue.ofNum(value));
  ArrayBuilder addString(String value) => addValue(LDValue.ofString(value));

  LDValue build() {
    _copyOnWrite = true;
    return _LDValueArray.fromList(_builder);
  }
}

class ObjectBuilder {
  Map<String, LDValue> _builder = new Map();
  bool _copyOnWrite = false;

  ObjectBuilder addValue(String key, LDValue value) {
    if (_copyOnWrite) {
      _builder = new Map.from(_builder);
      _copyOnWrite = false;
    }
    _builder[key] = LDValue.normalize(value);
    return this;
  }

  ObjectBuilder addBool(String key, bool value) => addValue(key, LDValue.ofBool(value));
  ObjectBuilder addNum(String key, num value) => addValue(key, LDValue.ofNum(value));
  ObjectBuilder addString(String key, String value) => addValue(key, LDValue.ofString(value));

  LDValue build() {
    _copyOnWrite = true;
    return _LDValueObject.fromMap(_builder);
  }
}

class _LDValueNull extends LDValue {
  static const INSTANCE = _LDValueNull._const();

  const _LDValueNull._const(): super._const();

  LDValueType getType() => LDValueType.NULL;
  dynamic codecValue() => null;
}

class _LDValueBool extends LDValue {
  static const TRUE = _LDValueBool._const(true);
  static const FALSE = _LDValueBool._const(false);

  final bool _value;

  const _LDValueBool._const(bool value): _value = value, super._const();

  static LDValue fromBool(bool value) {
    return value == null ? _LDValueNull.INSTANCE : (value ? TRUE : FALSE);
  }

  LDValueType getType() => LDValueType.BOOLEAN;
  dynamic codecValue() => _value;

  @override bool booleanValue() => _value;
}

class _LDValueNumber extends LDValue {
  final num _value;

  const _LDValueNumber._const(num value): _value = value, super._const();

  static LDValue fromNum(num value) {
    return value == null ? _LDValueNull.INSTANCE : _LDValueNumber._const(value);
  }

  LDValueType getType() => LDValueType.NUMBER;
  dynamic codecValue() => _value;

  @override int intValue() => _value.toInt();
  @override double doubleValue() => _value.toDouble();
  @override num numValue() => _value;
}

class _LDValueString extends LDValue {
  final String _value;

  const _LDValueString._const(String value): _value = value, super._const();

  static LDValue fromString(String value) {
    return value == null ? _LDValueNull.INSTANCE : _LDValueString._const(value);
  }

  LDValueType getType() => LDValueType.STRING;
  dynamic codecValue() => _value;

  @override String stringValue() => _value;
}

class _LDValueArray extends LDValue {
  final List<LDValue> _values;

  const _LDValueArray._const(List<LDValue> values): _values = values, super._const();

  static LDValue fromList(List<LDValue> values) {
    return values == null ? _LDValueNull.INSTANCE : _LDValueArray._const(List.unmodifiable(values));
  }

  LDValueType getType() => LDValueType.ARRAY;
  dynamic codecValue() => List.unmodifiable(_values.map((value) => value.codecValue()));

  @override int size() => _values.length;
  @override Iterable<LDValue> values() => _values;
  @override LDValue get(int index) => _values[index];
}

class _LDValueObject extends LDValue {
  final Map<String, LDValue> _values;

  const _LDValueObject._const(Map<String, LDValue> values): _values = values, super._const();

  static LDValue fromMap(Map<String, LDValue> values) {
    return values == null ? _LDValueNull.INSTANCE : _LDValueObject._const(Map.unmodifiable(values));
  }

  LDValueType getType() => LDValueType.OBJECT;
  dynamic codecValue() => _values.map((key, value) => MapEntry(key, value.codecValue()));

  @override int size() => _values.length;
  @override Iterable<String> keys() => _values.keys;
  @override Iterable<LDValue> values() => _values.values;
  @override LDValue getFor(String key) => _values[key];
}
