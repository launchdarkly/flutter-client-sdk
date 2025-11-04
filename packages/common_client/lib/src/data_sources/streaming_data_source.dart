import 'dart:async';
import 'dart:convert';
import 'dart:math' as math;

import 'package:launchdarkly_dart_common/launchdarkly_dart_common.dart';
import 'package:launchdarkly_event_source_client/launchdarkly_event_source_client.dart';

import '../config/data_source_config.dart';
import '../config/defaults/credential_type.dart';
import '../config/defaults/default_config.dart';
import 'data_source.dart';
import 'data_source_requestor.dart';
import 'data_source_status.dart';
import 'get_environment_id.dart';

typedef SseClientFactory = SSEClient Function(
    Uri uri,
    HttpProperties httpProperties,
    String? body,
    SseHttpMethod? method,
    EventSourceLogger? logger);

SSEClient _defaultClientFactory(Uri uri, HttpProperties httpProperties,
    String? body, SseHttpMethod? method, EventSourceLogger? logger) {
  return SSEClient(uri, {'put', 'patch', 'delete', 'ping'},
      headers: httpProperties.baseHeaders,
      body: body,
      httpMethod: method ?? SseHttpMethod.get,
      logger: logger);
}

final class StreamingDataSource implements DataSource {
  static const String _pingEventType = 'ping';

  final LDLogger _logger;
  final ServiceEndpoints _endpoints;
  final StreamingDataSourceConfig _dataSourceConfig;
  final SseClientFactory _clientFactory;
  final HttpProperties _httpProperties;
  final String _credential;
  final Backoff _pollBackoff;

  late final Uri _uri;
  late final String _contextString;
  late final bool _useReport;
  late final HttpClient _pollingClient;
  late final DataSourceRequestor _requestor;
  late final Uri _pollingUri;
  late final RequestMethod _pollingMethod;

  final StreamController<DataSourceEvent> _dataController = StreamController();
  SSEClient? _client;
  StreamSubscription<Event>? _subscription;
  String? _environmentId;
  bool _stopped = false;
  bool _permanentShutdown = false;

  int? _pollActiveSince;

  @override
  Stream<DataSourceEvent> get events => _dataController.stream;

  StreamingDataSource(
      {required String credential,
      required LDContext context,
      required ServiceEndpoints endpoints,
      required LDLogger logger,
      required StreamingDataSourceConfig dataSourceConfig,
      required HttpProperties httpProperties,
      SseClientFactory clientFactory = _defaultClientFactory})
      : _endpoints = endpoints,
        _logger = logger.subLogger('StreamingDataSource'),
        _dataSourceConfig = dataSourceConfig,
        _clientFactory = clientFactory,
        _httpProperties = httpProperties,
        _credential = credential,
        _pollBackoff = Backoff(math.Random()) {
    final plainContextString =
        jsonEncode(LDContextSerialization.toJson(context, isEvent: false));

    if (_dataSourceConfig.useReport &&
        !DefaultConfig.dataSourceConfig.streamingReportSupported) {
      _logger.warn(
          'REPORT is currently not supported for streaming on web targets');
    }

    _useReport = _dataSourceConfig.useReport &&
        DefaultConfig.dataSourceConfig.streamingReportSupported;

    _contextString = _useReport
        ? plainContextString
        : base64UrlEncode(utf8.encode(plainContextString));

    _uri = _buildStreamingUri();
    _setupPollingClient();
    _requestor = DataSourceRequestor(
        client: _pollingClient, logger: _logger, credential: credential);
    _pollingUri = _buildPollingUri();
  }

  @override
  void start() {
    if (_subscription != null || _permanentShutdown || _stopped) {
      return;
    }
    _stopped = false;
    _logger.debug('Establishing new streaming connection, uri: $_uri');
    _client = _clientFactory(
        _uri,
        _httpProperties,
        _useReport ? _contextString : null,
        _useReport ? SseHttpMethod.report : SseHttpMethod.get,
        LDLoggerToEventSourceAdapter(_logger));

    _subscription = _client!.stream.listen((event) {
      if (_stopped) {
        return;
      }

      switch (event) {
        case MessageEvent():
          if (event.type == _pingEventType) {
            _handlePingEvent();
          } else {
            _handleMessageEvent(event.type, event.data);
          }
        case OpenEvent():
          _environmentId = _getEnvironmentIdFromHeaders(event.headers);
      }
    })
      ..onError((err) {
        if (_permanentShutdown) {
          return;
        }
        _permanentShutdown = true;
        _logger.error(
            'Encountered an unrecoverable error: "$err", Shutting down.');
        stop();
        _dataController.sink.add(StatusEvent(ErrorKind.unknown, null,
            'Encountered unrecoverable error streaming'));
      });
  }

  @override
  void restart() {
    _client?.restart();
  }

  @override
  void stop() {
    if (_stopped) {
      return;
    }
    _subscription?.cancel();
    _subscription = null;
    _stopped = true;
    _pollActiveSince = null;
    _pollingClient.close();
    _dataController.close();
  }

  void _handleMessageEvent(String type, String data) {
    _dataController.sink.add(
        DataEvent(type, data, environmentId: _environmentId));
  }

  Future<void> _handlePingEvent() async {
    if (_stopped) {
      return;
    }

    final chainId = _requestor.startRequestChain();
    _updatePollActiveTime();
    await _pollWithRetry(chainId);
  }

  Future<void> _pollWithRetry(int chainId, {bool isRetry = false}) async {
    if (!_requestor.isValidChain(chainId)) {
      return;
    }

    if (isRetry) {
      await _waitForBackoff();
      if (!_requestor.isValidChain(chainId)) {
        return;
      }
    }

    try {
      final res = await _requestor.makeRequest(
        chainId,
        _pollingUri,
        _pollingMethod,
        body: _dataSourceConfig.useReport ? _contextString : null,
      );

      final result = _requestor.processResponse(
        res,
        chainId,
        isRecoverableStatus: isHttpGloballyRecoverable,
      );

      if (result == null) {
        return;
      }

      if (result.event != null) {
        _dataController.sink.add(result.event!);
        if (result.event is DataEvent) {
          _updatePollActiveTime();
        }
      }

      if (result.shouldRetry) {
        await _pollWithRetry(chainId, isRetry: true);
      } else if (result.shutdown) {
        _permanentShutdown = true;
        stop();
      }
    } catch (err) {
      if (!_requestor.isValidChain(chainId)) {
        return;
      }
      _logger
          .error('encountered error with ping-triggered polling request: $err');
      await _pollWithRetry(chainId, isRetry: true);
    }
  }

  void _updatePollActiveTime() {
    _pollActiveSince = DateTime.now().millisecondsSinceEpoch;
  }

  Future<void> _waitForBackoff() async {
    final retryDelay = _pollBackoff.getRetryDelay(_pollActiveSince);
    await Future.delayed(Duration(milliseconds: retryDelay));
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

  Uri _buildStreamingUri() {
    return _buildUri(
        _endpoints.streaming,
        _dataSourceConfig.streamingReportPath,
        _dataSourceConfig.streamingGetPath);
  }

  Uri _buildPollingUri() {
    return _buildUri(_endpoints.polling,
        DefaultConfig.pollingPaths.pollingReportPath,
        DefaultConfig.pollingPaths.pollingGetPath);
  }

  Uri _buildUri(String baseUrl, String Function(String, String) reportPath,
      String Function(String, String) getPath) {
    final path = _useReport
        ? reportPath(_credential, _contextString)
        : getPath(_credential, _contextString);

    var url = appendPath(baseUrl, path);
    if (_dataSourceConfig.withReasons) {
      url = '$url?withReasons=true';
    }
    return Uri.parse(url);
  }

  void _setupPollingClient() {
    if (_dataSourceConfig.useReport) {
      final updatedProperties =
          _httpProperties.withHeaders({'content-type': 'application/json'});
      _pollingMethod = RequestMethod.report;
      _pollingClient = HttpClient(httpProperties: updatedProperties);
    } else {
      _pollingMethod = RequestMethod.get;
      _pollingClient = HttpClient(httpProperties: _httpProperties);
    }
  }
}

/// Adapter to convert LDLogger to EventSourceLogger
class LDLoggerToEventSourceAdapter implements EventSourceLogger {
  final LDLogger _logger;

  LDLoggerToEventSourceAdapter(this._logger);

  @override
  void debug(String message) => _logger.debug(message);

  @override
  void info(String message) => _logger.info(message);

  @override
  void warn(String message) => _logger.warn(message);

  @override
  void error(String message) => _logger.error(message);
}
