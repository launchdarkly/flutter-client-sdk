// @dart=3.1
part of launchdarkly_flutter_client_sdk;

/// A collection of attributes that can be referenced in flag evaluations and analytics events.  A
/// [LDContext] may contain information about a single context or multiple contexts differentiated by
/// the "kind" attribute.
///
/// Besides the kind and key (required), [LDContext] supports built in attributes (optional to use)
/// and also custom attributes.
///
/// [LDContext] is the newer replacement for the previous, less flexible [LDUser] type.
///
/// For a more complete description of context attributes and how they can be referenced in feature flag rules, see the
/// reference guide on [setting user attributes](https://docs.launchdarkly.com/home/contexts/attributes) and
/// [targeting users](https://docs.launchdarkly.com/home/flags/targeting).
class LDContext {
  final Map<String, LDContextAttributes> attributesByKind;

  LDContext._internal(this.attributesByKind);
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
class LDContextBuilder {
  final Map<String, LDAttributesBuilder> _buildersByKind = Map();

  /// Adds another kind to the context.  [kind] and optional [key] must be
  /// non-empty.  Calling this method again with the same kind returns the same
  /// [LDAttributesBuilder] as before.
  ///
  /// If key is omitted, this will create an anonymous context with a generated key.
  /// The generated key will be persisted and reused for future application runs.
  LDAttributesBuilder kind(String kind, [String? key]) {
    LDAttributesBuilder builder = _buildersByKind.putIfAbsent(
        kind, () => LDAttributesBuilder._internal(kind));

    if (key != null) {
      // key may be different on this subsequent call, so need to update it.
      builder._key(key);
    }

    return builder;
  }

  /// Builds the context.
  LDContext build() {
    Map<String, LDContextAttributes> contextsByKind = Map();
    _buildersByKind.forEach((kind, b) {
      // attempt to build
      LDContextAttributes? attributes = b._build();

      // if build fails, ignore
      if (attributes != null) {
        contextsByKind[kind] = attributes;
      } else {
        log("Ignoring context of kind $kind");
      }
    });
    return LDContext._internal(Map.unmodifiable(contextsByKind));
  }
}
