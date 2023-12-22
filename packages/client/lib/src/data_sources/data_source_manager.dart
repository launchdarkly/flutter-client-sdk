import 'dart:async';

import 'package:launchdarkly_dart_common/ld_common.dart'
    show LDContext, LDLogger;

import 'data_source.dart';
import 'data_source_event_handler.dart';
import 'data_source_status_manager.dart';

enum ConnectionMode {
  networkUnavailable,
  offline,
  foregroundStreaming,
  foregroundPolling,
  backgroundPolling
}

// TODO: Background polling may need to be orchestrated differently.

typedef DataSourceFactory = DataSource Function(LDContext context);

/// The data source manager controls which data source is connected to
/// the data source status as well as the data source event handler.
final class DataSourceManager {
  ConnectionMode _activeMode;
  LDContext? _activeContext;

  final LDLogger _logger;
  final DataSourceStatusManager _statusManager;
  final DataSourceEventHandler _dataSourceEventHandler;
  final Map<ConnectionMode, DataSourceFactory> _dataSourceFactories;

  DataSource? _activeDataSource;
  StreamSubscription<MessageStatus?>? _subscription;

  DataSourceManager(
      {ConnectionMode startingMode = ConnectionMode.foregroundStreaming,
      required DataSourceStatusManager statusManager,
      required DataSourceEventHandler dataSourceEventHandler,
      required LDLogger logger,
      required Map<ConnectionMode, DataSourceFactory> dataSourceFactories})
      : _activeMode = startingMode,
        _logger = logger.subLogger('DataSourceManager'),
        _statusManager = statusManager,
        _dataSourceEventHandler = dataSourceEventHandler,
        _dataSourceFactories = dataSourceFactories;

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

  void _stopConnection() {
    _activeDataSource?.stop();
    _subscription?.cancel();
    _activeDataSource = null;
  }

  DataSource? _createDataSource(ConnectionMode mode) {
    if (_activeContext != null) {
      return _dataSourceFactories[mode]?.call(_activeContext!);
    }
    return null;
  }

  void _setupConnection() {
    _stopConnection();

    switch (_activeMode) {
      case ConnectionMode.networkUnavailable:
        _statusManager.setNetworkUnavailable();
      case ConnectionMode.offline:
        _statusManager.setOffline();
      case ConnectionMode.backgroundPolling:
        if (!_dataSourceFactories
            .containsKey(ConnectionMode.backgroundPolling)) {
          _statusManager.setBackgroundDisabled();
        }

      case ConnectionMode.foregroundStreaming:
      case ConnectionMode.foregroundPolling:
      default:
      // TODO: Should we go back to initializing, or have some other
      // equivalent state.
    }


    _activeDataSource = _createDataSource(_activeMode);
    _subscription = _activeDataSource?.events.asyncMap((event) async {
      switch (event) {
        case DataEvent():
          return _dataSourceEventHandler.handleMessage(event.type, event.data);
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
}
