import 'collections.dart';
import 'ld_value.dart';
import 'attribute_reference.dart';

RegExp _kindExp = RegExp(r'^(\w|\.|-)+$', unicode: false);

const String _kindAttr = 'kind';
const String _keyAttr = 'key';
const String _nameAttr = 'name';
const String _anonymousAttr = 'anonymous';
const String _metaAttr = '_meta';

String _encodeKey(String key) {
  if (key.contains('%') || key.contains(':')) {
    // Keys should be small, so this should be fine, but we could
    // use replaceAllMapped if we need to gain some performance.
    return key.replaceAll('%', '%25').replaceAll(':', '%3A');
  }
  return key;
}

bool _validKind(String kind) {
  return kind != 'kind' && _kindExp.hasMatch(kind);
}

bool _referenceIs(AttributeReference reference, String value) {
  if (reference.components.length == 1) {
    return reference.components[0] == value;
  }
  return false;
}

/// Collection of attributes for a [LDContext]
final class LDContextAttributes {
  final Map<String, LDValue> customAttributes;

  final String kind;
  final String key;
  final bool anonymous;
  final String? name;
  final Set<AttributeReference> privateAttributes;

  LDContextAttributes._internal(this.customAttributes, this.kind, this.key,
      this.anonymous, this.privateAttributes, this.name);

  LDValue _get(AttributeReference reference) {
    if (!reference.valid) {
      return LDValue.ofNull();
    }
    if (_referenceIs(reference, _nameAttr)) {
      return name == null ? LDValue.ofNull() : LDValue.ofString(name!);
    }
    if (_referenceIs(reference, _keyAttr)) {
      return LDValue.ofString(key);
    }
    if (_referenceIs(reference, _anonymousAttr)) {
      return LDValue.ofBool(anonymous);
    }
    if (_referenceIs(reference, _kindAttr)) {
      return LDValue.ofString(kind);
    }

    var pointer = customAttributes[reference.components.first];

    for (var index = 1; index < reference.components.length; index++) {
      if (pointer == null || pointer.type != LDValueType.object) {
        return LDValue.ofNull();
      }

      pointer = pointer.getFor(reference.components[index]);
    }
    return pointer ?? LDValue.ofNull();
  }

  @override
  String toString() {
    return 'LDContextAttributes{customAttributes: $customAttributes, kind: $kind, key: $key, anonymous: $anonymous, name: $name, privateAttributes: $privateAttributes}';
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is LDContextAttributes &&
          customAttributes.equals(other.customAttributes) &&
          kind == other.kind &&
          key == other.key &&
          anonymous == other.anonymous &&
          name == other.name &&
          privateAttributes.equals(other.privateAttributes);

  @override
  int get hashCode =>
      Object.hashAllUnordered(customAttributes.keys) ^
      Object.hashAllUnordered(customAttributes.values) ^
      kind.hashCode ^
      key.hashCode ^
      anonymous.hashCode ^
      name.hashCode ^
      Object.hashAllUnordered(privateAttributes);
}

/// A builder for constructing [LDContextAttributes].
final class LDAttributesBuilder {
  final String _kind;
  final LDContextBuilder _parent;
  String? _key;
  String? _name;
  bool _anonymous = false;
  final Set<AttributeReference> _privateAttributes = {};

  // map for tracking attributes of the context
  final Map<String, LDValue> _attributes = {};

  /// Creates the builder with the provided kind.
  LDAttributesBuilder._internal(LDContextBuilder parent, String kind)
      : _kind = kind,
        _parent = parent;

  /// Builds the context.
  LDContext build() => _parent.build();

  /// Start building a new context with the given kind.
  LDAttributesBuilder kind(String kind, [String? key]) =>
      _parent.kind(kind, key);

  /// Set the name of the context.
  LDAttributesBuilder name(String name) {
    _name = name;
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
    _anonymous = anonymous;
    return this;
  }

  /// Sets the attribute with [name] to the [value] provided.  Also marks the
  /// attribute as private accordingly if [private] is provided.
  ///
  /// This method uses the [LDValue] type to represent a value of any JSON
  /// type: null, boolean, number, string, array, or object. For all attribute
  /// names that do not have special meaning to LaunchDarkly, you may use any
  /// of those types. Values of different JSON types are always treated as
  /// different values: for instance, null, false, and the empty string "" are
  /// not the same, and the number 1 is not the same as the string "1".
  ///
  /// You cannot use this method to set the following attributes.
  ///
  /// - "" - A name with an empty string.
  /// - "kind"
  /// - "key"
  /// - "_meta"
  ///
  /// Attempts to set these attributes will be ignored.
  ///
  /// Values that are JSON arrays or objects have special behavior when
  /// referenced in flag/segment rules.
  ///
  /// A value of [LDValue.ofNull] is equivalent to removing any current
  /// non-default value of the attribute. Null is not a valid attribute value
  /// in the LaunchDarkly model; any expressions in feature flags that reference
  /// an attribute with a null value will behave as if the attribute did not
  /// exist.
  LDAttributesBuilder setValue(String name, LDValue value,
      {bool private = false}) {
    _trySet(name, value, private);
    return this;
  }

  /// Sets the attribute with [name] to the [bool] provided.  Also marks the
  /// attribute as private accordingly if [private] is provided.
  ///
  /// You cannot use this method to set the following attributes.
  ///
  /// - "" - A name with an empty string.
  /// - "kind"
  /// - "key"
  /// - "_meta"
  ///
  /// Attempts to set these attributes will be ignored.
  LDAttributesBuilder setBool(String name, bool bool, {bool private = false}) {
    _trySet(name, LDValue.ofBool(bool), private);
    return this;
  }

  /// Sets the attribute with [name] to the [num] provided.  Also marks the
  /// attribute as private accordingly if [private] is provided.
  ///
  /// You cannot use this method to set the following attributes.
  ///
  /// - "" - A name with an empty string.
  /// - "kind"
  /// - "key"
  /// - "_meta"
  ///
  /// Attempts to set these attributes will be ignored.
  LDAttributesBuilder setNum(String name, num num, {bool private = false}) {
    _trySet(name, LDValue.ofNum(num), private);
    return this;
  }

  /// Sets the attribute with [name] to the [string] provided.  Also marks the
  /// attribute as private accordingly if [private] is provided.
  ///
  /// You cannot use this method to set the following attributes.
  ///
  /// - "" - A name with an empty string.
  /// - "kind"
  /// - "key"
  /// - "_meta"
  ///
  /// Attempts to set these attributes will be ignored.
  LDAttributesBuilder setString(String name, String string,
      {bool private = false}) {
    _trySet(name, LDValue.ofString(string), private);
    return this;
  }

  bool _trySet(String attrName, LDValue value, bool private) {
    if (attrName.isEmpty) {
      return false;
    }

    switch (attrName) {
      case _kindAttr:
      case _keyAttr:
      case _metaAttr:
        return false;
      case _nameAttr:
        if (value.type != LDValueType.string) {
          return false;
        }

        name(value.stringValue());
      case _anonymousAttr:
        if (value.type != LDValueType.boolean) {
          return false;
        }

        anonymous(value.booleanValue());
      default:
        if (value.type == LDValueType.nullType) {
          _attributes.remove(attrName);
        } else {
          _attributes[attrName] = value;
        }
    }

    if (private) {
      _privateAttributes.add(AttributeReference.fromLiteral(attrName));
    }
    return true;
  }

  /// Mark additional attributes as private. This will add additional
  /// private attributes, it will not replace existing attributes that have
  /// been added using [addPrivateAttributes]. Each string
  /// should be in attribute reference format, not literal names.
  ///
  /// The attributes 'key', 'kind', '_meta', and 'anonymous' cannot be
  /// private. Adding them to the private attributes will have no effect.
  LDAttributesBuilder addPrivateAttributes(List<String> private) {
    private
        .map((refStr) => AttributeReference(refStr))
        .where((ref) => ref.valid)
        .forEach(_privateAttributes.add);
    return this;
  }

  /// Creates a [LDContextAttributes] from the current properties.  If any
  /// attributes are invalid, they are dropped.  If required attributes are
  /// invalid or missing, null is returned.
  ///
  /// The [LDContextAttributes] is immutable and will not be affected by
  /// any subsequent actions on the [LDAttributesBuilder].
  LDContextAttributes? _build() {
    final key = _key ?? '';
    if (key == '' && !_anonymous) {
      // If the context is not anonymous, then the key cannot be empty.
      return null;
    }
    if (_validKind(_kind)) {
      return LDContextAttributes._internal(
          // create immutable shallow copy
          Map.unmodifiable(_attributes),
          _kind,
          _key ?? '',
          _anonymous,
          _privateAttributes,
          _name);
    }
    return null;
  }
}

/// A collection of attributes that can be referenced in flag evaluations and analytics events.  A
/// [LDContext] may contain information about a single context or multiple contexts differentiated by
/// the "kind" attribute.
///
/// Besides the kind and key (required), [LDContext] supports built in attributes (optional to use)
/// and also custom attributes.
///
/// For a more complete description of context attributes and how they can be referenced in feature flag rules, see the
/// reference guide on [setting user attributes](https://docs.launchdarkly.com/home/contexts/attributes) and
/// [targeting users](https://docs.launchdarkly.com/home/flags/targeting).
final class LDContext {
  final Map<String, LDContextAttributes> attributesByKind;
  final bool valid;

  /// The canonical key and the kind-key map are generated once on demand and
  /// subsequently these memo fields will be used.
  String? _canonicalKeyMemo;
  Map<String, String>? _keysMemo;

  LDContext._valid(this.attributesByKind) : valid = true;

  LDContext._invalid()
      : attributesByKind = {},
        valid = false;

  /// Get the canonical key for the context.
  ///
  /// An invalid context cannot be used to generate a key, so an empty
  /// string will be returned.
  String get canonicalKey {
    if (!valid) {
      return '';
    }
    if (_canonicalKeyMemo != null) {
      return _canonicalKeyMemo!;
    }

    if (attributesByKind.length == 1 && attributesByKind.containsKey('user')) {
      return attributesByKind['user']!.key;
    }

    final kinds = attributesByKind.keys.toList(growable: false);
    kinds.sort();
    _canonicalKeyMemo = kinds
        .map((kind) => '$kind:${_encodeKey(attributesByKind[kind]!.key)}')
        .join(':');

    return _canonicalKeyMemo!;
  }

  /// Get a map of all the context kinds and their keys.
  ///
  /// An invalid context cannot be used to access a set of kinds and keys and
  /// an empty map will be returned.
  ///
  /// The returned map is immutable.
  Map<String, String> get keys {
    if (!valid) {
      return {};
    }
    if (_keysMemo != null) {
      return _keysMemo!;
    }

    final kinds = attributesByKind.keys.toList(growable: false);
    final kindsAndKeys = <String, String>{};
    for (var kind in kinds) {
      kindsAndKeys[kind] = attributesByKind[kind]!.key;
    }
    _keysMemo = Map.unmodifiable(kindsAndKeys);
    return _keysMemo!;
  }

  /// For the given context kind get an attribute using a reference.
  /// If the attribute does not exist, then a null LDValue type will
  /// be returned.
  LDValue get(String kind, AttributeReference reference) {
    return attributesByKind[kind]?._get(reference) ?? LDValue.ofNull();
  }

  @override
  String toString() {
    return 'LDContext{attributesByKind: $attributesByKind, valid: $valid}';
  }

  /// Determine if two contexts are equal.
  ///
  /// Note that all invalid contexts are equal. If a context cannot be built,
  /// because it contains invalid data, then it does not contain data which
  /// differentiates it from other invalid contexts. It is not generally
  /// meaningful to compare invalid contexts.
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is LDContext &&
          attributesByKind.equals(other.attributesByKind) &&
          valid == other.valid;

  @override
  int get hashCode =>
      Object.hashAllUnordered(attributesByKind.keys) ^
      Object.hashAllUnordered(attributesByKind.values) ^
      valid.hashCode;
}

/// A builder to facilitate the creation of [LDContext]s.  Note that the return
/// type of [kind] is a [LDAttributesBuilder] that is used to define attributes for
/// the specific kind of context you are creating.
///
/// ```dart
/// LDContextBuilder builder = LDContextBuilder();
/// builder.kind('user', 'user-key-123abc')
///   .name('Sandy Smith')
///   .setString('employeeID', 'ID-1234');
/// builder.kind('company', 'company-key-123abc')
///   .name('ExampleCompany');
/// builder.kind('options', 'options-key-123abc')
///   .setValue('advanced', LDValue.buildObject().addBool('poweruser', true).build())
/// LDContext context = builder.build();
/// ```
final class LDContextBuilder {
  final Map<String, LDAttributesBuilder> _buildersByKind = {};

  LDContextBuilder();

  /// Create a context builder from an existing context. If the context is
  /// not valid, then no attributes will be transcribed.
  LDContextBuilder.fromContext(LDContext context) {
    mergeContext(context);
  }

  // TODO: sc-228366 eliminate as part of improving auto env decorator
  /// Adds a context to the context builder combining the provided context
  /// kinds with the existing kinds in the builder.  This function is not
  /// normally needed as the [kind] method can be used for making a
  /// multi-context.
  LDContextBuilder mergeContext(LDContext context) {
    for (var MapEntry(key: kind, value: attributes)
        in context.attributesByKind.entries) {
      final attributesBuilder = this.kind(kind, attributes.key);
      attributesBuilder.anonymous(attributes.anonymous);
      if (attributes.name != null) {
        attributesBuilder.name(attributes.name!);
      }
      attributesBuilder._privateAttributes.addAll(attributes.privateAttributes);
      for (var MapEntry(key: name, value: attributeValue)
          in attributes.customAttributes.entries) {
        attributesBuilder.setValue(name, attributeValue);
      }
    }
    return this;
  }

  /// Adds another kind to the context.  [kind] and optional [key] must be
  /// non-empty.  Calling this method again with the same kind returns the same
  /// [LDAttributesBuilder] as before.
  ///
  /// If key is omitted, this will create an anonymous context with a generated key.
  /// The generated key will be persisted and reused for future application runs.
  LDAttributesBuilder kind(String kind, [String? key]) {
    LDAttributesBuilder builder = _buildersByKind.putIfAbsent(
        kind, () => LDAttributesBuilder._internal(this, kind));

    if (key != null) {
      // key may be different on this subsequent call, so need to update it.
      builder._key = key;
    }

    return builder;
  }

  /// Builds the context.
  LDContext build() {
    Map<String, LDContextAttributes> contextsByKind = {};
    for (final MapEntry(key: kind, value: builder) in _buildersByKind.entries) {
      LDContextAttributes? attributes = builder._build();
      // Component context was invalid. When this context is used for an
      // evaluation a log entry will be emitted which will let the developer
      // narrow down the reason.
      if (attributes == null) {
        return LDContext._invalid();
      }
      contextsByKind[kind] = attributes;
    }
    // Must contain at least 1 context.
    if (contextsByKind.isEmpty) {
      return LDContext._invalid();
    }
    return LDContext._valid(Map.unmodifiable(contextsByKind));
  }
}
