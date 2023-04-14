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
/// builder.kind('user', 'user-key-123abc').name('Sandy Smith').set('employeeID', LDValue.ofString('ID-1234'));
/// builder.kind('company', 'company-key-123abc').name('Microsoft');
/// LDContext context = builder.build();
/// ```
class LDContextBuilder {

  final Map<String, LDAttributesBuilder> _buildersByKind = Map();

  /// Adds another kind to the context.  Both [kind] and [key] must be
  /// non-empty.  Calling this method again with the same kind returns
  /// the same [LDAttributesBuilder] as before.
  LDAttributesBuilder kind(String kind, String key) {
    LDAttributesBuilder attrBuilder =
        LDAttributesBuilder._internal(kind, key);
    return _buildersByKind.putIfAbsent(kind, () => attrBuilder);
  }

  /// Builds the context.  At the moment this Flutter SDK and therefore
  /// this [build] method does not perform attribute validation until the [LDContext]
  /// is used.  This may be subject to change in the future.
  LDContext build() {
    Map<String, LDContextAttributes> contextsByKind = Map();
    _buildersByKind.forEach((kind, b) {
      contextsByKind[kind] = b._build();
    });
    return LDContext._internal(Map.unmodifiable(contextsByKind));
  }
}
