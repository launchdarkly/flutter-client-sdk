import 'dart:async';
import 'dart:convert';

import 'package:launchdarkly_dart_common/ld_common.dart';
import 'package:launchdarkly_event_source_client/sse_client.dart';

import '../config/data_source_config.dart';
import 'data_source_event_handler.dart';
import 'data_source_status.dart';
import 'data_source_status_manager.dart';

typedef MessageHandler = void Function(MessageEvent);
typedef ErrorHandler = void Function(dynamic);
typedef MessageSubscriptionFactory = StreamSubscription<MessageEvent> Function(
    Uri uri,
    HttpProperties httpProperties,
    MessageHandler handler,
    ErrorHandler errorHandler);

StreamSubscription<MessageEvent> _defaultSubscriptionFactory(
    Uri uri,
    HttpProperties httpProperties,
    MessageHandler handler,
    ErrorHandler errorHandler) {
  final stream = SSEClient(uri, {'put', 'patch', 'delete'},
          headers: httpProperties.baseHeaders)
      .stream;
  stream.handleError(errorHandler);
  return stream.listen(handler);
}

final class StreamingDataSource {
  final LDLogger _logger;

  final DataSourceStatusManager _statusManager;

  final DataSourceEventHandler _dataSourceEventHandler;

  final ServiceEndpoints _endpoints;

  final StreamingDataSourceConfig _dataSourceConfig;

  final MessageSubscriptionFactory _subFactory;

  late final Uri _uri;

  late final HttpProperties _httpProperties;

  late final String _contextString;
  bool _stopped = false;

  StreamSubscription<MessageEvent>? _subscription;

  /// Used to track if there has been an unrecoverable error.
  bool _permanentShutdown = false;

  /// The [subFactory] parameter is primarily intended for testing, but it also
  /// could be used for customized SSE clients which support functionality
  /// our default client support does not, or for alternative implementations
  /// which are not based on SSE.
  StreamingDataSource(
      {required String credential,
      required LDContext context,
      required ServiceEndpoints endpoints,
      required LDLogger logger,
      required DataSourceStatusManager statusManager,
      required DataSourceEventHandler dataSourceEventHandler,
      required StreamingDataSourceConfig dataSourceConfig,
      required HttpProperties httpProperties,
      MessageSubscriptionFactory subFactory = _defaultSubscriptionFactory})
      : _endpoints = endpoints,
        _logger = logger.subLogger('StreamingDataSource'),
        _statusManager = statusManager,
        _dataSourceEventHandler = dataSourceEventHandler,
        _dataSourceConfig = dataSourceConfig,
        _subFactory = subFactory {
    if (_dataSourceConfig.useReport) {
      _logger.warn('REPORT is currently not supported for streaming');
    }
    _httpProperties = httpProperties.withHeaders({'authorization': credential});

    final plainContextString =
        jsonEncode(LDContextSerialization.toJson(context, isEvent: false));
    _contextString = base64UrlEncode(utf8.encode(plainContextString));

    String completeUrl = appendPath(_endpoints.streaming,
        _dataSourceConfig.streamingGetPath(credential, _contextString));

    if (_dataSourceConfig.withReasons) {
      completeUrl = '$completeUrl?withReasons=true';
    }

    _uri = Uri.parse(completeUrl);
  }

  void start() {
    if (_subscription != null || _permanentShutdown) {
      return;
    }
    _stopped = false;
    _subscription = _subFactory(_uri, _httpProperties, (event) async {
      if (_stopped) {
        return;
      }
      if (await _dataSourceEventHandler.handleMessage(event.type, event.data) ==
          MessageStatus.invalidMessage) {
        _logger.warn('Restarting the event source because of invalid data');
        _restart();
      }
    }, (err) {
      if (_permanentShutdown) {
        return;
      }
      _permanentShutdown = true;
      _logger
          .error('Encountered an unrecoverable error: "$err", Shutting down.');
      stop();
      _statusManager.setErrorByKind(
          ErrorKind.unknown, 'Encountered unrecoverable error streaming');
    });
  }

  void _restart() {
    if (_stopped || _permanentShutdown) {
      return;
    }
    stop();
    start();
  }

  void stop() {
    // Cancel is async, but it should only be for the cleanup portion, according
    // to the method documentation.
    _subscription?.cancel();
    _subscription = null;
    _stopped = true;
  }
}
