import 'dart:async';
import 'dart:convert';

import 'package:launchdarkly_dart_common/launchdarkly_dart_common.dart';
import 'package:launchdarkly_event_source_client/launchdarkly_event_source_client.dart';

import '../config/data_source_config.dart';
import '../config/defaults/credential_type.dart';
import '../config/defaults/default_config.dart';
import 'data_source.dart';
import 'data_source_status.dart';
import 'get_environment_id.dart';
import 'requestor.dart';

const String _pingEvent = 'ping';
const String _patchEvent = 'patch';
const String _putEvent = 'put';
const String _delete = 'delete';

typedef MessageHandler = void Function(MessageEvent);
typedef ErrorHandler = void Function(dynamic);
typedef SseClientFactory = SSEClient Function(
    Uri uri,
    HttpProperties httpProperties,
    String? body,
    SseHttpMethod? method,
    EventSourceLogger? logger);

SSEClient _defaultClientFactory(Uri uri, HttpProperties httpProperties,
    String? body, SseHttpMethod? method, EventSourceLogger? logger) {
  return SSEClient(uri, {_putEvent, _patchEvent, _delete, _pingEvent},
      headers: httpProperties.baseHeaders,
      body: body,
      httpMethod: method ?? SseHttpMethod.get,
      logger: logger);
}

HttpClient _defaultHttpClientFactory(HttpProperties httpProperties) {
  return HttpClient(httpProperties: httpProperties);
}

final class StreamingDataSource implements DataSource {
  final LDLogger _logger;

  final StreamingDataSourceConfig _dataSourceConfig;

  final SseClientFactory _clientFactory;

  late final Uri _uri;

  late final HttpProperties _httpProperties;

  late final String _contextString;
  bool _stopped = false;

  StreamSubscription<Event>? _subscription;

  final StreamController<DataSourceEvent> _dataController = StreamController();

  late final bool _useReport;

  SSEClient? _client;

  String? _environmentId;

  final String _credential;

  late final Requestor _requestor;

  @override
  Stream<DataSourceEvent> get events => _dataController.stream;

  /// Used to track if there has been an unrecoverable error.
  bool _permanentShutdown = false;

  /// The [clientFactory] parameter is primarily intended for testing, but it also
  /// could be used for customized SSE clients which support functionality
  /// our default client support does not, or for alternative implementations
  /// which are not based on SSE.
  /// The [httpClientFactory] parameter is primarily intended for testing the
  /// requestor used for ping events.
  StreamingDataSource(
      {required String credential,
      required LDContext context,
      required ServiceEndpoints endpoints,
      required LDLogger logger,
      required StreamingDataSourceConfig dataSourceConfig,
      required PollingDataSourceConfig pollingDataSourceConfig,
      required HttpProperties httpProperties,
      SseClientFactory clientFactory = _defaultClientFactory,
      HttpClientFactory? httpClientFactory})
      : _logger = logger.subLogger('StreamingDataSource'),
        _dataSourceConfig = dataSourceConfig,
        _clientFactory = clientFactory,
        _httpProperties = httpProperties,
        _credential = credential {
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

    final path = _useReport
        ? _dataSourceConfig.streamingReportPath(credential, _contextString)
        : _dataSourceConfig.streamingGetPath(credential, _contextString);

    String completeUrl = appendPath(endpoints.streaming, path);

    if (_dataSourceConfig.withReasons) {
      completeUrl = '$completeUrl?withReasons=true';
    }

    _uri = Uri.parse(completeUrl);

    _requestor = Requestor(
        logger: logger,
        contextString: _contextString,
        method: _useReport ? RequestMethod.report : RequestMethod.get,
        httpProperties: httpProperties,
        dataSourceConfig: pollingDataSourceConfig,
        endpoints: endpoints,
        credential: _credential,
        httpClientFactory: httpClientFactory ?? _defaultHttpClientFactory);
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

    _subscription = _client!.stream.listen((event) async {
      if (_stopped) {
        return;
      }

      switch (event) {
        case MessageEvent():
          if (event.type == _pingEvent) {
            final res = await _requestor.requestAllFlags();
            if (_stopped) {
              return;
            }
            switch (res) {
              case null:
                // No update, so things stay the same.
                return;
              case DataEvent():
                _dataController.sink.add(res);
              case StatusEvent():
                _logger.error(
                    'received unexpected status code when polling in response to a ping event: ${res.statusCode}');
                _dataController.sink.add(res);
            }
          } else {
            _logger.debug('Received message event, data: ${event.data}');
            _dataController.sink.add(DataEvent(event.type, event.data,
                environmentId: _environmentId));
          }
        case OpenEvent():
          _logger.debug('Received connect event, data: ${event.headers}');
          if (event.headers != null) {
            _environmentId = getEnvironmentId(event.headers);
          } else if (DefaultConfig.credentialConfig.credentialType ==
              CredentialType.clientSideId) {
            // When using a client-side ID we can use it to represent the
            // environment.
            _environmentId = _credential;
          }
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
    // Cancel is async, but it should only be for the cleanup portion, according
    // to the method documentation.
    _subscription?.cancel();
    _subscription = null;
    _stopped = true;
    _dataController.close();
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
