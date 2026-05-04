import 'dart:async';

import 'package:http/http.dart' as http;
import 'package:launchdarkly_dart_common/launchdarkly_dart_common.dart';

import '../config/data_source_config.dart';
import '../config/defaults/credential_type.dart';
import '../config/defaults/default_config.dart';
import 'data_source.dart';
import 'data_source_status.dart';
import 'get_environment_id.dart';

typedef HttpClientFactory = HttpClient Function(HttpProperties httpProperties);

HttpClient _defaultHttpClientFactory(HttpProperties httpProperties) {
  return HttpClient(httpProperties: httpProperties);
}

final class Requestor {
  String? _lastEtag;
  final LDLogger _logger;
  late final String _contextString;
  late final Uri _uri;
  final RequestMethod _method;
  final HttpClient _client;
  final String _credential;

  Requestor({
    required LDLogger logger,
    required String contextString,
    required RequestMethod method,
    required HttpProperties httpProperties,
    required String credential,
    required ServiceEndpoints endpoints,
    required PollingDataSourceConfig dataSourceConfig,
    HttpClientFactory httpClientFactory = _defaultHttpClientFactory,
  })  : _logger = logger,
        _contextString = contextString,
        _method = method,
        _client = httpClientFactory(method != RequestMethod.get
            ? httpProperties.withHeaders({'content-type': 'application/json'})
            : httpProperties),
        _credential = credential {
    String completeUrl;
    if (dataSourceConfig.useReport) {
      completeUrl = appendPath(endpoints.polling,
          dataSourceConfig.pollingReportPath(credential, _contextString));
    } else {
      completeUrl = appendPath(endpoints.polling,
          dataSourceConfig.pollingGetPath(credential, _contextString));
    }
    if (dataSourceConfig.withReasons) {
      completeUrl = '$completeUrl?withReasons=true';
    }

    _uri = Uri.parse(completeUrl);
  }

  Future<DataSourceEvent?> requestAllFlags() async {
    try {
      _logger.debug(
          'Making polling request, method: $_method, hasEtag: ${_lastEtag != null}');
      final additionalHeaders = switch (_lastEtag) {
        final etag? => {'if-none-match': etag},
        null => null,
      };
      final res = await _client.request(_method, _uri,
          additionalHeaders: additionalHeaders,
          body: _method != RequestMethod.get ? _contextString : null);
      return await _handleResponse(res);
    } catch (err) {
      // Don't echo the raw exception. `http.ClientException`'s
      // `toString()` formats as `'ClientException: <msg>, uri=<full-url>'`,
      // and the URL embeds the base64url-encoded context in GET mode.
      // Categorize into a fixed message and use that everywhere.
      final sanitized = _describeError(err);
      _logger.warn('Polling request failed: $sanitized');
      return StatusEvent(ErrorKind.networkError, null, sanitized);
    }
  }

  Future<DataSourceEvent?> _handleResponse(http.Response res) async {
    if (res.statusCode == 304) {
      // Server confirmed our cached payload is still current.
      return null;
    }
    if (res.statusCode == 200) {
      _lastEtag = res.headers['etag'];

      var environmentId = getEnvironmentId(res.headers);

      if (environmentId == null &&
          DefaultConfig.credentialConfig.credentialType ==
              CredentialType.clientSideId) {
        // When using a client-side ID we can use it to represent the
        // environment.
        environmentId = _credential;
      }

      return DataEvent('put', res.body, environmentId: environmentId);
    }
    if (isHttpGloballyRecoverable(res.statusCode)) {
      return StatusEvent(ErrorKind.errorResponse, res.statusCode,
          'Received unexpected status code: ${res.statusCode}');
    }
    return StatusEvent(ErrorKind.errorResponse, res.statusCode,
        'Received unexpected status code: ${res.statusCode}',
        shutdown: true);
  }

  String _describeError(Object err) {
    if (err is TimeoutException) return 'Polling request timed out';
    if (err is http.ClientException) {
      return 'Network error during polling request';
    }
    final type = err.runtimeType.toString();
    if (type.contains('Tls') || type.contains('Handshake')) {
      return 'TLS error during polling request';
    }
    return 'Polling request failed';
  }
}
