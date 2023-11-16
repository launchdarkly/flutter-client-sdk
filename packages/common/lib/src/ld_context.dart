import 'ld_value.dart';
import 'attribute_reference.dart';

RegExp _kindExp = RegExp(r'^(\w|\.|-)+$');

const String _kindAttr = "kind";
const String _keyAttr = "key";
const String _nameAttr = "name";
const String _anonymousAttr = "anonymous";
const String _metaAttr = "_meta";

String _encodeKey(String key) {
  if (key.contains('%') || key.contains(':')) {
    // Keys should be small, so this should be fine, but we could
    // use replaceAllMapped if we need to gain some performance.
    return key.replaceAll('%', '%25').replaceAll(':', '%3A');
  }
  return key;
}

bool _validKind(String kind) {
  return kind != "kind" && _kindExp.hasMatch(kind);
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

  /// Sets the value of any attribute for the Context.
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
  /// - "anonymous"
  /// - "name"
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
  LDAttributesBuilder set(String name, LDValue value) {
    _trySet(name, value);

    return this;
  }

  /// Sets the value of any attribute for the Context and mark it as private.
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
  /// - "anonymous"
  /// - "name"
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
  LDAttributesBuilder setPrivate(String name, LDValue value) {
    if (_trySet(name, value)) {
      _privateAttributes.add(AttributeReference.fromLiteral(name));
    }
    return this;
  }

  bool _trySet(String name, LDValue value) {
    if (_canSet(name, value)) {
      if (value.type == LDValueType.nullType) {
        _attributes.remove(value.stringValue());
        return true;
      }
      _attributes[name] = value;
      return true;
    }

    return false;
  }

  /// Mark additional attributes as private. This will add additional
  /// private attributes, it will not replace existing attributes that have
  /// been added using [addPrivateAttributes] or [setPrivate]. Each string
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

  /// Set the name of the context.
  LDAttributesBuilder name(String name) {
    _name = name;
    return this;
  }

  /// Creates a [LDContextAttributes] from the current properties.  If any
  /// attributes are invalid, they are dropped.  If required attributes are
  /// invalid or missing, null is returned.
  ///
  /// The [LDContextAttributes] is immutable and will not be affected by
  /// any subsequent actions on the [LDAttributesBuilder].
  LDContextAttributes? _build() {
    // TODO: Add anonymous key generation.
    if (_key != null && _validKind(_kind) && _key != "") {
      return LDContextAttributes._internal(
          // create immutable shallow copy
          Map.unmodifiable(_attributes),
          _kind,
          _key!,
          _anonymous,
          _privateAttributes,
          _name);
    }
    return null;
  }

  static bool _canSet(String name, LDValue value) {
    if (name.isEmpty) {
      return false;
    }

    switch (name) {
      case _kindAttr:
      case _keyAttr:
      case _nameAttr:
      case _anonymousAttr:
      case _metaAttr:
        return false;
      default:
        return true;
    }
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

  LDContext._valid(this.attributesByKind) : valid = true;

  LDContext._invalid()
      : attributesByKind = {},
        valid = false;

  String get canonicalKey {
    if (attributesByKind.length == 1 && attributesByKind.containsKey('user')) {
      return attributesByKind['user']!.key;
    }

    final kinds = attributesByKind.keys.toList();
    kinds.sort();
    return kinds
        .map((kind) => '$kind:${_encodeKey(attributesByKind[kind]!.key)}')
        .join(":");
  }

  /// For the given context kind get an attribute using a reference.
  /// If the attribute does not exist, then a null LDValue type will
  /// be returned.
  LDValue get(String kind, AttributeReference reference) {
    return attributesByKind[kind]?._get(reference) ?? LDValue.ofNull();
  }
}

/// A builder to facilitate the creation of [LDContext]s.  Note that the return
/// type of [kind] is a [LDAttributesBuilder] that is used to define attributes for
/// the specific kind of context you are creating.
///
/// ```dart
/// LDContextBuilder builder = LDContextBuilder();
/// builder.kind('user', 'user-key-123abc').name('Sandy Smith').set('employeeID', LDValue.ofString('ID-1234'));
/// builder.kind('company', 'company-key-123abc').name('Microsoft');
/// LDContext context = builder.build();
/// ```
final class LDContextBuilder {
  final Map<String, LDAttributesBuilder> _buildersByKind = {};

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
