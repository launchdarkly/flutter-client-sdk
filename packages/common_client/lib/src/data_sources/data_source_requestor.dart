import 'dart:async';
import 'package:http/http.dart' as http;
import 'package:launchdarkly_dart_common/launchdarkly_dart_common.dart';
import '../config/defaults/credential_type.dart';
import '../config/defaults/default_config.dart';
import 'data_source.dart';
import 'data_source_status.dart';
import 'get_environment_id.dart';

class RequestResult {
  final DataSourceEvent? event;
  final bool shouldRetry;
  final bool shutdown;

  RequestResult({this.event, this.shouldRetry = false, this.shutdown = false});
}

class DataSourceRequestor {
  final HttpClient _client;
  final LDLogger _logger;
  final String _credential;

  int _currentChainId = 0;
  String? _lastEtag;

  DataSourceRequestor({
    required HttpClient client,
    required LDLogger logger,
    required String credential,
  })  : _client = client,
        _logger = logger,
        _credential = credential;

  int startRequestChain() {
    return ++_currentChainId;
  }

  bool isValidChain(int chainId) {
    return chainId == _currentChainId;
  }

  Future<http.Response> makeRequest(
    int chainId,
    Uri uri,
    RequestMethod method, {
    String? body,
    Map<String, String>? additionalHeaders,
  }) async {
    if (!isValidChain(chainId)) {
      throw Exception('Request chain $chainId is no longer valid');
    }

    final headers = _buildHeaders(additionalHeaders);
    _logger.debug(
        'Making request for chain $chainId, method: $method, uri: $uri, etag: $_lastEtag');

    return await _client.request(method, uri,
        additionalHeaders: headers, body: body);
  }

  RequestResult? processResponse(
    http.Response res,
    int chainId, {
    required bool Function(int) isRecoverableStatus,
  }) {
    if (!isValidChain(chainId)) {
      _logger.debug('Discarding response from stale request chain $chainId');
      return null;
    }

    final statusCode = res.statusCode;

    if (statusCode == 200 || statusCode == 304) {
      if (statusCode == 200) {
        _updateEtagFromResponse(res);
        final environmentId = _getEnvironmentIdFromHeaders(res.headers);
        return RequestResult(
          event: DataEvent('put', res.body, environmentId: environmentId),
        );
      }
      return RequestResult();
    }

    if (isRecoverableStatus(statusCode)) {
      _logger.debug(
          'Received recoverable status code $statusCode for chain $chainId, will retry');
      return RequestResult(shouldRetry: true);
    }

    _logger.error(
        'Received unexpected status code $statusCode for chain $chainId, shutting down');
    return RequestResult(
      event: StatusEvent(
        ErrorKind.networkError,
        statusCode,
        'Received unexpected status code: $statusCode',
        shutdown: true,
      ),
      shutdown: true,
    );
  }

  Map<String, String>? _buildHeaders(Map<String, String>? additionalHeaders) {
    if (_lastEtag == null && additionalHeaders == null) {
      return null;
    }

    final headers = <String, String>{};
    if (_lastEtag != null) {
      headers['if-none-match'] = _lastEtag!;
    }
    if (additionalHeaders != null) {
      headers.addAll(additionalHeaders);
    }
    return headers;
  }

  void _updateEtagFromResponse(http.Response res) {
    final etag = res.headers['etag'];
    if (etag != null) {
      _lastEtag = etag;
    }
  }

  String? _getEnvironmentIdFromHeaders(Map<String, String>? headers) {
    var environmentId = getEnvironmentId(headers);
    if (environmentId == null &&
        DefaultConfig.credentialConfig.credentialType ==
            CredentialType.clientSideId) {
      environmentId = _credential;
    }
    return environmentId;
  }
}
