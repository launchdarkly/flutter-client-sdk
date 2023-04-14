// @dart=2.12
part of launchdarkly_flutter_client_sdk;

/// Extension functionality for converting [LDContext] to value that can
/// be ingested as method channel arguments
extension ContextCodec on LDContext {

  @visibleForTesting
  List<dynamic> toCodecValue() {
    final List<dynamic> result = <dynamic>[];
    attributesByKind.forEach((_, value) {
      result.add(value.toCodecValue());
    });
    return result;
  }
}
/// Extension functionality for converting [LDContextAttributes] to value that can
/// be ingested as method channel arguments
extension ContextAttributesCodec on LDContextAttributes {

  @visibleForTesting
  Map<String, dynamic> toCodecValue() {
    final Map<String, dynamic> result = <String, dynamic>{};
    attributes.forEach((key, value) {
      result[key] = value.codecValue();
    });

    // TODO sc-195759: Support private attributes
    return result;
  }
}

/// Extension functionality for converting [toCodecValue] to value that can
/// be ingested as method channel arguments
extension UserCodec on LDUser {

  @visibleForTesting
  Map<String, dynamic> toCodecValue() {
    final Map<String, dynamic> result = <String, dynamic>{};
    result['key'] = key;
    result['anonymous'] = anonymous;
    result['ip'] = ip;
    result['email'] = email;
    result['name'] = name;
    result['firstName'] = firstName;
    result['lastName'] = lastName;
    result['avatar'] = avatar;
    result['country'] = country;
    result['custom'] = custom?.map((key, value) => MapEntry(key, value.codecValue()));
    result['privateAttributeNames'] = privateAttributeNames;
    return result;
  }

}


