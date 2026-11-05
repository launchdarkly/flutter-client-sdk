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
import 'streaming_client.dart';

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

  final SseClientBuilder _clientBuilder;

  /// Whether the stream uses REPORT. False when the client cannot send it.
  final bool _useReport;

  final String _plainContextString;

  final ServiceEndpoints _endpoints;

  final HttpProperties _httpProperties;

  final String _credential;

  /// Polls for all flags when the stream sends a ping. Its method follows
  /// the polling configuration, not the method of the stream.
  final Requestor _requestor;

  bool _stopped = false;

  StreamSubscription<Event>? _subscription;

  final StreamController<DataSourceEvent> _dataController = StreamController();

  SSEClient? _client;

  String? _environmentId;

  @override
  Stream<DataSourceEvent> get events => _dataController.stream;

  /// Used to track if there has been an unrecoverable error.
  bool _permanentShutdown = false;

  /// [useHttpStreamingOnWeb] selects the HTTP-based SSE client on web. The
  /// [clientBuilder] parameter is for tests, which inject a fake client. The
  /// [httpClientFactory] parameter is for tests of the requestor that serves
  /// ping events.
  StreamingDataSource(
      {required String credential,
      required LDContext context,
      required ServiceEndpoints endpoints,
      required LDLogger logger,
      required StreamingDataSourceConfig dataSourceConfig,
      required PollingDataSourceConfig pollingDataSourceConfig,
      required HttpProperties httpProperties,
      bool useHttpStreamingOnWeb = false,
      SseClientBuilder? clientBuilder,
      HttpClientFactory? httpClientFactory})
      : this._(
            credential: credential,
            endpoints: endpoints,
            logger: logger.subLogger('StreamingDataSource'),
            dataSourceConfig: dataSourceConfig,
            pollingDataSourceConfig: pollingDataSourceConfig,
            httpProperties: httpProperties,
            clientBuilder: clientBuilder ??
                sseClientBuilderFor(
                    useHttpStreamingOnWeb: useHttpStreamingOnWeb),
            useReport: dataSourceConfig.useReport &&
                streamingCustomMethodSupported(
                    useHttpStreamingOnWeb: useHttpStreamingOnWeb),
            httpClientFactory: httpClientFactory ?? _defaultHttpClientFactory,
            plainContextString: jsonEncode(
                LDContextSerialization.toJson(context, isEvent: false)));

  StreamingDataSource._(
      {required String credential,
      required ServiceEndpoints endpoints,
      required LDLogger logger,
      required StreamingDataSourceConfig dataSourceConfig,
      required PollingDataSourceConfig pollingDataSourceConfig,
      required HttpProperties httpProperties,
      required SseClientBuilder clientBuilder,
      required bool useReport,
      required HttpClientFactory httpClientFactory,
      required String plainContextString})
      : _logger = logger,
        _dataSourceConfig = dataSourceConfig,
        _clientBuilder = clientBuilder,
        _useReport = useReport,
        _httpProperties = httpProperties,
        _credential = credential,
        _endpoints = endpoints,
        _plainContextString = plainContextString,
        _requestor = Requestor(
            logger: logger,
            contextString: pollingDataSourceConfig.useReport
                ? plainContextString
                : base64UrlEncode(utf8.encode(plainContextString)),
            method: pollingDataSourceConfig.useReport
                ? RequestMethod.report
                : RequestMethod.get,
            httpProperties: httpProperties,
            dataSourceConfig: pollingDataSourceConfig,
            endpoints: endpoints,
            credential: credential,
            httpClientFactory: httpClientFactory) {
    if (dataSourceConfig.useReport && !_useReport) {
      _logger.warn('The browser EventSource cannot send REPORT requests. '
          'Streaming with GET instead. Set useHttpStreamingOnWeb to stream '
          'with REPORT on web.');
    }
  }

  /// The streaming URI for the request method.
  Uri _buildUri() {
    final contextString = _useReport
        ? _plainContextString
        : base64UrlEncode(utf8.encode(_plainContextString));
    final path = _useReport
        ? _dataSourceConfig.streamingReportPath(_credential, contextString)
        : _dataSourceConfig.streamingGetPath(_credential, contextString);

    var completeUrl = appendPath(_endpoints.streaming, path);
    if (_dataSourceConfig.withReasons) {
      completeUrl = '$completeUrl?withReasons=true';
    }
    return Uri.parse(completeUrl);
  }

  @override
  void start() {
    if (_subscription != null || _permanentShutdown || _stopped) {
      return;
    }
    _stopped = false;
    final uri = _buildUri();
    _logger.debug('Establishing new streaming connection, uri: $uri');
    final client = _clientBuilder(
        uri, const {_putEvent, _patchEvent, _delete, _pingEvent},
        headers: streamingRequestHeaders(_httpProperties),
        body: _useReport ? _plainContextString : null,
        httpMethod: _useReport ? SseHttpMethod.report : SseHttpMethod.get,
        logger: LDLoggerToEventSourceAdapter(_logger),
        uriProvider: _buildUri);
    _client = client;

    _subscription = client.stream.listen((event) async {
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
    _client?.close();
    _client = null;
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
