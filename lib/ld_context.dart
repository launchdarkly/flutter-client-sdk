// @dart=2.12
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
/// builder.kind('user').key('user-key-123abc').name('Sandy Smith').set('employeeID', LDValue.ofString('ID-1234'));
/// builder.kind('company').key('company-key-123abc').name('Microsoft');
/// LDContext context = builder.build();
/// ```
class LDContextBuilder {
  final Map<String, LDAttributesBuilder> _buildersByKind = Map();

  /// Adds another kind to the context.  [kind] must be non-empty.
  /// Calling this method again with the same kind returns the same
  /// [LDAttributesBuilder] as before.
  ///
  /// By default, this will create an anonymous context with a generated key.
  /// This key will be cached locally and reused for the same context kind
  /// unless manually set via [LDAttributesBuilder.key]
  LDAttributesBuilder kind(String kind) {
    LDAttributesBuilder attrBuilder = LDAttributesBuilder._internal(kind);
    return _buildersByKind.putIfAbsent(kind, () => attrBuilder);
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
