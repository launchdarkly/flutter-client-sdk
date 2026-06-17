import 'dart:async';

import 'package:launchdarkly_dart_common/launchdarkly_dart_common.dart'
    show LDContext, LDLogger;

import '../connection_mode.dart';
import '../fdv2_connection_mode.dart';
import '../offline_detail.dart';
import '../resolved_connection_mode.dart';
import 'data_source.dart';
import 'data_source_event_handler.dart';
import 'data_source_status_manager.dart';

typedef DataSourceFactory = DataSource Function(LDContext context);

/// The data source manager controls which data source is connected to
/// the data source status as well as the data source event handler.
final class DataSourceManager {
  /// The mode that drives factory lookup and status dispatch.
  FDv2ConnectionMode _activeConnectionMode;

  /// Semantically meaningful only when [_activeConnectionMode] is
  /// [FDv2Offline]. Otherwise carries a stale value from the last time the
  /// SDK was offline (or the construction-time default), and is intentionally
  /// only read inside the [FDv2Offline] arm of [_setupConnection].
  OfflineDetail _offlineDetail;

  LDContext? _activeContext;

  final LDLogger _logger;
  final DataSourceStatusManager _statusManager;
  final DataSourceEventHandler _dataSourceEventHandler;
  final Map<FDv2ConnectionMode, DataSourceFactory> _dataSourceFactories = {};

  DataSource? _activeDataSource;
  StreamSubscription<MessageStatus?>? _subscription;
  bool _stopped = false;

  Completer<void>? _identifyCompleter;

  DataSourceManager({
    ConnectionMode startingMode = ConnectionMode.streaming,
    required DataSourceStatusManager statusManager,
    required DataSourceEventHandler dataSourceEventHandler,
    required LDLogger logger,
  })  : _activeConnectionMode = switch (startingMode) {
          ConnectionMode.streaming => const FDv2Streaming(),
          ConnectionMode.polling => const FDv2Polling(),
          ConnectionMode.offline => const FDv2Offline(),
        },
        _offlineDetail = const OfflineSetOffline(),
        _logger = logger.subLogger('DataSourceManager'),
        _statusManager = statusManager,
        _dataSourceEventHandler = dataSourceEventHandler;

  /// Set the available data source factories. These factories will not apply
  /// until the next identify call. Currently factories will be set once during
  /// startup and before the first identify.
  void setFactories(Map<FDv2ConnectionMode, DataSourceFactory> factories) {
    _dataSourceFactories.clear();
    _dataSourceFactories.addAll(factories);
  }

  void identify(LDContext context, Completer<void> completer) {
    _identifyCompleter = completer;
    _activeContext = context;

    _setupConnection();
  }

  void setMode(ResolvedConnectionMode mode) {
    final newConnectionMode = mode.connectionMode;
    final newDetail = mode is ResolvedOffline ? mode.detail : null;
    final isOffline = newConnectionMode is FDv2Offline;
    if (newConnectionMode == _activeConnectionMode &&
        (!isOffline || newDetail == _offlineDetail)) {
      _logger.debug('Mode is already set to: $mode');
      return;
    }
    _logger.debug(
        'Changing connection mode from: $_activeConnectionMode to: $mode');
    _activeConnectionMode = newConnectionMode;
    if (newDetail != null) {
      _offlineDetail = newDetail;
    }
    _setupConnection();
  }

  void _stopConnection() {
    _activeDataSource?.stop();
    _subscription?.cancel();
    _activeDataSource = null;
  }

  void _completeIdentify(MessageStatus handled) {
    if (handled == MessageStatus.messageHandled && _identifyCompleter != null) {
      if (_identifyCompleter!.isCompleted) {
        _logger.error('Identify was already complete before receiving '
            'data. This could represent an issue with SDK logic. Please'
            'make a bug report if you encounter this situation.');
      } else {
        _identifyCompleter!.complete();
      }
    }
    // Only need to complete this the first time.
    _identifyCompleter = null;
  }

  DataSource? _createDataSource(FDv2ConnectionMode mode) {
    if (_activeContext != null) {
      if (_dataSourceFactories[mode] == null) {
        _logger.debug('No data source factory exists for mode: $mode');
      }
      return _dataSourceFactories[mode]?.call(_activeContext!);
    }
    return null;
  }

  void _setupConnection() {
    // In the future we may want to consider not stopping the connection
    // when the network is not available. Instead it would be good to allow
    // the connection to remain, but disable the retry logic. This would
    // prevent unneeded connection churn.

    if (_stopped) {
      _logger.debug(
          'Request to setup connection after data source manager was stopped');
      return;
    }

    _stopConnection();

    switch (_activeConnectionMode) {
      case FDv2Offline():
        switch (_offlineDetail) {
          case OfflineSetOffline():
            _statusManager.setOffline();
          case OfflineNetworkUnavailable():
            _statusManager.setNetworkUnavailable();
          case OfflineBackgroundDisabled():
            _statusManager.setBackgroundDisabled();
        }
        return;
      case FDv2Streaming():
      case FDv2Polling():
      case FDv2Background():
        break;
    }

    _activeDataSource = _createDataSource(_activeConnectionMode);
    _subscription = _activeDataSource?.events.asyncMap((event) async {
      if (_activeContext == null) {
        _logger.error(
            'No active context when handling an event from a data source.'
            ' This most likely represents a bug in the SDK.');
        return MessageStatus.messageHandled;
      }
      switch (event) {
        case DataEvent():
          var handled = await _dataSourceEventHandler.handleMessage(
              _activeContext!, event.type, event.data,
              environmentId: event.environmentId);
          _completeIdentify(handled);
          return handled;
        case PayloadEvent():
          var handled = await _dataSourceEventHandler.handlePayload(
              _activeContext!, event.changeSet,
              environmentId: event.environmentId);
          _completeIdentify(handled);
          return handled;
        case StatusEvent():
          if (_identifyCompleter != null && !_identifyCompleter!.isCompleted) {
            _identifyCompleter!.completeError(Exception(event.message));
            _identifyCompleter = null;
          }
          if (event.statusCode != null) {
            _statusManager.setErrorResponse(event.statusCode!, event.message,
                shutdown: event.shutdown);
          } else {
            _statusManager.setErrorByKind(event.kind, event.message,
                shutdown: event.shutdown);
          }
      }
    }).listen((status) {
      if (status is MessageStatus && status == MessageStatus.invalidMessage) {
        _activeDataSource?.restart();
      }
    });
    _activeDataSource?.start();
  }

  void stop() {
    _stopped = true;
    _stopConnection();
  }
}
