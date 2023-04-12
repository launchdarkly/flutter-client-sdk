// @dart=2.12
part of launchdarkly_flutter_client_sdk;

// TODO: review making these package private, but still being able to test them
extension ContextCodec on LDContext {

    // TODO: review this method being public, try to make package private.  Same for other toCodecValue methods in codebase
    List<dynamic> toCodecValue() {
      final List<dynamic> result = <dynamic>[];
      contextsByKind.forEach((_, value) {
        result.add(value.toCodecValue());
      });
      return result;
    }
}

extension ContextAttributesCodec on LDContextAttributes {

  Map<String, dynamic> toCodecValue() {
    final Map<String, dynamic> result = <String, dynamic>{};
    result['kind'] = kind;
    result['key'] = key;
    result['anonymous'] = anonymous;
    result['name'] = name;

    // TODO: determine if custom is even necessary anymore, isn't everything
    // else custom and at the same level?
    result['custom'] = custom.map((key, value) => MapEntry(key, value.codecValue()));
    result['privateAttributeNames'] = privateAttributeNames;
    return result;
  }
}

extension UserCodec on LDUser {

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


