import 'dart:collection';
import 'collections.dart';

/// Describes the type of an [LDValue]. These correspond to the standard types in JSON.
enum LDValueType {
  /// The value is null.
  nullType,

  /// The value is a boolean.
  boolean,

  /// The value is a number.
  ///
  /// JSON does not have separate types for integers and floating-point values, but you can convert to either.
  number,

  /// The value is a string.
  string,

  /// The value is an array.
  array,

  /// The value is an object (map).
  object
}

// Constant instances reused for all null and boolean [LDValue] instances.
const LDValue _null = LDValue._const(null);
const LDValue _true = LDValue._const(true);
const LDValue _false = LDValue._const(false);

/// An immutable instance of any data type that is allowed in JSON.
///
/// [LDValue] provides the type of the contained value as an [LDValueType] returned by [type].
final class LDValue {
  final dynamic _value;

  const LDValue._const(this._value);

  /// Returns an instance for a null value.
  ///
  /// The same instance is always reused for null values.
  static LDValue ofNull() => _null;

  /// Returns an instance for a bool value.
  ///
  /// For each input value, [ofBool] will always return the same instance.
  static LDValue ofBool(bool value) => value ? _true : _false;

  /// Returns an instance for a numeric value.
  static LDValue ofNum(num value) => LDValue._const(value);

  /// Returns an instance for a string value.
  static LDValue ofString(String value) => LDValue._const(value);

  // Returns this value as a `bool` if the type matches, otherwise returns `false`.
  bool booleanValue() => _value is bool ? _value : false;

  /// Returns this value as an `int` if the value is numeric, otherwise returns `0`.
  ///
  /// Equivalent to `LDValue.numValue().toInt()`
  int intValue() => _value is num ? (_value as num).toInt() : 0;

  /// Returns this value as a `double` if the value is numeric, otherwise returns `0`.
  ///
  /// Equivalent to `LDValue.numValue().toDouble()`
  double doubleValue() => _value is num ? (_value as num).toDouble() : 0;

  /// Returns this value as a `String` if the type matches, otherwise returns an empty string.
  String stringValue() => _value is String ? (_value as String) : '';

  /// Starts building an array value.
  ///
  /// Returns an [LDValueArrayBuilder] for constructing an array instance.
  /// ```
  /// LDValue arrayValue = LDValue.buildArray().addNum(1).addString('abc').build();
  /// ```
  static LDValueArrayBuilder buildArray() => LDValueArrayBuilder();

  /// Starts building an object value.
  ///
  /// Returns an [LDValueObjectBuilder] for constructing an object instance.
  /// ```
  /// LDValue objectValue = LDValue.buildObject().addBool('key', true).build();
  /// ```
  static LDValueObjectBuilder buildObject() => LDValueObjectBuilder();

  /// Get the type of this value.
  LDValueType get type {
    if (_value is bool) {
      return LDValueType.boolean;
    }
    if (_value is num) {
      return LDValueType.number;
    }
    if (_value is String) {
      return LDValueType.string;
    }
    if (_value is _LDValueArray) {
      return LDValueType.array;
    }
    if (_value is _LDValueObject) {
      return LDValueType.object;
    }
    if (_value == null) {
      return LDValueType.nullType;
    }

    assert(false,
        'Unsupported LDValue type. Please ensure exhaustive support in `get type`');
    return LDValueType.nullType;
  }

  /// Retrieves an array element by index.
  ///
  /// Returns [ofNull] if the value is not an array or if the index is out of range.
  LDValue get(int index) {
    if (_value is _LDValueArray) {
      return (_value as _LDValueArray)[index];
    }
    return LDValue.ofNull();
  }

  /// Retrieves an object element by index.
  ///
  /// Returns [ofNull] if the value is not an object or if the key is not found.
  LDValue getFor(String key) {
    if (_value is _LDValueObject) {
      return (_value as _LDValueObject)[key];
    }
    return LDValue.ofNull();
  }

  /// Enumerates the property names in an object, returns an empty iterable for all other types.
  Iterable<String> get keys {
    if (_value is _LDValueObject) {
      return (_value as _LDValueObject).keys;
    }
    return [];
  }

  /// Enumerates the property values in an array or object, returns an empty iterable for all other types.
  Iterable<LDValue> get values {
    if (_value is _LDValueObject) {
      return (_value as _LDValueObject).values;
    }
    if (_value is _LDValueArray) {
      return (_value as _LDValueArray).values;
    }
    return [];
  }

  /// Returns the number of elements in an array or object, returns `0` for all other types.
  int get length {
    if (_value is _LDValueObject) {
      return (_value as _LDValueObject).length;
    }
    if (_value is _LDValueArray) {
      return (_value as _LDValueArray).length;
    }
    return 0;
  }

  @override
  bool operator ==(Object other) {
    // Same references are equal.
    if (identical(this, other)) {
      return true;
    }
    // If it is a different type, then it is not equal.
    if (other is! LDValue) {
      return false;
    }
    // If it isn't the same type of value, then it cannot be equal.
    if (type != other.type) {
      return false;
    }

    return _value == other._value;
  }

  @override
  int get hashCode => Object.hash(type, _value);

  @override
  String toString() {
    return 'LDValue{_value: $_value}';
  }
}

class _LDValueArray {
  final List<LDValue> _value;

  const _LDValueArray(this._value);

  int get length => _value.length;

  LDValue operator [](int i) => i < length ? _value[i] : LDValue.ofNull();

  Iterable<LDValue> get values => _value;

  @override
  bool operator ==(Object other) {
    // Same references are equal.
    if (identical(this, other)) {
      return true;
    }
    // If it is a different type, then it is not equal.
    if (other is! _LDValueArray) {
      return false;
    }
    return _value.equals(other._value);
  }

  @override
  int get hashCode => Object.hashAll(_value);

  @override
  String toString() {
    return '_LDValueArray{_value: $_value}';
  }
}

class _LDValueObject {
  final Map<String, LDValue> _value;

  const _LDValueObject(this._value);

  int get length => _value.length;

  LDValue operator [](String i) => _value[i] ?? LDValue.ofNull();

  Iterable<String> get keys => _value.keys;

  Iterable<LDValue> get values => _value.values;

  @override
  bool operator ==(Object other) {
    // Same references are equal.
    if (identical(this, other)) {
      return true;
    }
    // If it is a different type, then it is not equal.
    if (other is! _LDValueObject) {
      return false;
    }

    return _value.equals(other._value);
  }

  @override
  int get hashCode => Object.hashAllUnordered(
      _value.entries.map((item) => Object.hash(item.key, item.value)));

  @override
  String toString() {
    return '_LDValueObject{_value: $_value}';
  }
}

/// Builder for constructing an [LDValueType.array] typed [LDValue].
class LDValueArrayBuilder {
  List<LDValue> _builder = [];
  bool _copyOnWrite = false;

  /// Append an [LDValue] to the builder.
  LDValueArrayBuilder addValue(LDValue value) {
    if (_copyOnWrite) {
      _builder = List.of(_builder);
      _copyOnWrite = false;
    }
    _builder.add(value);
    return this;
  }

  /// Append a bool value to the builder.
  LDValueArrayBuilder addBool(bool value) => addValue(LDValue.ofBool(value));

  /// Append a numeric value to the builder.
  LDValueArrayBuilder addNum(num value) => addValue(LDValue.ofNum(value));

  /// Append a String value to the builder.
  LDValueArrayBuilder addString(String value) =>
      addValue(LDValue.ofString(value));

  /// Returns an [LDValue] of type [LDValueType.array] containing the builder's current elements.
  ///
  /// Subsequent changes to the builder will not affect the returned value (it uses copy-on-write logic, so the previous
  /// values will only be copied to a new list if you continue to add elements after calling [build]).
  LDValue build() {
    _copyOnWrite = true;
    return LDValue._const(_LDValueArray(UnmodifiableListView(_builder)));
  }
}

/// Builder for constructing an [LDValueType.object] typed [LDValue].
class LDValueObjectBuilder {
  Map<String, LDValue> _builder = {};
  bool _copyOnWrite = false;

  /// Associated the given key and [LDValue] in the builder.
  LDValueObjectBuilder addValue(String key, LDValue value) {
    if (_copyOnWrite) {
      _builder = Map.of(_builder);
      _copyOnWrite = false;
    }
    _builder[key] = value;
    return this;
  }

  /// Associated the given key and bool in the builder.
  LDValueObjectBuilder addBool(String key, bool value) =>
      addValue(key, LDValue.ofBool(value));

  /// Associated the given key and num in the builder.
  LDValueObjectBuilder addNum(String key, num value) =>
      addValue(key, LDValue.ofNum(value));

  /// Associated the given key and String in the builder.
  LDValueObjectBuilder addString(String key, String value) =>
      addValue(key, LDValue.ofString(value));

  /// Returns an [LDValue] of type [LDValueType.object] containing the builder's current elements.
  ///
  /// Subsequent changes to the builder will not affect the returned value (it uses copy-on-write logic, so the previous
  /// values will only be copied to a new list if you continue to add elements after calling [build]).
  LDValue build() {
    _copyOnWrite = true;
    return LDValue._const(_LDValueObject(UnmodifiableMapView(_builder)));
  }
}
