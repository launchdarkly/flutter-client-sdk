import 'dart:async';

import 'data_source_status.dart';

DateTime _defaultStamper() => DateTime.now();

/// Class which tracks the current data source status and emits updates when
/// the status changes.
final class DataSourceStatusManager {
  DataSourceState _state;
  DataSourceStatusErrorInfo? _errorInfo;
  DateTime _stateSince;
  final DateTime Function() _stamper;

  DataSourceStatus get status {
    return DataSourceStatus(
        state: _state, stateSince: _stateSince, lastError: _errorInfo);
  }

  final StreamController<DataSourceStatus> _controller =
      StreamController<DataSourceStatus>.broadcast();

  Stream<DataSourceStatus> get changes {
    return _controller.stream;
  }

  DataSourceStatusManager(
      {
      // This is primarily to allow overwriting the default time stamping for testing.
      stamper = _defaultStamper})
      : _state = DataSourceState.initializing,
        _stateSince = stamper(),
        _stamper = stamper;

  _updateState(DataSourceState requestedState, {bool isError = false}) {
    // While initializing the state remains initializing if the desired
    // transition is interrupted.
    final newState = requestedState == DataSourceState.interrupted &&
            _state == DataSourceState.initializing
        ? DataSourceState.initializing
        : requestedState;

    final changedState = _state != newState;
    if (changedState) {
      _state = newState;
      _stateSince = _stamper();
    }

    // For basic state changes we only want to notify listeners if the state
    // changed. For error state changes we always want to notify the listeners
    // of the new error data.
    if (changedState || isError) {
      _controller.sink.add(status);
    }
  }

  /// Report that the data source is in a valid state.
  setValid() {
    _updateState(DataSourceState.valid);
  }

  /// Report that the data source has been set offline.
  setOffline() {
    _updateState(DataSourceState.setOffline);
  }

  /// Report that the data source has been disabled from entering the
  /// background.
  setBackgroundDisabled() {
    _updateState(DataSourceState.backgroundDisabled);
  }

  /// Report that the data source is temporarily disabled while the device
  /// is offline.
  setNetworkUnavailable() {
    _updateState(DataSourceState.networkUnavailable);
  }

  /// Report an http error response.
  setErrorResponse(num statusCode, String message) {
    _errorInfo = DataSourceStatusErrorInfo(
        kind: ErrorKind.errorResponse,
        statusCode: statusCode,
        message: message,
        time: _stamper());
    _updateState(DataSourceState.interrupted, isError: true);
  }

  /// Report a specific error with a message. For error responses use
  /// [setErrorResponse].
  setErrorByKind(ErrorKind kind, String message) {
    _errorInfo = DataSourceStatusErrorInfo(
        kind: kind, statusCode: null, message: message, time: _stamper());
    _updateState(DataSourceState.interrupted, isError: true);
  }

  /// Shutdown the manager closing the changes stream.
  void stop() {
    _controller.close();
  }
}
