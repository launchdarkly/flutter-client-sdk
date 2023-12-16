import 'dart:async';
import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:launchdarkly_dart_common/ld_common.dart';
import 'dart:math';

import '../config/data_source_config.dart';
import 'data_source_event_handler.dart';
import 'data_source_status.dart';
import 'data_source_status_manager.dart';

HttpClient _defaultClientFactory(HttpProperties httpProperties) {
  return HttpClient(httpProperties: httpProperties);
}

final class PollingDataSource {
  final LDLogger _logger;

  final DataSourceStatusManager _statusManager;

  final DataSourceEventHandler _dataSourceEventHandler;

  final ServiceEndpoints _endpoints;

  final PollingDataSourceConfig _dataSourceConfig;

  late final HttpClient _client;

  Timer? _pollTimer;

  final Stopwatch _pollStopwatch = Stopwatch();

  late final Duration _pollingInterval;

  late final String _contextString;

  bool _stopped = false;

  late final Uri _uri;

  late final RequestMethod _method;

  String? _lastEtag;

  /// The [client] parameter is primarily intended for testing, but it also
  /// could be used for customized clients which support functionality
  /// our default client support does not. For instance domain sockets or
  /// other connection mechanisms.
  ///
  /// The [testingInterval] should only be used for tests.
  PollingDataSource(
      {required LDContext context,
      required ServiceEndpoints endpoints,
      required LDLogger logger,
      required DataSourceStatusManager statusManager,
      required DataSourceEventHandler dataSourceEventHandler,
      required PollingDataSourceConfig dataSourceConfig,
      required HttpProperties httpProperties,
      Duration? testingInterval,
      HttpClient Function(HttpProperties) clientFactory =
          _defaultClientFactory})
      : _endpoints = endpoints,
        _logger = logger.subLogger('PollingDataSource'),
        _statusManager = statusManager,
        _dataSourceEventHandler = dataSourceEventHandler,
        _dataSourceConfig = dataSourceConfig {
    _pollingInterval = testingInterval ?? dataSourceConfig.pollingInterval;

    if (_dataSourceConfig.useReport) {
      final updatedProperties =
          httpProperties.withHeaders({'content-type': 'application/json'});
      _method = RequestMethod.report;
      _client = clientFactory(updatedProperties);
    } else {
      final updatedProperties = httpProperties
          .withHeaders({'authorization': _dataSourceConfig.credential});
      _method = RequestMethod.get;
      _client = clientFactory(updatedProperties);
    }

    final plainContextString =
        jsonEncode(LDContextSerialization.toJson(context, isEvent: false));
    if (dataSourceConfig.useReport) {
      _contextString = plainContextString;
    } else {
      _contextString = base64UrlEncode(utf8.encode(plainContextString));
    }

    String completeUrl;
    if (_dataSourceConfig.useReport) {
      completeUrl = appendPath(_endpoints.polling,
          _dataSourceConfig.pollingReportPath(_contextString));
    } else {
      completeUrl = appendPath(
          _endpoints.polling, _dataSourceConfig.pollingGetPath(_contextString));
    }
    if (_dataSourceConfig.withReasons) {
      completeUrl = '$completeUrl?withReasons=true';
    }

    _uri = Uri.parse(completeUrl);
  }

  Future<void> _makeRequest() async {
    try {
      final res = await _client.request(_method, _uri,
          additionalHeaders: _lastEtag != null ? {'etag': _lastEtag!} : null,
          body: _dataSourceConfig.useReport ? _contextString : null);
      await _handleResponse(res);
    } catch (err) {
      _logger.error('encountered error with polling request: $err, will retry');
      _statusManager.setErrorByKind(ErrorKind.networkError, err.toString());
    }
  }

  Future<void> _handleResponse(http.Response res) async {
    // The data source has been instructed to stop, so we discard the response.
    if (_stopped) {
      return;
    }
    if (res.statusCode == 200 || res.statusCode == 304) {
      final etag = res.headers['etag'];
      if (etag != null && etag == _lastEtag) {
        // The response has not changed, so we don't need to do the work of
        // updating the store, calculating changes, or persisting the payload.
        return;
      }
      _lastEtag = etag;

      await _dataSourceEventHandler.handleMessage('put', res.body);
    } else {
      if (isHttpGloballyRecoverable(res.statusCode)) {
        _statusManager.setErrorResponse(res.statusCode,
            'Received unexpected status code: ${res.statusCode}');
        _logger.error(
            'received unexpected status code when polling: ${res.statusCode}, will retry');
      } else {
        _logger.error(
            'received unexpected status code when polling: ${res.statusCode}, stopping polling');
        _statusManager.setErrorResponse(res.statusCode,
            'Received unexpected status code: ${res.statusCode}',
            shutdown: true);
        stop();
      }
    }
  }

  Future<void> _doPoll() async {
    _pollStopwatch.reset();
    _pollStopwatch.start();

    await _makeRequest();
    _schedulePoll();
  }

  void _schedulePoll() {
    if (_stopped) {
      return;
    }
    _pollStopwatch.stop();
    final timeSincePoll = _pollStopwatch.elapsed;
    // Calculate a delay based on the polling interval and the duration elapsed
    // since the last poll.

    // Example: If the poll took 5 seconds, and the interval is 30 seconds, then
    // we want to poll after 25 seconds.
    final delay = Duration(
        milliseconds: max(
            _pollingInterval.inMilliseconds - timeSincePoll.inMilliseconds,
            _pollingInterval.inMilliseconds));

    _pollTimer = Timer(delay, _doPoll);
  }

  void start() {
    _doPoll();
  }

  void stop() {
    _stopped = true;
    _pollTimer?.cancel();
    _pollTimer = null;
  }
}
