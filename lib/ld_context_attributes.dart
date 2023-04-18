// @dart=2.12
part of launchdarkly_flutter_client_sdk;

/// Collection of attributes for a [LDContext]
class LDContextAttributes {
  final Map<String, LDValue> attributes;

  // TODO sc-195759: Support private, redacted attributes
  // final List<String> privateAttributeNames;

  LDContextAttributes._internal(this.attributes);
}

/// A builder for constructing [LDContextAttributes].
class LDAttributesBuilder {
  static const String _KIND = "kind";
  static const String _KEY = "key";
  static const String _NAME = "name";
  static const String _ANONYMOUS = "anonymous";
  static const String _META = "_meta";

  Map<String, LDValue> _attributes = new Map();

  // TODO sc-195759: Support private, redacted attributes
  // Set<String> _metaPrivateAttributes = new Set();

  /// Creates the builder with the provided kind and key which are required
  /// attributes.
  LDAttributesBuilder._internal(String kind, String key) {
    _attributes[_KIND] = LDValue.ofString(kind);
    _attributes[_KEY] = LDValue.ofString(key);
  }

  /// Sets the context's name attribute.  This attribute is optional.
  /// This will be used as the preferred display name for the context in LaunchDarkly.
  LDAttributesBuilder name(String name) {
    _attributes[_NAME] = LDValue.ofString(name);
    return this;
  }

  /// Sets whether the LDContext is only intended for flag evaluations and
  /// should not be indexed by LaunchDarkly.
  ///
  /// The default value is false. False means that this LDContext represents an
  /// entity such as a user that you want to be able to see on the LaunchDarkly
  /// dashboard.
  ///
  /// Setting anonymous to true excludes this [LDContext] from the dashboard.
  /// It does not exclude it from analytics event data, so it is not the same as
  /// making attributes private; all non-private attributes will still be
  /// included in events and data export.
  LDAttributesBuilder anonymous(bool anonymous) {
    _attributes[_ANONYMOUS] = LDValue.ofBool(anonymous);
    return this;
  }

  /// Sets the value of any attribute for the Context.
  ///
  /// This method uses the [LDValue] type to represent a value of any JSON
  /// type: null, boolean, number, string, array, or object. For all attribute
  /// names that do not have special meaning to LaunchDarkly, you may use any
  /// of those types. Values of different JSON types are always treated as
  /// different values: for instance, null, false, and the empty string "" are
  /// not the same, and the number 1 is not the same as the string "1".
  ///
  /// The following attribute names have special restrictions on their value
  /// types, and any value of an unsupported type will be ignored (leaving
  /// the attribute unchanged):
  ///
  /// - "kind", "key": Required and must be a non-empty string.
  /// - "name": Must be a non-empty string or null.
  /// - "anonymous": Must be a boolean.
  /// - "_meta": Is reserved for internal use.
  ///
  /// Values that are JSON arrays or objects have special behavior when
  /// referenced in flag/segment rules.
  ///
  /// A value of [LDValue.ofNull] is equivalent to removing any current
  /// non-default value of the attribute. Null is not a valid attribute value
  /// in the LaunchDarkly model; any expressions in feature flags that reference
  /// an attribute with a null value will behave as if the attribute did not
  /// exist.
  LDAttributesBuilder set(String name, LDValue value) {
    _attributes[name] = value;
    return this;
  }

  // TODO sc-195759: Support private, redacted attributes, references.  Rewrite
  // private functions and private APIs to match other contemporary SDK versions

  /// Creates a [LDContextAttributes] from the current properties.  If any
  /// attributes are invalid, they are dropped.  If required attributes are
  /// invalid or missing, null is returned.
  ///
  /// The [LDContextAttributes] is immutable and will not be affected by
  /// any subsequent actions on the [LDAttributesBuilder].
  LDContextAttributes? _build() {

    // remove invalid attributes
    _attributes.removeWhere((key, value) => !(_isAttributeValid(key, value)));

    // kind and key are required to build a proper context.  it is important
    // this line is after the removal of invalid attributes
    if (!_attributes.containsKey(_KIND) || !_attributes.containsKey(_KEY)) {
      return null;
    }

    return LDContextAttributes._internal(
      // create immutable shallow copy
        Map.unmodifiable(_attributes));
  }

  /// Performs minimal validation to provide some guarantees in Flutter layer.
  /// Additional validation is performed by the native SDK and we don't want
  /// to duplicate more complex validation (ex: valid characters) in this layer.
  /// Returns true if valid, false if invalid
  static bool _isAttributeValid(String name, LDValue value) {
    if (name.isEmpty) {
      log("Ignoring attribute.  Name was empty.  Value was ${value.toString()}");
      return false;
    }

    switch (name) {
      case _KIND:
        if (value.getType() != LDValueType.STRING || value.stringValue().isEmpty) {
          log("Ignoring attribute.  $_KIND must be a non-empty string.");
          return false;
        }

        break;
      case _KEY:
        if (value.getType() != LDValueType.STRING || value.stringValue().isEmpty) {
          log("Ignoring attribute.  $_KEY must be a non-empty string.");
          return false;
        }
        break;
      case _NAME:
        if (value.getType() != LDValueType.STRING) {
          log("Ignoring attribute.  $_NAME must be a string.");
          return false;
        }
        break;
      case _ANONYMOUS:
        if (value.getType() != LDValueType.BOOLEAN) {
          log("Ignoring attribute.  $_ANONYMOUS must be a boolean.");
          return false;
        }
        break;
      case _META:
        log("Ignoring attribute.  $_META is a reserved attribute for internal usage.");
        return false;
    }
    return true;
  }
}
