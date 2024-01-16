import 'dart:collection';
import 'dart:core';

import 'collections.dart';

import 'ld_context.dart';

// Regular expression that matches "~" or "/". They are different groups so
// that they can be selectively replaced.
RegExp _toRefExp = RegExp('(~)|(/)');
// Match escape sequences of ~0 and ~1 so they can be transformed back into
// the original characters.
RegExp _unescapeExp = RegExp(r'(~0)|(~1)');
// Expression which only matches invalid references.
RegExp _invalidExp = RegExp(r'//|(^/.*~[^0|^1])|~$|/$');

/// Given a string literal escape it to be suitable for an attribute reference.
String _toRefString(String value) {
  return "/${value.replaceAllMapped(_toRefExp, (match) {
    // The 0 group is all, so we are looking at groups 2 and 1.
    if (match.group(2) != null) {
      return '~1';
    }
    return '~0';
  })}";
}

/// Given an escaped attribute reference component produce a literal name.
String _unescape(String ref) {
  if (ref.contains('~')) {
    // The replaceAllMapped allows for a single pass replacement of all matches.
    // Removes the ordering dependence for a multi-pass approach.
    return ref.replaceAllMapped(_unescapeExp, (match) {
      // The 0 group is all, so we are looking at groups 2 and 1.
      if (match.group(2) != null) {
        return '/';
      }
      return '~';
    });
  }
  return ref;
}

/// Check if an attribute reference string is valid.
bool _validate(String ref) {
  return ref.isNotEmpty && !_invalidExp.hasMatch(ref);
}

/// Check if the reference is a literal.
bool _isLiteral(String value) {
  return !value.startsWith('/');
}

/// Given a reference string produce the components of the reference.
List<String> _getComponents(String value) {
  if (_isLiteral(value)) {
    return List.unmodifiable([value]);
  }
  final withoutPrefix = value.substring(1);
  return List.unmodifiable(withoutPrefix.split('/').map(_unescape));
}

/// An attribute name or path expression identifying a value within an [LDContext].
///
/// Applications are unlikely to need to use this type directly, but see below for details of the
/// attribute reference syntax used by methods like [LDAttributesBuilder.privateAttributes].
///
/// The string representation of an attribute reference in LaunchDarkly data uses the following
/// syntax:
///
/// - If the first character is not a slash, the string is interpreted literally as an
/// attribute name. An attribute name can contain any characters, but must not be empty.
/// - If the first character is a slash, the string is interpreted as a slash-delimited
/// path where the first path component is an attribute name, and each subsequent path
/// component is the name of a property in a JSON object. Any instances of the characters '/'
/// or '~' in a path component are escaped as '~1' or '~0' respectively. This syntax
/// deliberately resembles JSON Pointer, but no JSON Pointer behaviors other than those
/// mentioned here are supported.
final class AttributeReference {
  final bool valid;
  final String redactionName;
  final List<String> components;

  /// Take an attribute reference string and produce an attribute reference.
  ///
  /// [ref] must be a valid attribute reference string.
  AttributeReference(String ref)
      : valid = _validate(ref),
        redactionName = ref,
        components = UnmodifiableListView(_getComponents(ref));

  @override
  bool operator ==(Object other) {
    return other is AttributeReference && components.equals(other.components);
  }

  /// Create an attribute reference from a literal.
  static AttributeReference fromLiteral(String literal) {
    return AttributeReference(
        _isLiteral(literal) ? literal : _toRefString(literal));
  }

  /// Create an attribute reference from a list of components.
  AttributeReference.fromComponents(List<String> components)
      : valid = true,
        redactionName = components.map((e) => _toRefString(e)).join(),
        components = UnmodifiableListView(components);

  @override
  int get hashCode => components.join('/').hashCode;

  @override
  String toString() {
    return 'AttributeReference{valid: $valid, redactionName: $redactionName, components: $components}';
  }
}
