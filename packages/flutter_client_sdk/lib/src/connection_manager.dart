import 'dart:async';
import 'package:launchdarkly_common_client/ld_common_client.dart';

enum ApplicationState {
  /// The application is in the foreground.
  foreground,

  /// The application is in the background.
  ///
  /// Note, the application will not be active while in the background, but
  /// it will track when it is entering or exiting a background state.
  background
}

enum NetworkState {
  /// There is no network available for the SDK to use.
  unavailable,

  /// The network is available. Note that network requests may still fail
  /// for other reasons.
  available
}

/// Interface which provides notifications of application and network state
/// changes. Implementers should always emit the initial states.
abstract interface class StateDetector {
  Stream<NetworkState> get networkState;

  Stream<ApplicationState> get applicationState;

  void dispose();
}

/// Connection destination allows for the connection manager to easily
/// be tested. The LDCommonClient doesn't implement this, so there is a small
/// private adapter.
abstract interface class ConnectionDestination {
  void setMode(ConnectionMode mode);

  void setNetworkAvailability(bool available);

  void setEventSendingEnabled(bool enabled, {bool flush = true});
}

/// Basic adapter that turns an LDCommonClient into a ConnectionDestination.
final class DartClientAdapter implements ConnectionDestination {
  final LDCommonClient _client;

  DartClientAdapter(this._client);

  @override
  void setMode(ConnectionMode mode) {
    _client.setMode(mode);
  }

  @override
  void setNetworkAvailability(bool available) {
    _client.setNetworkAvailability(available);
  }

  @override
  void setEventSendingEnabled(bool enabled, {bool flush = true}) {
    _client.setEventSendingEnabled(enabled, flush: flush);
  }
}

final class ConnectionManagerConfig {
  /// The initial connection mode the SDK should use.
  final ConnectionMode initialConnectionMode;

  /// Some platforms (windows, web, mac, linux) can continue executing code
  /// in the background.
  final bool runInBackground;

  /// Disable handling of network availability. When this is true the
  /// connection state will not have any automatic changes when network
  /// availability changes. For instance a connection that is active will
  /// continue to retry while the network is not available.
  ///
  /// The network will always be treated as available.
  final bool disableAutomaticNetworkHandling;

  /// Disable handling associated with transitioning between the foreground
  /// and background. This means that an application will make no attempt to
  /// disconnect when entering background state, and it will not attempt
  /// to re-establish a connection entering the foreground, beyond the standard
  /// retry logic.
  ///
  /// The application will always be treated as in the foreground.
  final bool disableAutomaticBackgroundHandling;

  ConnectionManagerConfig(
      {this.initialConnectionMode = ConnectionMode.streaming,
      this.runInBackground = true,
      this.disableAutomaticBackgroundHandling = false,
      this.disableAutomaticNetworkHandling = false});
}

/// This class tracks the state of the application, network, configuration,
/// and desired network state. It uses this information to request specific
/// data source configurations.
///
/// This class does not contain any platform specific code. Instead platform
/// specific code should be implemented in a [StateDetector]. This is primarily
/// to facilitate easy of testing.
final class ConnectionManager {
  final LDLogger _logger;
  final ConnectionManagerConfig _config;
  final StateDetector _detector;
  final ConnectionDestination _destination;

  StreamSubscription<ApplicationState>? _applicationStateSub;
  StreamSubscription<NetworkState>? _networkStateSub;

  ConnectionMode _currentConnectionMode;
  ApplicationState _applicationState;
  NetworkState _networkState;

  bool _offline = false;

  bool get offline => _offline;

  set offline(bool offline) {
    _offline = offline;
    _handleState();
  }

  ConnectionManager(
      {required LDLogger logger,
      required ConnectionManagerConfig config,
      required ConnectionDestination destination,
      required StateDetector detector})
      : _logger = logger.subLogger('ConnectionManager'),
        _config = config,
        _destination = destination,
        _currentConnectionMode = config.initialConnectionMode,
        _applicationState = ApplicationState.foreground,
        _networkState = NetworkState.available,
        _detector = detector {
    if (!_config.disableAutomaticBackgroundHandling) {
      _applicationStateSub =
          detector.applicationState.listen((applicationState) {
        _applicationState = applicationState;
        _handleState();
      });
    }

    if (!_config.disableAutomaticNetworkHandling) {
      _networkStateSub = detector.networkState.listen((networkState) {
        _networkState = networkState;
        _handleState();
      });
    }
  }

  void _setForegroundAvailableMode() {
    if (offline) {
      _destination.setMode(ConnectionMode.offline);
      _destination.setEventSendingEnabled(false, flush: false);
      return;
    }

    /// Currently the foreground mode will always be whatever the last active
    /// connection mode was.
    _destination.setMode(_currentConnectionMode);
    _destination.setEventSendingEnabled(true);
  }

  void _setBackgroundAvailableMode() {
    if (!_config.runInBackground) {
      // TODO: Can we support the backgroundDisabled data source status?
      // TODO: Is it acceptable for the data source status and `offline` to
      // report an `offline` status?
      _destination.setMode(ConnectionMode.offline);
      _destination.setEventSendingEnabled(false);
      return;
    }

    /// If connections in the background are allowed, then use the same mode
    /// as is configured for the foreground.
    _setForegroundAvailableMode();
    _destination.setEventSendingEnabled(true);
  }

  void _handleState() {
    _logger.debug('Handling state: $_applicationState:$_networkState');

    switch (_networkState) {
      case NetworkState.unavailable:
        _destination.setNetworkAvailability(false);
      case NetworkState.available:
        _destination.setNetworkAvailability(true);
        switch (_applicationState) {
          case ApplicationState.foreground:
            _setForegroundAvailableMode();
          case ApplicationState.background:
            _setBackgroundAvailableMode();
        }
    }
  }

  /// This should be called when closing the client.
  ///
  /// This isn't a widget, so we cannot depend on it just being disposed.
  void dispose() {
    _applicationStateSub?.cancel();
    _networkStateSub?.cancel();
    _detector.dispose();
  }

  /// Set the desired connection mode for the SDK.
  void setMode(ConnectionMode mode) {
    _currentConnectionMode = mode;
    _handleState();
  }
}
