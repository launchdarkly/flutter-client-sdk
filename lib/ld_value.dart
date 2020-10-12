part of launchdarkly_flutter_client_sdk;

enum LDValueType {
  NULL, BOOLEAN, NUMBER, STRING, ARRAY, OBJECT
}

abstract class LDValue {
  const LDValue._const();
  LDValueType getType();
  dynamic _codecValue();
  bool booleanValue() => false;
  double doubleValue() => 0;
  String stringValue() => "";
  int size() => 0;
  Iterable<String> keys() => [];
  Iterable<LDValue> values() => [];
  LDValue get(int index) => _LDValueNull.INSTANCE;
  LDValue getFor(String key) => _LDValueNull.INSTANCE;

//  LDValue _fromCodecValue(dynamic value) {
//
//  }
}

class _LDValueNull extends LDValue {
  static const INSTANCE = _LDValueNull._const();

  const _LDValueNull._const(): super._const();

  LDValueType getType() => LDValueType.NULL;
  dynamic _codecValue() => null;
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
  dynamic _codecValue() => _value;

  @override bool booleanValue() => _value;
}

class _LDValueNumber extends LDValue {
  final double _value;

  const _LDValueNumber._const(double value): _value = value, super._const();

  static LDValue fromDouble(double value) {
    return value == null ? _LDValueNull.INSTANCE : _LDValueNumber._const(value);
  }

  LDValueType getType() => LDValueType.NUMBER;
  dynamic _codecValue() => _value;

  @override double doubleValue() => _value;
}

class _LDValueString extends LDValue {
  final String _value;

  const _LDValueString._const(String value): _value = value, super._const();

  static LDValue fromString(String value) {
    return value == null ? _LDValueNull.INSTANCE : _LDValueString._const(value);
  }

  LDValueType getType() => LDValueType.STRING;
  dynamic _codecValue() => _value;

  @override String stringValue() => _value;
}

class _LDValueArray extends LDValue {
  final List<LDValue> _values;

  const _LDValueArray._const(List<LDValue> values): _values = values, super._const();

  static LDValue fromList(List<LDValue> values) {
    return values == null ? _LDValueNull.INSTANCE : _LDValueArray._const(List.unmodifiable(values));
  }

  LDValueType getType() => LDValueType.ARRAY;
  dynamic _codecValue() => List.unmodifiable(_values.map((value) => value._codecValue()));

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
  dynamic _codecValue() => _values.map((key, value) => MapEntry(key, value._codecValue()));

  @override int size() => _values.length;
  @override Iterable<String> keys() => _values.keys;
  @override Iterable<LDValue> values() => _values.values;
  @override LDValue getFor(String key) => _values[key];
}
