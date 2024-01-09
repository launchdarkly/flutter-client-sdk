import 'dart:async';

import 'package:launchdarkly_dart_common/ld_common.dart'
    show LDContext, LDLogger;

import 'data_source.dart';
import 'data_source_event_handler.dart';
import 'data_source_status_manager.dart';

enum ConnectionMode {
  offline,
  streaming,
  polling,
}

typedef DataSourceFactory = DataSource Function(LDContext context);

/// The data source manager controls which data source is connected to
/// the data source status as well as the data source event handler.
final class DataSourceManager {
  ConnectionMode _activeMode;
  LDContext? _activeContext;

  final LDLogger _logger;
  final DataSourceStatusManager _statusManager;
  final DataSourceEventHandler _dataSourceEventHandler;
  final Map<ConnectionMode, DataSourceFactory> _dataSourceFactories = {};

  // At start we assume the network is available.
  bool _networkAvailable = true;

  DataSource? _activeDataSource;
  StreamSubscription<MessageStatus?>? _subscription;
  bool _stopped = false;

  DataSourceManager({
    ConnectionMode startingMode = ConnectionMode.streaming,
    required DataSourceStatusManager statusManager,
    required DataSourceEventHandler dataSourceEventHandler,
    required LDLogger logger,
  })  : _activeMode = startingMode,
        _logger = logger.subLogger('DataSourceManager'),
        _statusManager = statusManager,
        _dataSourceEventHandler = dataSourceEventHandler;

  /// Set the available data source factories. These factories will not apply
  /// until the next identify fall. Currently factories will be set once during
  /// startup and before the first identify.
  void setFactories(Map<ConnectionMode, DataSourceFactory> factories) {
    _dataSourceFactories.clear();
    _dataSourceFactories.addAll(factories);
  }

  void identify(LDContext context) {
    _activeContext = context;

    _setupConnection();
  }

  void setMode(ConnectionMode mode) {
    if (mode == _activeMode) {
      _logger.debug('Mode already active: $_activeMode');
      return;
    }
    _logger.debug('Changing data source mode from: $_activeMode to: $mode');
    _activeMode = mode;
    _setupConnection();
  }

  void setNetworkAvailable(bool available) {
    if (_networkAvailable == available) {
      _logger.debug('Network availability set to same value: $available');
      return;
    }

    _logger.debug(
        'Network availability changed from: $_networkAvailable to: $available');
    _networkAvailable = available;
    _setupConnection();
  }

  void _stopConnection() {
    _activeDataSource?.stop();
    _subscription?.cancel();
    _activeDataSource = null;
  }

  DataSource? _createDataSource(ConnectionMode mode) {
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

    // If the active mode is offline, then we do not need to setup
    // a new connection. Additionally if we are offline, and the network
    // is not available, our data source status should remain offline.
    if (_activeMode == ConnectionMode.offline) {
      _statusManager.setOffline();
      return;
    }

    // We are not offline, but the network is not available, so we are going
    // to set the status as unavailable and not start a new connection.
    if (!_networkAvailable) {
      _statusManager.setNetworkUnavailable();
      return;
    }

    switch (_activeMode) {
      case ConnectionMode.offline:
        _statusManager.setOffline();
      case ConnectionMode.streaming:
      case ConnectionMode.polling:
      default:
      // We may want to consider adding another state to the data source state
      // for the intermediate between switching data sources, or for identifying
      // a new context.
    }

    _activeDataSource = _createDataSource(_activeMode);
    _subscription = _activeDataSource?.events.asyncMap((event) async {
      if (_activeContext == null) {
        _logger.error(
            'No active context when handling an event from a data source.'
            ' This most likely represents a bug in the SDK.');
        return MessageStatus.messageHandled;
      }
      switch (event) {
        case DataEvent():
          return _dataSourceEventHandler.handleMessage(
              _activeContext!, event.type, event.data);
        case StatusEvent():
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
        _setupConnection();
      }
    });
    _activeDataSource?.start();
  }

  void stop() {
    _stopped = true;
    _stopConnection();
  }
}
