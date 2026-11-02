import 'dart:async';
import 'dart:convert';

import 'package:launchdarkly_dart_common/launchdarkly_dart_common.dart';
import 'package:launchdarkly_event_source_client/launchdarkly_event_source_client.dart';

import '../config/data_source_config.dart';
import '../config/defaults/default_config.dart';
import 'data_source.dart';
import 'data_source_status.dart';
import 'get_environment_id.dart';
import 'requestor.dart';
import 'sse_client_factory.dart';

const String _pingEvent = 'ping';
const String _patchEvent = 'patch';
const String _putEvent = 'put';
const String _delete = 'delete';

typedef MessageHandler = void Function(MessageEvent);
typedef ErrorHandler = void Function(dynamic);
HttpClient _defaultHttpClientFactory(HttpProperties httpProperties) {
  return HttpClient(httpProperties: httpProperties);
}

final class StreamingDataSource implements DataSource {
  final LDLogger _logger;

  final StreamingDataSourceConfig _dataSourceConfig;

  final SSEClientFactory _clientFactory;

  /// Whether the application supplied the SSE client factory.
  final bool _customFactory;

  /// The configured request method, before the capabilities of the client
  /// are known.
  late final bool _wantReport;

  late final String _plainContextString;

  late final ServiceEndpoints _endpoints;

  late final PollingDataSourceConfig _pollingDataSourceConfig;

  late final HttpClientFactory _httpClientFactory;

  late Uri _uri;

  late final HttpProperties _httpProperties;

  late String _contextString;
  bool _stopped = false;

  StreamSubscription<Event>? _subscription;

  final StreamController<DataSourceEvent> _dataController = StreamController();

  late bool _useReport;

  SSEClient? _client;

  String? _environmentId;

  final String _credential;

  late Requestor _requestor;

  @override
  Stream<DataSourceEvent> get events => _dataController.stream;

  /// Used to track if there has been an unrecoverable error.
  bool _permanentShutdown = false;

  /// The [clientFactory] parameter supplies a customized SSE client. When it
  /// is given, the data source sends a REPORT request if the client reports
  /// [SSECapability.customMethod], whatever the platform default is.
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
      SSEClientFactory? clientFactory,
      HttpClientFactory? httpClientFactory})
      : _logger = logger.subLogger('StreamingDataSource'),
        _dataSourceConfig = dataSourceConfig,
        _clientFactory = clientFactory ?? defaultSseClientFactory,
        _customFactory = clientFactory != null,
        _httpProperties = httpProperties,
        _credential = credential {
    _plainContextString =
        jsonEncode(LDContextSerialization.toJson(context, isEvent: false));
    _endpoints = endpoints;
    _pollingDataSourceConfig = pollingDataSourceConfig;
    _httpClientFactory = httpClientFactory ?? _defaultHttpClientFactory;

    // With a custom client, the capabilities of the client decide in start.
    // Without one, the platform decides.
    if (_dataSourceConfig.useReport &&
        !_customFactory &&
        !DefaultConfig.dataSourceConfig.streamingReportSupported) {
      _logger.warn(
          'REPORT is currently not supported for streaming on web targets');
    }

    _wantReport = _dataSourceConfig.useReport &&
        (_customFactory ||
            DefaultConfig.dataSourceConfig.streamingReportSupported);

    _configureRequest(_wantReport);
  }

  /// Sets the URI and the ping requestor for the request method.
  void _configureRequest(bool useReport) {
    _useReport = useReport;
    _contextString = useReport
        ? _plainContextString
        : base64UrlEncode(utf8.encode(_plainContextString));

    final path = useReport
        ? _dataSourceConfig.streamingReportPath(_credential, _contextString)
        : _dataSourceConfig.streamingGetPath(_credential, _contextString);

    String completeUrl = appendPath(_endpoints.streaming, path);

    if (_dataSourceConfig.withReasons) {
      completeUrl = '$completeUrl?withReasons=true';
    }

    _uri = Uri.parse(completeUrl);

    _requestor = Requestor(
        logger: _logger,
        contextString: _contextString,
        method: useReport ? RequestMethod.report : RequestMethod.get,
        httpProperties: _httpProperties,
        dataSourceConfig: _pollingDataSourceConfig,
        endpoints: _endpoints,
        credential: _credential,
        httpClientFactory: _httpClientFactory);
  }

  SSEClient _buildClient() {
    final headers =
        streamingRequestHeaders(_httpProperties, customFactory: _customFactory);
    return _clientFactory(SSEClientRequest(
        uriProvider: () => _uri,
        eventTypes: const {_putEvent, _patchEvent, _delete, _pingEvent},
        headers: headers,
        body: _useReport ? _contextString : null,
        method: _useReport ? SseHttpMethod.report : SseHttpMethod.get,
        logger: LDLoggerToEventSourceAdapter(_logger)));
  }

  @override
  void start() {
    if (_subscription != null || _permanentShutdown || _stopped) {
      return;
    }
    _stopped = false;
    _logger.debug('Establishing new streaming connection, uri: $_uri');
    var client = _buildClient();
    if (_wantReport && !client.hasCapability(SSECapability.customMethod)) {
      _logger.warn(
          'The SSE client cannot send REPORT requests. Streaming with GET instead.');
      client.close();
      _configureRequest(false);
      client = _buildClient();
    }
    _client = client;

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
                final message = res.kind == ErrorKind.errorResponse
                    ? 'received unexpected status code when polling in response to a ping event'
                    : 'encountered error with polling request in response to a ping event';
                final argument = res.kind == ErrorKind.errorResponse
                    ? res.statusCode
                    : res.message;
                _logger.error('$message: $argument');
                _dataController.sink.add(res);
              case PayloadEvent():
              case InitializedEvent():
                // The FDv1 requestor never produces FDv2 payload or lifecycle
                // events.
                break;
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
          } else {
            _environmentId = DefaultConfig.credentialConfig
                .environmentIdFallback(_credential);
          }
      }
    })
      ..onError((err) {
        if (_permanentShutdown) {
          return;
        }
        // The SSE client retries recoverable responses on its own (and
        // logs them), so this source is not shutting down -- let the retry
        // run.
        if (err is SseHttpError && err.recoverable) {
          return;
        }
        _permanentShutdown = true;
        _logger.error(
            'Encountered an unrecoverable error: "$err", Shutting down.');
        // The event must be added before calling stop, because stop closes
        // the controller and adding an event after that throws a StateError.
        _dataController.sink.add(StatusEvent(ErrorKind.unknown, null,
            'Encountered unrecoverable error streaming'));
        stop();
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
