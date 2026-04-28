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
/// does no FDv2 protocol parsing or error classification -- that is the
/// responsibility of the caller (see [FDv2PollingBase]).
///
/// One [FDv2Requestor] is bound to a single evaluation context. Switching
/// contexts requires a fresh instance so a previous context's `ETag`
/// can never leak into a request for a different context.
///
/// Calls to [request] are not safe to interleave on a single instance --
/// `ETag` tracking assumes serial requests. Callers (the polling
/// synchronizer) must wait for each [request] to complete before issuing
/// the next.
final class FDv2Requestor {
  final LDLogger _logger;
  final HttpClient _client;
  final Uri _baseUri;
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
        _baseUri = Uri.parse(endpoints.polling),
        _contextEncoded = contextEncoded,
        _contextJson = contextJson,
        _usePost = usePost,
        _withReasons = withReasons,
        _client = httpClientFactory(usePost
            ? httpProperties.withHeaders({'content-type': 'application/json'})
            : httpProperties);

  /// Sends a single poll request, optionally including a [basis] selector
  /// for delta updates. Throws on network errors; otherwise returns the
  /// response. Tracks `ETag` across successful (`200`) responses on this
  /// instance.
  Future<RequestorResponse> request({Selector basis = Selector.empty}) async {
    final uri = _buildUri(basis: basis);
    final method = _usePost ? RequestMethod.post : RequestMethod.get;
    final additionalHeaders = <String, String>{};
    if (_lastEtag != null) {
      additionalHeaders['if-none-match'] = _lastEtag!;
    }

    // Avoid logging the full URI -- in GET mode it embeds the
    // base64url-encoded context, which is reversible PII.
    _logger.debug('FDv2 poll: method=$method, hasEtag=${_lastEtag != null}, '
        'hasBasis=${basis.isNotEmpty}');

    final response = await _client.request(
      method,
      uri,
      additionalHeaders: additionalHeaders.isEmpty ? null : additionalHeaders,
      body: _usePost ? _contextJson : null,
    );

    // Only persist the ETag from a successful response. Non-200 responses
    // could carry stale or hostile ETag values that would taint future
    // conditional requests. A 304 confirms the existing ETag still matches,
    // so leaving the stored value alone is correct.
    if (response.statusCode == 200) {
      final etag = response.headers['etag'];
      if (etag != null) {
        _lastEtag = etag;
      }
    }

    return (
      status: response.statusCode,
      headers: response.headers,
      body: response.body,
    );
  }

  Uri _buildUri({required Selector basis}) {
    final addedPath = _usePost
        ? FDv2Endpoints.polling
        : FDv2Endpoints.pollingGet(_contextEncoded);

    // Compose against the parsed base URI so a custom polling URL
    // carrying its own query parameters (e.g. a relay proxy with a token)
    // is preserved correctly. String concatenation against `_baseUri`
    // would land the appended path inside the query component.
    final basePath = _baseUri.path.endsWith('/')
        ? _baseUri.path.substring(0, _baseUri.path.length - 1)
        : _baseUri.path;
    final mergedPath = '$basePath$addedPath';

    final mergedQuery = <String, String>{};
    mergedQuery.addAll(_baseUri.queryParameters);
    if (_withReasons) {
      mergedQuery['withReasons'] = 'true';
    }
    if (basis.isNotEmpty && basis.state!.isNotEmpty) {
      mergedQuery['basis'] = basis.state!;
    }

    return _baseUri.replace(
      path: mergedPath,
      queryParameters: mergedQuery.isEmpty ? null : mergedQuery,
    );
  }
}
