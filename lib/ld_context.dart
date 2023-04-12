// @dart=2.12
part of launchdarkly_flutter_client_sdk;

class LDContext {

  // TODO: add comment.
  // kind to context attributes
  final Map<String, LDContextAttributes> contextsByKind;

  // TODO: verify unnamed private constructor is appropriate way to prevent instantiation by outside packages.  Some examples use _internal
  LDContext._internal(this.contextsByKind);

}

class LDContextBuilder {

  final Map<String, _ContextAttributesBuilder> _buildersByKind = Map();

  // TODO: come back and see if you can get builder.kind().name().kind().name() to work with some clever templating or interfacing in Dart
  // TODO: verify key is non-nullable
  _ContextAttributesBuilder kind(String kind, String key) {
    return _buildersByKind.putIfAbsent(kind, () => _ContextAttributesBuilder._internal(kind, key));
  }

  LDContext build() {

    Map<String, LDContextAttributes> contextsByKind = Map();
    _buildersByKind.forEach((kind, b) {
      contextsByKind[kind] = b._build();
    });

    return LDContext._internal(Map.unmodifiable(contextsByKind));
  }
}