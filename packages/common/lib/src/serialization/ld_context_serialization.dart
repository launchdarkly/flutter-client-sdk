import '../ld_context.dart';
import '../attribute_reference.dart';
import '../ld_value.dart';
import '../collections.dart';
import 'ld_value_serialization.dart';

void _executeIfNotRedacted(
    bool isEvent,
    bool allAttributesPrivate,
    Map<String, dynamic> container,
    List<String> components,
    Set<AttributeReference> privateAttributes,
    Set<AttributeReference> redactions,
    Function work) {
  if (isEvent && allAttributesPrivate) {
    redactions.add(AttributeReference.fromComponents(components));
    return;
  }
  if (isEvent) {
    // This searches for equality by components. We could make a reference and
    // check if it is in the set, but this will generate less intermediate garbage.
    var matched = privateAttributes
        .firstWhereOrNull((element) => element.components.equals(components));
    if (matched != null) {
      redactions.add(matched);
      return;
    }
  }
  work();
}

/// Given an LDValue, that is an object, serialize it and perform any needed
/// redactions if being serialized for an event.
void _redactInLDValueObject(
    Map<String, dynamic> container,
    List<String> parentComponents,
    LDValue object,
    bool isEvent,
    bool allAttributesPrivate,
    Set<AttributeReference> privateAttributes,
    Set<AttributeReference> redactions) {
  final Map<String, LDValue> result = {};
  for (var key in object.keys) {
    final value = object.getFor(key);
    final components = [...parentComponents, key];

    _redactInValue(isEvent, allAttributesPrivate, result, components,
        privateAttributes, redactions, value, container, key);
  }
}

/// Given a map of LDValues, serialize them and perform any needed redactions
/// if being serialized for an event.
void _redactInValueMap(
  Map<String, dynamic> container,
  List<String> parentComponents,
  Map<String, LDValue> values,
  bool isEvent,
  bool allAttributesPrivate,
  Set<AttributeReference> privateAttributes,
  Set<AttributeReference> redactions,
) {
  final Map<String, LDValue> result = {};
  for (var MapEntry(key: key, value: value) in values.entries) {
    final components = [...parentComponents, key];

    _redactInValue(isEvent, allAttributesPrivate, result, components,
        privateAttributes, redactions, value, container, key);
  }
}

/// Given an LDValue, which may be of any kind, serialize it and perform
/// any needed redactions if being serialized for an event.
void _redactInValue(
    bool isEvent,
    bool allAttributesPrivate,
    Map<String, LDValue> result,
    List<String> components,
    Set<AttributeReference> privateAttributes,
    Set<AttributeReference> redactions,
    LDValue value,
    Map<String, dynamic> container,
    String key) {
  _executeIfNotRedacted(isEvent, allAttributesPrivate, result, components,
      privateAttributes, redactions, () {
    if (value.type == LDValueType.object) {
      final Map<String, dynamic> nested = {};
      _redactInLDValueObject(nested, components, value, isEvent,
          allAttributesPrivate, privateAttributes, redactions);
      container[key] = nested;
      return;
    }
    container[key] = LDValueSerialization.toJson(value);
  });
}

final class _LDContextAttributesSerialization {
  static Map<String, dynamic> toJson(LDContextAttributes attributes,
      {required bool isEvent,
      required bool allAttributesPrivate,
      Set<AttributeReference>? globalPrivateAttributes}) {
    Map<String, dynamic> result = {};
    result['key'] = attributes.key;
    if (attributes.anonymous) {
      result['anonymous'] = attributes.anonymous;
    }

    final Set<AttributeReference> combinedPrivateAttributes = isEvent
        ? {...attributes.privateAttributes, ...(globalPrivateAttributes ?? {})}
        : {};

    final Set<AttributeReference> redactions = {};

    if (attributes.name?.isNotEmpty ?? false) {
      _executeIfNotRedacted(isEvent, allAttributesPrivate, result, ['name'],
          combinedPrivateAttributes, redactions, () {
        result['name'] = attributes.name;
      });
    }

    _redactInValueMap(result, [], attributes.customAttributes, isEvent,
        allAttributesPrivate, combinedPrivateAttributes, redactions);

    _addMetaAttributes(isEvent, redactions, attributes, result);

    return result;
  }

  static void _addMetaAttributes(
      bool isEvent,
      Set<AttributeReference> redactions,
      LDContextAttributes attributes,
      Map<String, dynamic> result) {
    Map<String, dynamic> meta = {};

    if (isEvent && redactions.isNotEmpty) {
      meta['redactedAttributes'] =
          redactions.map((ref) => ref.redactionName).toList(growable: false);
    } else if (!isEvent && attributes.privateAttributes.isNotEmpty) {
      meta['privateAttributes'] = attributes.privateAttributes
          .map((ref) => ref.redactionName)
          .toList(growable: false);
    }

    if (meta.isNotEmpty) {
      result['_meta'] = meta;
    }
  }
}

final class LDContextSerialization {
  /// Convert a context into its serialized representation.
  ///
  /// A context can be serialized for either an event, or as a complete context
  /// which could be deserialized back to its original form. This method supports
  /// both use cases.
  ///
  /// When [isEvent] is set to true, then event serialization is done. This
  /// will redact private attributes and catalogue their redaction in _meta.
  ///
  /// If [isEvent] is true, and [allAttributesPrivate] is also true, then
  /// all attributes in the context will be redacted.
  ///
  /// if [isEvent] is true, and [globalPrivateAttributes] contains attribute
  /// references, then those attributes will be redacted in all context
  /// kinds.
  ///
  /// if [isEvent] is true, and [redactAnonymous] is true, then for any
  /// anonymous context provided, all attributes will be redacted regardless of
  /// the [allAttributesPrivate] or [globalPrivateAttributes] settings.
  ///
  /// Attempting to serialize an invalid context will return null.
  static Map<String, dynamic>? toJson(LDContext context,
      {required bool isEvent,
      bool allAttributesPrivate = false,
      Set<AttributeReference>? globalPrivateAttributes,
      bool redactAnonymous = false}) {
    if (!context.valid) {
      // Cannot serialize an invalid context.
      return null;
    }
    if (context.attributesByKind.length == 1) {
      final attributes = context.attributesByKind.values.first;
      _LDContextAttributesSerialization.toJson(attributes,
          isEvent: isEvent,
          allAttributesPrivate: allAttributesPrivate,
          globalPrivateAttributes: globalPrivateAttributes);
      Map<String, dynamic> result = {
        ..._LDContextAttributesSerialization.toJson(attributes,
            isEvent: isEvent,
            allAttributesPrivate: allAttributesPrivate ||
                (redactAnonymous && attributes.anonymous),
            globalPrivateAttributes: globalPrivateAttributes)
      };
      result['kind'] = attributes.kind;
      return result;
    } else {
      Map<String, dynamic> result = {};
      result['kind'] = 'multi';
      for (var attributes in context.attributesByKind.values) {
        result[attributes.kind] = _LDContextAttributesSerialization.toJson(
            attributes,
            isEvent: isEvent,
            allAttributesPrivate: allAttributesPrivate ||
                (redactAnonymous && attributes.anonymous),
            globalPrivateAttributes: globalPrivateAttributes);
      }
      return result;
    }
  }
}
