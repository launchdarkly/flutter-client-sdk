import 'dart:collection';

const _envIdHeader = 'x-ld-envid';

/// Get the environment ID from headers.
String? getEnvironmentId(Map<String, String>? headers) {
  return headers?[_envIdHeader];
}
