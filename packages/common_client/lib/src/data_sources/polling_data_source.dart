import 'dart:async';
import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:launchdarkly_dart_common/launchdarkly_dart_common.dart';
import 'dart:math';

import '../config/data_source_config.dart';
import '../config/defaults/credential_type.dart';
import '../config/defaults/default_config.dart';
import 'data_source.dart';
import 'data_source_status.dart';
import 'data_source_requestor.dart';
import 'get_environment_id.dart';

HttpClient _defaultClientFactory(HttpProperties httpProperties) {
  return HttpClient(httpProperties: httpProperties);
}

// Currently the polling data source does not accept an external etag. This is
// because the etag may not correspond to the current payload the SDK has,
// because streaming could have been used in the interim.

final class PollingDataSource implements DataSource {
  final LDLogger _logger;

  final ServiceEndpoints _endpoints;

  final PollingDataSourceConfig _dataSourceConfig;

  late final HttpClient _client;

  late final DataSourceRequestor _requestor;

  Timer? _pollTimer;

  final Stopwatch _pollStopwatch = Stopwatch();

  late final Duration _pollingInterval;

  late final String _contextString;

  bool _stopped = false;

  late final Uri _uri;

  late final RequestMethod _method;

  final StreamController<DataSourceEvent> _eventController = StreamController();

  late final String _credential;

  @override
  Stream<DataSourceEvent> get events => _eventController.stream;

  /// Used to track if there has been an unrecoverable error.
  bool _permanentShutdown = false;

  /// The [client] parameter is primarily intended for testing, but it also
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
      HttpClient Function(HttpProperties) clientFactory =
          _defaultClientFactory})
      : _endpoints = endpoints,
        _logger = logger.subLogger('PollingDataSource'),
        _dataSourceConfig = dataSourceConfig,
        _credential = credential {
    _pollingInterval = testingInterval ?? dataSourceConfig.pollingInterval;

    if (_dataSourceConfig.useReport) {
      final updatedProperties =
          httpProperties.withHeaders({'content-type': 'application/json'});
      _method = RequestMethod.report;
      _client = clientFactory(updatedProperties);
    } else {
      _method = RequestMethod.get;
      _client = clientFactory(httpProperties);
    }

    _requestor = DataSourceRequestor(
        client: _client, logger: _logger, credential: credential);

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
          _dataSourceConfig.pollingReportPath(credential, _contextString));
    } else {
      completeUrl = appendPath(_endpoints.polling,
          _dataSourceConfig.pollingGetPath(credential, _contextString));
    }
    if (_dataSourceConfig.withReasons) {
      completeUrl = '$completeUrl?withReasons=true';
    }

    _uri = Uri.parse(completeUrl);
  }

  Future<void> _makeRequest() async {
    if (_stopped) {
      return;
    }

    final chainId = _requestor.startRequestChain();

    try {
      final res = await _requestor.makeRequest(
        chainId,
        _uri,
        _method,
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
        _eventController.sink.add(result.event!);
      }

      if (result.shutdown) {
        _permanentShutdown = true;
        stop();
      }
    } catch (err) {
      _logger.error('encountered error with polling request: $err, will retry');
      _eventController.sink
          .add(StatusEvent(ErrorKind.networkError, null, err.toString()));
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
