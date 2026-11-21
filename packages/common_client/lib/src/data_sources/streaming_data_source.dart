import 'dart:async';
import 'dart:convert';

import 'package:launchdarkly_dart_common/launchdarkly_dart_common.dart';
import 'package:launchdarkly_event_source_client/launchdarkly_event_source_client.dart';
import 'package:meta/meta.dart';

import '../config/data_source_config.dart';
import '../config/defaults/default_config.dart';
import 'data_source.dart';
import 'data_source_status.dart';
import 'fdv1_payloads.dart';
import 'get_environment_id.dart';
import 'requestor.dart';
import 'retry_state.dart';
import 'streaming_client.dart';

const String _pingEvent = 'ping';
const String _patchEvent = 'patch';
const String _putEvent = 'put';
const String _deleteEvent = 'delete';

typedef MessageHandler = void Function(MessageEvent);
typedef ErrorHandler = void Function(dynamic);
HttpClient _defaultHttpClientFactory(HttpProperties httpProperties) {
  return HttpClient(httpProperties: httpProperties);
}

final class StreamingDataSource implements DataSource {
  final LDLogger _logger;

  final StreamingDataSourceConfig _dataSourceConfig;

  final SseClientFactory _clientFactory;

  final StreamingRetryState _retry;

  late final Uri _uri;

  late final HttpProperties _httpProperties;

  late final String _contextString;
  bool _stopped = false;

  StreamSubscription<Event>? _subscription;

  Timer? _reconnectTimer;

  final StreamController<DataSourceEvent> _dataController = StreamController();

  late final bool _useReport;

  SSEClient? _client;

  String? _environmentId;

  final String _credential;

  late final Requestor _requestor;

  @override
  Stream<DataSourceEvent> get events => _dataController.stream;

  /// The factory that [start] uses for the SSE client.
  @visibleForTesting
  SseClientFactory get eventSource => _clientFactory;

  /// [eventSource] creates the SSE client. When it is null, the data source
  /// uses the default client for the platform. Tests inject a fake client.
  /// The [streamingReportSupported] parameter overrides whether the client
  /// can send REPORT. Tests set it. The [httpClientFactory] parameter is for
  /// tests of the requestor that serves ping events. The [now] parameter
  /// supplies the current time. Tests set it.
  StreamingDataSource(
      {required String credential,
      required LDContext context,
      required ServiceEndpoints endpoints,
      required LDLogger logger,
      required StreamingDataSourceConfig dataSourceConfig,
      required PollingDataSourceConfig pollingDataSourceConfig,
      required HttpProperties httpProperties,
      SseClientFactory? eventSource,
      bool? streamingReportSupported,
      HttpClientFactory? httpClientFactory,
      DateTime Function()? now})
      : _logger = logger.subLogger('StreamingDataSource'),
        _dataSourceConfig = dataSourceConfig,
        _clientFactory = eventSource ?? SSEClient.new,
        _retry = StreamingRetryState(now: now),
        _httpProperties = httpProperties,
        _credential = credential {
    final plainContextString =
        jsonEncode(LDContextSerialization.toJson(context, isEvent: false));

    _useReport = _dataSourceConfig.useReport &&
        (streamingReportSupported ??
            streamingCustomMethodSupported(eventSource: eventSource));

    if (_dataSourceConfig.useReport && !_useReport) {
      _logger
          .warn('The streaming transport on this platform cannot send REPORT '
              'requests. The SDK streams with GET instead.');
    }

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
    if (_subscription != null || _stopped) {
      return;
    }
    _stopped = false;
    _connect();
  }

  void _connect() {
    _logger.debug('Establishing new streaming connection, uri: $_uri');
    final client = _clientFactory(SseClientOptions(
        uri: _uri,
        eventTypes: const {_putEvent, _patchEvent, _deleteEvent, _pingEvent},
        headers: streamingRequestHeaders(_httpProperties),
        body: _useReport ? _contextString : null,
        httpMethod: _useReport ? SseHttpMethod.report : SseHttpMethod.get,
        autoReconnect: false,
        logger: LDLoggerToEventSourceAdapter(_logger)));
    _client = client;

    _subscription = client.stream.listen((event) async {
      if (_stopped) {
        return;
      }

      switch (event) {
        case MessageEvent():
          _retry.recordMessage();
          if (event.type == _pingEvent) {
            final res = await _requestor.requestAllFlags();
            if (_stopped) {
              return;
            }
            switch (res) {
              case null:
                // No update, so things stay the same.
                return;
              case PollPayload():
                _emitParsed(parsePut(res.body, _logger,
                    environmentId: res.environmentId));
              case PollError():
                final message = res.kind == ErrorKind.errorResponse
                    ? 'received unexpected status code when polling in response to a ping event'
                    : 'encountered error with polling request in response to a ping event';
                final argument = res.kind == ErrorKind.errorResponse
                    ? res.statusCode
                    : res.message;
                _logger.error('$message: $argument');
                _dataController.sink
                    .add(StatusEvent(res.kind, res.statusCode, res.message));
            }
          } else {
            _logger.debug('Received message event, data: ${event.data}');
            switch (event.type) {
              case _putEvent:
                _emitParsed(parsePut(event.data, _logger,
                    environmentId: _environmentId));
              case _patchEvent:
                _emitParsed(parsePatch(event.data, _logger));
              case _deleteEvent:
                _emitParsed(parseDelete(event.data, _logger));
            }
          }
        case OpenEvent():
          _logger.debug('Received connect event, data: ${event.headers}');
          // A browser can hide the environment ID header, so the fallback
          // also applies when the headers are present but lack it.
          _environmentId = getEnvironmentId(event.headers) ??
              DefaultConfig.credentialConfig.environmentIdFallback(_credential);
      }
    })
      ..onError(_handleError);
  }

  /// Reports a failed connection, and connects again after the retry delay.
  void _handleError(Object err) {
    final status = switch (err) {
      SseHttpError(:final statusCode) => StatusEvent(ErrorKind.errorResponse,
          statusCode, 'Received unexpected status code: $statusCode'),
      SseConnectionError(:final message) =>
        StatusEvent(ErrorKind.networkError, null, message),
      _ => StatusEvent(
          ErrorKind.networkError, null, 'Streaming connection failed'),
    };
    _logger.error('${status.message}, will retry');
    _dataController.sink.add(status);
    _reconnect(unexpected: err is SseHttpError && !err.recoverable);
  }

  /// Emits [event], and reconnects if the message did not parse.
  void _emitParsed(DataSourceEvent event) {
    _dataController.sink.add(event);
    if (event is StatusEvent) {
      _reconnect(unexpected: false);
    }
  }

  /// Records a failure, closes the connection, and connects again later.
  void _reconnect({required bool unexpected}) {
    if (_stopped) {
      return;
    }
    _retry.recordFailure(unexpected: unexpected);
    _subscription?.cancel();
    _subscription = null;
    _client?.close();
    _client = null;
    _reconnectTimer?.cancel();
    _reconnectTimer = Timer(_retry.nextDelay(), _connect);
  }

  @override
  void restart() {
    _reconnect(unexpected: false);
  }

  @override
  void stop() {
    _reconnectTimer?.cancel();
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
