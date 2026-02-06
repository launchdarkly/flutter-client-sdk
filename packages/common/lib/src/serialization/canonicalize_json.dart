import 'dart:convert';

/// Serialize a number according to RFC 8785 rules.
///
/// Per RFC 8785, NaN and Infinity are forbidden and implementations
/// must terminate with an error if encountered. However, when [lenient]
/// is true, these values are replaced with null instead.
String _serializeNumber(num value, {required bool lenient}) {
  // RFC 8785 requires termination with error for NaN and Infinity
  // In lenient mode, replace with null instead
  if (value.isNaN) {
    if (lenient) {
      return 'null';
    }
    throw ArgumentError('NaN is not allowed in RFC 8785 canonical JSON');
  }
  if (value.isInfinite) {
    if (lenient) {
      return 'null';
    }
    throw ArgumentError('Infinity is not allowed in RFC 8785 canonical JSON');
  }

  // Check if it's an integer value (even if stored as double)
  if (value == value.toInt()) {
    return value.toInt().toString();
  }

  // For non-integer values, use Dart's toString()
  // Dart's num.toString() returns the shortest string that uniquely identifies
  // the number, using exponential notation outside the range 10^-6 to 10^21.
  // On web platforms, Dart defers to JavaScript's number serialization.
  // See: https://api.dart.dev/dart-core/num/toString.html
  String str = value.toString();

  // RFC 8785 requires lowercase 'e' in scientific notation
  // Dart may produce uppercase 'E', so normalize it
  if (str.contains('E')) {
    str = str.replaceAll('E', 'e');
  }

  // Remove unnecessary trailing zeros after decimal point
  // (but only if not in scientific notation)
  if (str.contains('.') && !str.contains('e')) {
    str = str.replaceAll(RegExp(r'\.?0+$'), '');
  }

  return str;
}

/// Given some object to serialize, produce a canonicalized JSON string
/// according to RFC 8785 (https://www.rfc-editor.org/rfc/rfc8785.html).
///
/// We do not support custom toJson methods on objects. Objects should be
/// limited to basic types.
///
/// When [lenient] is false (default), throws an [ArgumentError] if NaN or
/// Infinity is encountered, per RFC 8785 requirements. When [lenient] is
/// true, NaN and Infinity are replaced with null for safety.
///
/// Throws an [ArgumentError] if a cycle is detected in the object graph.
String canonicalizeJson(dynamic object,
    {bool lenient = false, List<dynamic> visited = const []}) {
  // Handle null
  if (object == null) {
    return 'null';
  }

  // Handle primitives
  if (object is num) {
    return _serializeNumber(object, lenient: lenient);
  }

  if (object is bool) {
    return object.toString();
  }

  if (object is String) {
    return jsonEncode(object);
  }

  // Check for cycles
  if (visited.contains(object)) {
    throw ArgumentError('Cycle detected');
  }

  // Handle arrays
  if (object is List) {
    final newVisited = [...visited, object];
    final values = object.map((item) => canonicalizeJson(item, lenient: lenient, visited: newVisited));
    return '[${values.join(',')}]';
  }

  // Handle objects/maps
  if (object is Map) {
    final newVisited = [...visited, object];

    // Create a list of key-value pairs with string keys for sorting
    final entries = object.entries.map((entry) {
      final keyStr = entry.key.toString();
      return MapEntry(keyStr, entry);
    }).toList()
      ..sort((a, b) => a.key.compareTo(b.key));

    final serializedValues = entries.map((entry) {
      final keyStr = entry.key;
      final originalValue = entry.value.value;
      final value = canonicalizeJson(originalValue, lenient: lenient, visited: newVisited);
      // Include the key-value pair only if the value is not undefined
      // (In Dart, we don't have undefined, so we include all values)
      return '${jsonEncode(keyStr)}:$value';
    });

    return '{${serializedValues.join(',')}}';
  }

  // For any other object type, we can't serialize it
  throw ArgumentError('Cannot canonicalize object of type ${object.runtimeType}');
}
