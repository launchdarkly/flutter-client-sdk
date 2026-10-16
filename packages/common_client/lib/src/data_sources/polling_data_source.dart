import 'dart:async';
import 'dart:convert';
import 'package:launchdarkly_dart_common/launchdarkly_dart_common.dart';

import '../config/data_source_config.dart';
import 'data_source.dart';
import 'fdv2/payload.dart';
import 'requestor.dart';

HttpClient _defaultHttpClientFactory(HttpProperties httpProperties) {
  return HttpClient(httpProperties: httpProperties);
}

// Currently the polling data source does not accept an external etag. This is
// because the etag may not correspond to the current payload the SDK has,
// because streaming could have been used in the interim.

/// A data source that polls for flag updates.
///
/// Each poll is scheduled when the previous poll completes. After a
/// successful poll, the next poll comes one polling interval later. After a
/// failed poll, the wait comes from the [RetryState]. A payload that the SDK
/// cannot apply is a failed poll. No failure stops the data source.
final class PollingDataSource implements DataSource {
  final LDLogger _logger;

  Timer? _pollTimer;

  late final Duration _pollingInterval;

  late final String _contextString;

  bool _stopped = false;

  final StreamController<DataSourceEvent> _eventController = StreamController();

  late final String _credential;

  late final Requestor _requestor;

  late final RetryState _retryState;

  /// Set when the last poll returned a payload that the SDK has not yet
  /// rejected. The SDK rejects a payload through [restart].
  bool _payloadPending = false;

  @override
  Stream<DataSourceEvent> get events => _eventController.stream;

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
    _retryState = RetryState.polling(_pollingInterval);

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
    if (_payloadPending) {
      // The previous payload was applied, because it was not rejected
      // before this poll.
      _payloadPending = false;
      _retryState.recordSuccess();
    }
    final event = await _requestor.requestAllFlags();

    if (_stopped) {
      return;
    }

    switch (event) {
      case null:
        // No change (e.g. 304 Not Modified). This is a successful poll, and
        // a change set of type none restores the valid status.
        _retryState.recordSuccess();
        _eventController.sink.add(_unchanged());
        _schedulePoll(_pollingInterval);
      case DataEvent():
        _payloadPending = true;
        _eventController.sink.add(event);
        _schedulePoll(_pollingInterval);
      case StatusEvent():
        _eventController.sink.add(event);
        _handleFailure(event);
      case PayloadEvent():
      case InitializedEvent():
        // The FDv1 requestor never produces FDv2 payload or lifecycle events.
        break;
    }
  }

  void _handleFailure(StatusEvent event) {
    if (event.statusCode case final statusCode?) {
      final kind = classifyHttpStatus(statusCode);
      final delay = _retryState.recordFailure(kind);
      switch (kind) {
        case FailureKind.unexpected:
          _logger.error('Received unexpected status code $statusCode when '
              'polling.${credentialHint(statusCode)} Will retry in '
              '${delay.inMilliseconds} ms.');
        case FailureKind.normal:
          _logger.warn('Received status code $statusCode when polling. Will '
              'retry in ${delay.inMilliseconds} ms.');
      }
      _schedulePoll(delay);
      return;
    }
    final delay = _retryState.recordFailure(FailureKind.normal);
    _logger.warn('Encountered error with polling request: ${event.message}. '
        'Will retry in ${delay.inMilliseconds} ms.');
    _schedulePoll(delay);
  }

  void _schedulePoll(Duration delay) {
    if (_stopped) {
      return;
    }
    _pollTimer = Timer(delay, _doPoll);
  }

  @override
  void start() {
    if (_stopped) {
      return;
    }
    _doPoll();
  }

  /// Records that the SDK could not apply the last payload. The data source
  /// fetches a full payload again after the retry delay.
  @override
  void restart() {
    if (_stopped || !_payloadPending) {
      return;
    }
    _payloadPending = false;
    _requestor.clearEtag();
    _pollTimer?.cancel();
    final delay = _retryState.recordFailure(FailureKind.normal);
    _logger.warn('Polling response contained invalid data. Will retry in '
        '${delay.inMilliseconds} ms.');
    _schedulePoll(delay);
  }

  @override
  void stop() {
    _stopped = true;
    _pollTimer?.cancel();
    _pollTimer = null;
    _eventController.close();
  }
}

/// A change set that confirms that the SDK data is current.
PayloadEvent _unchanged() =>
    PayloadEvent(const ChangeSet(type: PayloadType.none, updates: {}));
