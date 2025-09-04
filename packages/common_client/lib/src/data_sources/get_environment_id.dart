const _envIdHeader = 'x-ld-envid';

final _splitRegex = RegExp(r'\s*,\s*');

/// Get the environment ID from headers.
String? getEnvironmentId(Map<String, String>? headers) {
  // Headers will always be in lower case from the http response.
  // If multiple headers are associated with a single key, then they will be
  // in a comma separated list with potential whitespace.
  final headerValue = headers?[_envIdHeader];
  if (headerValue == null) {
    return null;
  }
  return headerValue.split(_splitRegex).first;
}
