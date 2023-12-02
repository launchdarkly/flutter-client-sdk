import 'package:http/http.dart' as http;

import '../config/defaults/common_default_config.dart';
import '../config/http_properties.dart';

import 'platform_client/stub_client.dart'
    if (dart.library.io) 'platform_client/io_client.dart'
    if (dart.library.html) 'platform_client/js_client.dart';

/// Filter a set of headers to remove any headers that are not allowed.
///
/// This is primarily for web where a number of headers are forbidden from
/// modification by JavaScript.
///
Map<String, String> _filterHeaders(
    Set<String> forbidden, Map<String, String> headers) {
  Map<String, String> filteredHeaders = {};

  for (var entry in headers.entries) {
    if (!forbidden.contains(entry.key)) {
      filteredHeaders[entry.key] = entry.value;
    }
  }

  return filteredHeaders;
}

/// Http requests methods supported by the HTTP client.
enum RequestMethod {
  report('REPORT'),
  get('GET'),
  post('POST');

  final String stringValue;

  const RequestMethod(String value) : stringValue = value;

  @override
  String toString() {
    return stringValue;
  }
}

/// HttpClient which automatically handles io/web differences.
///
/// Headers will be filtered because the browser environment cannot accept all
/// headers.
///
/// The timeouts from the properties will be applied as possible.
final class HttpClient {
  final http.Client _client;
  final HttpProperties _httpProperties;
  final Set<String> _forbiddenHeaders;

  /// Construct an http client.
  ///
  /// The [client] and [forbiddenHeaders] values default to the appropriate
  /// values for the platform. They can be provided primarily for testing
  /// purposes.
  HttpClient(
      {required HttpProperties httpProperties,
      http.Client? client,
      Set<String>? forbiddenHeaders})
      : _httpProperties = httpProperties,
        _client = client ?? createClient(httpProperties),
        _forbiddenHeaders = forbiddenHeaders ??
            CommonDefaultConfig.networkConfig.restrictedHeaders;

  /// Make an HTTP request with the given [method] and [uri].
  Future<http.Response> request(RequestMethod method, Uri uri,
      {Map<String, String>? additionalHeaders, String? body}) async {
    final request = http.Request(method.stringValue, uri);

    final headers = additionalHeaders == null
        ? _httpProperties.baseHeaders
        : (<String, String>{}
          ..addAll(_httpProperties.baseHeaders)
          ..addAll(additionalHeaders));

    request.headers.addAll(_filterHeaders(_forbiddenHeaders, headers));
    if (body != null) {
      request.body = body;
    }

    // The write timeout is a applied a little liberally here as we do not
    // have a discrete steps for connecting and then writing.
    //
    // If this becomes a problem, then we could use the built-in http library
    // instead of the http package.
    //
    // The streamed request type does not solve this because it doesn't have
    // a deterministic point where the write is complete.
    final streamedResponse = await _client
        .send(request)
        .timeout(_httpProperties.writeTimeout + _httpProperties.connectTimeout);

    return await http.Response.fromStream(streamedResponse)
        .timeout(_httpProperties.readTimeout);
  }
}
