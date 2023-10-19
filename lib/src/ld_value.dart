// @dart=3.1
/// [ld_value] provides the [LDValue] class that represents JSON style values.
///
/// [LDValue] is used by [launchdarkly_flutter_client_sdk] (the
/// [LaunchDarkly Flutter SDK](https://github.com/launchdarkly/flutter-client-sdk)). See [LDAttributesBuilder.set] for how
/// [LDValue] can be used to set complex data in a custom context attribute. The SDK also uses [LDValue] for representing
/// the value of a flag when the type is not known ahead of time, such as in [LDClient.allFlags], as well as when the
/// flag value can be a complex value, such as in [LDClient.jsonVariation].
library ld_value;

import 'dart:collection';
import 'package:quiver/core.dart';

/// Describes the type of an [LDValue]. These correspond to the standard types in JSON.
enum LDValueType {
  /// The value is null.
  NULL,

  /// The value is a boolean.
  BOOLEAN,

  /// The value is a number.
  ///
  /// JSON does not have separate types for integers and floating-point values, but you can convert to either.
  NUMBER,

  /// The value is a string.
  STRING,

  /// The value is an array.
  ARRAY,

  /// The value is an object (map).
  OBJECT
}

/// An immutable instance of any data type that is allowed in JSON.
///
/// [LDValue] provides the type of the contained value as an [LDValueType] returned by [getType].
abstract class LDValue {
  // Constant instances reused for all null and boolean [LDValue] instances.
  static const _NULL = _LDValueNull();
  static const _FALSE = _LDValueBool(false);
  static const _TRUE = _LDValueBool(true);

  /// Internal constant constructor.
  const LDValue._const();

  /// Returns the type of this value.
  LDValueType getType();

  /// Returns a raw platform representation of the value.
  dynamic codecValue();

  /// Returns this value as a `bool` if the type matches, otherwise returns `false`.
  bool booleanValue() => false;

  /// Returns this value as an `int` if the value is numeric, otherwise returns `0`.
  ///
  /// Equivalent to `LDValue.numValue().toInt()`
  int intValue() => 0;

  /// Returns this value as a `double` if the value is numeric, otherwise returns `0`.
  ///
  /// Equivalent to `LDValue.numValue().toDouble()`
  double doubleValue() => 0;

  /// Returns this value as a `num` if the value is numeric, otherwise returns `0`.
  num numValue() => 0;

  /// Returns this value as a `String` if the type matches, otherwise returns an empty string.
  String stringValue() => "";

  /// Returns the number of elements in an array or object, returns `0` for all other types.
  int size() => 0;

  /// Enumerates the property names in an object, returns an empty iterable for all other types.
  Iterable<String> keys() => [];

  /// Enumerates the property values in an array or object, returns an empty iterable for all other types.
  Iterable<LDValue> values() => [];

  /// Retrieves an array element by index.
  ///
  /// Returns [ofNull] if the value is not an array or if the index is out of range.
  LDValue get(int index) => ofNull();

  /// Retrieves an object element by index.
  ///
  /// Returns [ofNull] if the value is not an object or if the key is not found.
  LDValue getFor(String key) => ofNull();

  /// Returns the same value if non-null, or [ofNull] if null.
  static LDValue normalize(LDValue? value) => value ?? ofNull();

  /// Returns an instance for a null value.
  ///
  /// The same instance is always reused for null values.
  static LDValue ofNull() => _NULL;

  /// Returns an instance for a bool value.
  ///
  /// For each input value, [ofBool] will always return the same instance.
  static LDValue ofBool(bool? value) =>
      value == null ? _NULL : (value ? _TRUE : _FALSE);

  /// Returns an instance for a numeric value.
  static LDValue ofNum(num? value) =>
      value == null ? _NULL : _LDValueNumber(value);

  /// Returns an instance for a string value.
  static LDValue ofString(String? value) =>
      value == null ? _NULL : _LDValueString(value);

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

  /// Constructs a value from an arbitrary platform value.
  ///
  /// Supports primitive values from types `bool`, `num`, and `String`, as well as the `null` inhabitant. All other
  /// primitives will be converted to [ofNull]. Supports complex values from `List`, where each element will be
  /// converted as a codec value, and `Map` with String keys, where the values will be converted as codec values.
  static LDValue fromCodecValue(dynamic value) {
    if (value is bool) {
      return ofBool(value);
    }
    if (value is num) {
      return ofNum(value);
    }
    if (value is String) {
      return ofString(value);
    }
    if (value is List) {
      var builder = buildArray();
      value.forEach((element) {
        builder.addValue(fromCodecValue(element));
      });
      return builder.build();
    }
    if (value is Map) {
      var builder = buildObject();
      value.forEach((key, value) {
        builder.addValue(key, fromCodecValue(value));
      });
      return builder.build();
    }
    return ofNull();
  }

  @override
  bool operator ==(Object other) {
    // Handles _LDValueNull and _LDValueBool by virtue of shared instances.
    if (identical(this, other)) {
      return true;
    }
    if (other is LDValue) {
      if (getType() != other.getType()) {
        return false;
      }
      if (getType() == LDValueType.NUMBER) {
        return numValue() == other.numValue();
      }
      if (getType() == LDValueType.STRING) {
        return stringValue() == other.stringValue();
      }
      if (getType() == LDValueType.ARRAY) {
        if (size() != other.size()) {
          return false;
        }
        for (int i = 0; i < size(); i++) {
          if (get(i) != other.get(i)) {
            return false;
          }
        }
        return true;
      }
      if (getType() == LDValueType.OBJECT &&
          other.getType() == LDValueType.OBJECT) {
        if (size() != other.size()) {
          return false;
        }
        for (final String key in keys()) {
          if (!other.keys().contains(key) || getFor(key) != other.getFor(key)) {
            return false;
          }
        }
        return true;
      }
    }
    return false;
  }

  @override
  int get hashCode {
    switch (getType()) {
      case LDValueType.BOOLEAN:
        return booleanValue() ? 1 : 0;
      case LDValueType.NUMBER:
        return intValue();
      case LDValueType.STRING:
        return stringValue().hashCode;
      case LDValueType.ARRAY:
        return hashObjects(values());
      case LDValueType.OBJECT:
        return hash2(hashObjects(keys()), hashObjects(values()));
      default:
        return 0;
    }
  }
}

/// Builder for constructing an [LDValueType.ARRAY] typed [LDValue].
class LDValueArrayBuilder {
  List<LDValue> _builder = [];
  bool _copyOnWrite = false;

  /// Append an [LDValue] to the builder.
  LDValueArrayBuilder addValue(LDValue? value) {
    if (_copyOnWrite) {
      _builder = new List.of(_builder);
      _copyOnWrite = false;
    }
    _builder.add(LDValue.normalize(value));
    return this;
  }

  /// Append a bool value to the builder.
  LDValueArrayBuilder addBool(bool? value) => addValue(LDValue.ofBool(value));

  /// Append a numeric value to the builder.
  LDValueArrayBuilder addNum(num? value) => addValue(LDValue.ofNum(value));

  /// Append a String value to the builder.
  LDValueArrayBuilder addString(String? value) =>
      addValue(LDValue.ofString(value));

  /// Returns an [LDValue] of type [LDValueType.ARRAY] containing the builder's current elements.
  ///
  /// Subsequent changes to the builder will not affect the returned value (it uses copy-on-write logic, so the previous
  /// values will only be copied to a new list if you continue to add elements after calling [build]).
  LDValue build() {
    _copyOnWrite = true;
    return _LDValueArray.ofIterable(_builder);
  }
}

/// Builder for constructing an [LDValueType.OBJECT] typed [LDValue].
class LDValueObjectBuilder {
  Map<String, LDValue> _builder = new Map();
  bool _copyOnWrite = false;

  /// Associated the given key and [LDValue] in the builder.
  LDValueObjectBuilder addValue(String key, LDValue? value) {
    if (_copyOnWrite) {
      _builder = new Map.of(_builder);
      _copyOnWrite = false;
    }
    _builder[key] = LDValue.normalize(value);
    return this;
  }

  /// Associated the given key and bool in the builder.
  LDValueObjectBuilder addBool(String key, bool? value) =>
      addValue(key, LDValue.ofBool(value));

  /// Associated the given key and num in the builder.
  LDValueObjectBuilder addNum(String key, num? value) =>
      addValue(key, LDValue.ofNum(value));

  /// Associated the given key and String in the builder.
  LDValueObjectBuilder addString(String key, String? value) =>
      addValue(key, LDValue.ofString(value));

  /// Returns an [LDValue] of type [LDValueType.OBJECT] containing the builder's current elements.
  ///
  /// Subsequent changes to the builder will not affect the returned value (it uses copy-on-write logic, so the previous
  /// values will only be copied to a new list if you continue to add elements after calling [build]).
  LDValue build() {
    _copyOnWrite = true;
    return _LDValueObject.ofMap(_builder);
  }
}

class _LDValueNull extends LDValue {
  const _LDValueNull() : super._const();

  LDValueType getType() => LDValueType.NULL;
  dynamic codecValue() => null;
}

class _LDValueBool extends LDValue {
  final bool _value;

  const _LDValueBool(this._value) : super._const();

  LDValueType getType() => LDValueType.BOOLEAN;
  dynamic codecValue() => _value;

  @override
  bool booleanValue() => _value;
}

class _LDValueNumber extends LDValue {
  final num _value;

  const _LDValueNumber(this._value) : super._const();

  LDValueType getType() => LDValueType.NUMBER;
  dynamic codecValue() => _value;

  @override
  int intValue() => _value.toInt();
  @override
  double doubleValue() => _value.toDouble();
  @override
  num numValue() => _value;
}

class _LDValueString extends LDValue {
  final String _value;

  const _LDValueString(this._value) : super._const();

  LDValueType getType() => LDValueType.STRING;
  dynamic codecValue() => _value;

  @override
  String stringValue() => _value;
}

class _LDValueArray extends LDValue {
  final List<LDValue> _values;

  const _LDValueArray(this._values) : super._const();

  // Takes ownership to prevent copy, allows copy-on-write behavior in LDValueArrayBuilder.
  static LDValue ofIterable(Iterable<LDValue> values) =>
      _LDValueArray(UnmodifiableListView(values));

  LDValueType getType() => LDValueType.ARRAY;
  dynamic codecValue() => List.of(_values.map((value) => value.codecValue()));

  @override
  int size() => _values.length;
  @override
  Iterable<LDValue> values() => _values;
  @override
  LDValue get(int index) =>
      index >= 0 && index < _values.length ? _values[index] : LDValue.ofNull();
}

class _LDValueObject extends LDValue {
  final Map<String, LDValue> _values;

  const _LDValueObject(this._values) : super._const();

  // Takes ownership to prevent copy, allows copy-on-write behavior in LDValueArrayBuilder.
  static LDValue ofMap(Map<String, LDValue> values) =>
      _LDValueObject(UnmodifiableMapView(values));

  LDValueType getType() => LDValueType.OBJECT;
  dynamic codecValue() =>
      _values.map((key, value) => MapEntry(key, value.codecValue()));

  @override
  int size() => _values.length;
  @override
  Iterable<String> keys() => _values.keys;
  @override
  Iterable<LDValue> values() => _values.values;
  @override
  LDValue getFor(String key) => _values[key] ?? LDValue.ofNull();
}
