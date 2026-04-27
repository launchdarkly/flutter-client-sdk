import 'package:launchdarkly_dart_common/launchdarkly_dart_common.dart';

import 'endpoints.dart';
import 'selector.dart';

typedef HttpClientFactory = HttpClient Function(HttpProperties httpProperties);

HttpClient _defaultHttpClientFactory(HttpProperties httpProperties) {
  return HttpClient(httpProperties: httpProperties);
}

/// The shape of a completed HTTP response from the FDv2 polling endpoint.
typedef RequestorResponse = ({
  int status,
  Map<String, String> headers,
  String body,
});

/// Issues a single HTTP poll against the FDv2 polling endpoint.
///
/// Pure HTTP layer: builds the URL, sends the request, tracks `ETag`
/// across calls on the same instance, and returns the raw response. It
/// does no FDv2 protocol parsing or error classification — that is the
/// responsibility of the caller (see [FDv2PollingBase]).
///
/// One [FDv2Requestor] is bound to a single evaluation context. Switching
/// contexts requires a fresh instance so a previous context's `ETag`
/// can never leak into a request for a different context.
final class FDv2Requestor {
  final LDLogger _logger;
  final HttpClient _client;
  final String _baseUrl;
  final String _contextEncoded;
  final String _contextJson;
  final bool _usePost;
  final bool _withReasons;
  String? _lastEtag;

  FDv2Requestor({
    required LDLogger logger,
    required ServiceEndpoints endpoints,
    required String contextEncoded,
    required String contextJson,
    required bool usePost,
    required bool withReasons,
    required HttpProperties httpProperties,
    HttpClientFactory httpClientFactory = _defaultHttpClientFactory,
  })  : _logger = logger.subLogger('FDv2Requestor'),
        _baseUrl = endpoints.polling,
        _contextEncoded = contextEncoded,
        _contextJson = contextJson,
        _usePost = usePost,
        _withReasons = withReasons,
        _client = httpClientFactory(usePost
            ? httpProperties.withHeaders({'content-type': 'application/json'})
            : httpProperties);

  /// Sends a single poll request, optionally including a [basis] selector
  /// for delta updates. Throws on network errors; otherwise returns the
  /// raw response. Tracks `ETag` for subsequent calls on this instance.
  Future<RequestorResponse> request({Selector basis = Selector.empty}) async {
    final uri = _buildUri(basis: basis);
    final method = _usePost ? RequestMethod.post : RequestMethod.get;
    final additionalHeaders = <String, String>{};
    if (_lastEtag != null) {
      additionalHeaders['if-none-match'] = _lastEtag!;
    }

    _logger.debug(
        'FDv2 poll: method=$method, uri=$uri, etag=$_lastEtag, basis=${basis.state}');

    final response = await _client.request(
      method,
      uri,
      additionalHeaders: additionalHeaders.isEmpty ? null : additionalHeaders,
      body: _usePost ? _contextJson : null,
    );

    final etag = response.headers['etag'];
    if (etag != null) {
      _lastEtag = etag;
    }

    return (
      status: response.statusCode,
      headers: response.headers,
      body: response.body,
    );
  }

  Uri _buildUri({required Selector basis}) {
    final path = _usePost
        ? FDv2Endpoints.polling
        : FDv2Endpoints.pollingGet(_contextEncoded);
    final queryParams = <String, String>{};
    if (_withReasons) {
      queryParams['withReasons'] = 'true';
    }
    if (basis.isNotEmpty) {
      queryParams['basis'] = basis.state!;
    }
    final url = appendPath(_baseUrl, path);
    final uri = Uri.parse(url);
    return queryParams.isEmpty
        ? uri
        : uri.replace(queryParameters: queryParams);
  }
}
