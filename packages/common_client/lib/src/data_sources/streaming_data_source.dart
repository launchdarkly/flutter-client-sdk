import 'dart:async';
import 'dart:convert';

import 'package:launchdarkly_dart_common/launchdarkly_dart_common.dart';
import 'package:launchdarkly_event_source_client/launchdarkly_event_source_client.dart';

import '../config/data_source_config.dart';
import 'data_source.dart';
import 'data_source_status.dart';

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

final class StreamingDataSource implements DataSource {
  final LDLogger _logger;

  final ServiceEndpoints _endpoints;

  final StreamingDataSourceConfig _dataSourceConfig;

  final MessageSubscriptionFactory _subFactory;

  late final Uri _uri;

  late final HttpProperties _httpProperties;

  late final String _contextString;
  bool _stopped = false;

  StreamSubscription<MessageEvent>? _subscription;

  final StreamController<DataSourceEvent> _dataController = StreamController();

  @override
  Stream<DataSourceEvent> get events => _dataController.stream;

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
      required StreamingDataSourceConfig dataSourceConfig,
      required HttpProperties httpProperties,
      MessageSubscriptionFactory subFactory = _defaultSubscriptionFactory})
      : _endpoints = endpoints,
        _logger = logger.subLogger('StreamingDataSource'),
        _dataSourceConfig = dataSourceConfig,
        _subFactory = subFactory,
        _httpProperties = httpProperties {
    if (_dataSourceConfig.useReport) {
      _logger.warn('REPORT is currently not supported for streaming');
    }

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

  @override
  void start() {
    if (_subscription != null || _permanentShutdown || _stopped) {
      return;
    }
    _stopped = false;
    _logger.debug('Establishing new streaming connection, uri: $_uri');
    _subscription = _subFactory(_uri, _httpProperties, (event) async {
      if (_stopped) {
        return;
      }

      _logger.debug('Received event, data: ${event.data}');
      _dataController.sink.add(DataEvent(event.type, event.data));
      // TODO: NEED TO RE-THINK restart.
    }, (err) {
      if (_permanentShutdown) {
        return;
      }
      _permanentShutdown = true;
      _logger
          .error('Encountered an unrecoverable error: "$err", Shutting down.');
      stop();
      _dataController.sink.add(StatusEvent(ErrorKind.unknown, null,
          'Encountered unrecoverable error streaming'));
    });
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
