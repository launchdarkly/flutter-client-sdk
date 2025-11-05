import 'dart:async';
import 'dart:convert';
import 'package:launchdarkly_dart_common/launchdarkly_dart_common.dart';
import 'dart:math';

import '../config/data_source_config.dart';
import 'data_source.dart';
import 'data_source_status.dart';
import 'requestor.dart';

HttpClient _defaultHttpClientFactory(HttpProperties httpProperties) {
  return HttpClient(httpProperties: httpProperties);
}

// Currently the polling data source does not accept an external etag. This is
// because the etag may not correspond to the current payload the SDK has,
// because streaming could have been used in the interim.

final class PollingDataSource implements DataSource {
  final LDLogger _logger;

  Timer? _pollTimer;

  final Stopwatch _pollStopwatch = Stopwatch();

  late final Duration _pollingInterval;

  late final String _contextString;

  bool _stopped = false;

  final StreamController<DataSourceEvent> _eventController = StreamController();

  late final String _credential;

  late final Requestor _requestor;

  @override
  Stream<DataSourceEvent> get events => _eventController.stream;

  /// Used to track if there has been an unrecoverable error.
  bool _permanentShutdown = false;

  /// The [httpClientFactory] parameter is primarily intended for testing, but it also
  /// could be used for customized clients which support functionality
  /// our default client support does not. For instance domain sockets or
  /// other connection mechanisms.
  ///
  /// The [testingInterval] should only be used for tests.
  PollingDataSource(
      {required String credential,
      required LDContext context,
      required ServiceEndpoints endpoints,
      required LDLogger logger,
      required PollingDataSourceConfig dataSourceConfig,
      required HttpProperties httpProperties,
      Duration? testingInterval,
      String? etag,
      HttpClient Function(HttpProperties)? httpClientFactory})
      : _logger = logger.subLogger('PollingDataSource'),
        _credential = credential {
    _pollingInterval = testingInterval ?? dataSourceConfig.pollingInterval;

    final method =
        dataSourceConfig.useReport ? RequestMethod.report : RequestMethod.get;

    final plainContextString =
        jsonEncode(LDContextSerialization.toJson(context, isEvent: false));
    if (dataSourceConfig.useReport) {
      _contextString = plainContextString;
    } else {
      _contextString = base64UrlEncode(utf8.encode(plainContextString));
    }

    _requestor = Requestor(
        logger: logger,
        contextString: _contextString,
        endpoints: endpoints,
        dataSourceConfig: dataSourceConfig,
        method: method,
        httpProperties: httpProperties,
        credential: _credential,
        httpClientFactory: httpClientFactory ?? _defaultHttpClientFactory);
  }

  Future<void> _doPoll() async {
    _pollStopwatch.reset();
    _pollStopwatch.start();

    final event = await _requestor.requestAllFlags();

    if (_stopped) {
      return;
    }

    switch (event) {
      case null:
        // No change.
        return;
      case DataEvent():
        _eventController.sink.add(event);
      case StatusEvent():
        _eventController.sink.add(event);
        final suffix = event.shutdown ? 'stopping polling' : 'will retry';
        final message = event.kind == ErrorKind.errorResponse
            ? 'received unexpected status code when polling'
            : 'encountered error with polling request';
        final argument = event.kind == ErrorKind.errorResponse
            ? event.statusCode
            : event.message;
        _logger.error('$message: $argument, $suffix');
        if (event.shutdown) {
          _permanentShutdown = true;
          stop();
        }
    }

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
        milliseconds: min(
            _pollingInterval.inMilliseconds - timeSincePoll.inMilliseconds,
            _pollingInterval.inMilliseconds));

    _pollTimer = Timer(delay, _doPoll);
  }

  @override
  void start() {
    if (_permanentShutdown || _stopped) {
      return;
    }

    _stopped = false;
    _doPoll();
  }

  @override
  void restart() {
    // For polling there is no persistent connection, so this function
    // has no effect.
  }

  @override
  void stop() {
    _stopped = true;
    _pollTimer?.cancel();
    _pollTimer = null;
    _eventController.close();
  }
}
