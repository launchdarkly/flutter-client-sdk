import 'dart:async';
import 'dart:convert';

import 'package:launchdarkly_dart_common/launchdarkly_dart_common.dart';
import 'package:launchdarkly_event_source_client/launchdarkly_event_source_client.dart';

import '../config/data_source_config.dart';
import '../config/defaults/default_config.dart';
import 'data_source.dart';
import 'data_source_status.dart';
import 'fdv2/payload.dart';
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
  // The data source owns the retry, so the client must not reconnect by
  // itself.
  return SSEClient(uri, {_putEvent, _patchEvent, _delete, _pingEvent},
      headers: httpProperties.baseHeaders,
      body: body,
      httpMethod: method ?? SseHttpMethod.get,
      logger: logger,
      autoReconnect: false);
}

HttpClient _defaultHttpClientFactory(HttpProperties httpProperties) {
  return HttpClient(httpProperties: httpProperties);
}

/// A data source that receives flag updates over a streaming connection.
///
/// The data source makes a new SSE client for each connection attempt.
/// After a failure it closes the client, waits for the delay from its
/// [RetryState], and then connects again. No failure stops it.
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

  final RetryState _retryState;

  Timer? _reconnectTimer;

  /// Counts the connections. Events carry it, so that a restart caused by an
  /// older connection does not close a newer one.
  int _generation = 0;

  @override
  Stream<DataSourceEvent> get events => _dataController.stream;

  /// The [clientFactory] parameter is primarily intended for testing, but it also
  /// could be used for customized SSE clients which support functionality
  /// our default client support does not, or for alternative implementations
  /// which are not based on SSE. A client from the factory must not
  /// reconnect by itself.
  /// The [httpClientFactory] parameter is primarily intended for testing the
  /// requestor used for ping events.
  /// The [retryState] parameter is for testing.
  StreamingDataSource(
      {required String credential,
      required LDContext context,
      required ServiceEndpoints endpoints,
      required LDLogger logger,
      required StreamingDataSourceConfig dataSourceConfig,
      required PollingDataSourceConfig pollingDataSourceConfig,
      required HttpProperties httpProperties,
      SseClientFactory clientFactory = _defaultClientFactory,
      HttpClientFactory? httpClientFactory,
      RetryState? retryState})
      : _logger = logger.subLogger('StreamingDataSource'),
        _dataSourceConfig = dataSourceConfig,
        _clientFactory = clientFactory,
        _httpProperties = httpProperties,
        _credential = credential,
        _retryState = retryState ?? RetryState.streaming() {
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
    if (_subscription != null || _reconnectTimer != null || _stopped) {
      return;
    }
    _connect();
  }

  void _connect() {
    _reconnectTimer = null;
    if (_stopped) {
      return;
    }
    _generation++;
    final generation = _generation;
    _logger.debug('Establishing new streaming connection, uri: $_uri');
    final client = _clientFactory(
        _uri,
        _httpProperties,
        _useReport ? _contextString : null,
        _useReport ? SseHttpMethod.report : SseHttpMethod.get,
        LDLoggerToEventSourceAdapter(_logger));
    _client = client;

    _subscription = client.stream.listen((event) async {
      if (_stopped) {
        return;
      }

      switch (event) {
        case MessageEvent():
          _retryState.recordSuccess();
          if (event.type == _pingEvent) {
            final res = await _requestor.requestAllFlags();
            if (_stopped) {
              return;
            }
            switch (res) {
              case null:
                // No update. A change set of type none restores the valid
                // status.
                _dataController.sink.add(PayloadEvent(
                    const ChangeSet(type: PayloadType.none, updates: {}),
                    generation: generation));
              case DataEvent():
                _dataController.sink.add(DataEvent(res.type, res.data,
                    environmentId: res.environmentId, generation: generation));
              case StatusEvent():
                _logPingPollFailure(res);
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
                environmentId: _environmentId, generation: generation));
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
      ..onError(_handleError);
  }

  void _logPingPollFailure(StatusEvent status) {
    if (status.statusCode case final statusCode?) {
      switch (classifyHttpStatus(statusCode)) {
        case FailureKind.unexpected:
          _logger.error('Received unexpected status code $statusCode when '
              'polling in response to a ping event.'
              '${credentialHint(statusCode)}');
        case FailureKind.normal:
          _logger.warn('Received status code $statusCode when polling in '
              'response to a ping event.');
      }
      return;
    }
    _logger.warn('Encountered error with polling request in response to a '
        'ping event: ${status.message}');
  }

  void _handleError(Object err) {
    if (_stopped) {
      return;
    }
    final StatusEvent status;
    final Duration delay;
    if (err is SseHttpError) {
      final kind = classifyHttpStatus(err.statusCode);
      delay = _retryState.recordFailure(kind);
      status = StatusEvent(ErrorKind.errorResponse, err.statusCode,
          'Received unexpected status code: ${err.statusCode}');
      switch (kind) {
        case FailureKind.unexpected:
          _logger.error('Received unexpected status code ${err.statusCode} '
              'for the streaming connection.${credentialHint(err.statusCode)} '
              'Will retry in ${delay.inMilliseconds} ms.');
        case FailureKind.normal:
          _logger.warn('Received status code ${err.statusCode} for the '
              'streaming connection. Will retry in ${delay.inMilliseconds} '
              'ms.');
      }
    } else {
      delay = _retryState.recordFailure(FailureKind.normal);
      final message = _describeError(err);
      status = StatusEvent(ErrorKind.networkError, null, message);
      _logger.warn('$message. Will retry in ${delay.inMilliseconds} ms.');
    }
    _closeConnection();
    _dataController.sink.add(status);
    _scheduleReconnect(delay);
  }

  /// Categorizes an error from the SSE client into a fixed message. The
  /// string form of a transport error can contain the request URL, which
  /// holds the context in GET mode.
  String _describeError(Object err) => switch (err) {
        SseTimeoutError(phase: SseTimeoutPhase.connect) =>
          'The streaming connection timed out while connecting',
        SseTimeoutError(phase: SseTimeoutPhase.read) =>
          'The streaming connection was silent for too long',
        SseContentTypeError() =>
          'The streaming connection received an unexpected content type',
        SseStreamClosedError() => 'The streaming connection was closed',
        _ => 'The streaming connection failed',
      };

  void _closeConnection() {
    // Cancel is async, but it should only be for the cleanup portion, according
    // to the method documentation.
    _subscription?.cancel();
    _subscription = null;
    _client?.close();
    _client = null;
  }

  void _scheduleReconnect(Duration delay) {
    _reconnectTimer?.cancel();
    _reconnectTimer = Timer(delay, _connect);
  }

  @override
  void restart({int? generation}) {
    // The payload that caused the restart can come from a ping poll, also
    // from a replaced connection. Forget its ETag, so that the next ping poll
    // fetches a full payload.
    _requestor.clearEtag();
    // A restart during a wait has no effect, because the data source is
    // already going to reconnect.
    if (_stopped || _client == null) {
      return;
    }
    if (generation != null && generation != _generation) {
      _logger.debug('Ignoring a restart for a replaced connection.');
      return;
    }
    final delay = _retryState.recordFailure(FailureKind.normal);
    _logger.warn('Restarting the streaming connection. Will retry in '
        '${delay.inMilliseconds} ms.');
    _closeConnection();
    _scheduleReconnect(delay);
  }

  @override
  void stop() {
    _stopped = true;
    _reconnectTimer?.cancel();
    _reconnectTimer = null;
    _closeConnection();
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
