import 'dart:async';
import 'package:launchdarkly_common_client/launchdarkly_common_client.dart';

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

  void flush();
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

  @override
  void flush() {
    _client.flush();
  }
}

final class ConnectionManagerConfig {
  /// Configured foreground connection mode used as the automatic resolution
  /// foreground slot.
  final ConnectionMode foregroundConnectionMode;

  /// Configured background connection mode used as the automatic resolution
  /// background slot.
  ///
  /// Defaults to [ConnectionMode.offline] per CONNMODE §2.2.1 .
  final ConnectionMode backgroundConnectionMode;

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

  ConnectionManagerConfig({
    this.foregroundConnectionMode = ConnectionMode.streaming,
    this.backgroundConnectionMode = ConnectionMode.offline,
    this.runInBackground = true,
    this.disableAutomaticBackgroundHandling = false,
    this.disableAutomaticNetworkHandling = false,
  });
}

/// This class tracks the state of the application, network, configuration,
/// and desired network state. It uses this information to request specific
/// connection modes.
///
/// Automatic [ConnectionMode] selection uses [resolveConnectionMode] with
/// [flutterDefaultResolutionTable] by default, or [resolutionTable] when
/// supplied to the constructor.
///
/// This class does not contain any platform specific code. Instead platform
/// specific code should be implemented in a [StateDetector]. This is primarily
/// to facilitate easy of testing.
final class ConnectionManager {
  final LDLogger _logger;
  final ConnectionManagerConfig _config;
  final StateDetector _detector;
  final ConnectionDestination _destination;
  final List<ModeResolutionEntry> _resolutionTable;

  StreamSubscription<ApplicationState>? _applicationStateSub;
  StreamSubscription<NetworkState>? _networkStateSub;

  /// When non-null, [resolveConnectionMode] is skipped and this mode is
  /// applied regardless of lifecycle/network.
  ConnectionMode? _modeOverride;

  ApplicationState _applicationState;
  NetworkState _networkState;

  bool _offline = false;

  bool get offline => _offline;

  set offline(bool offline) {
    _offline = offline;
    _handleState();
  }

  ConnectionManager({
    required LDLogger logger,
    required ConnectionManagerConfig config,
    required ConnectionDestination destination,
    required StateDetector detector,
    List<ModeResolutionEntry>? resolutionTable,
  })  : _logger = logger.subLogger('ConnectionManager'),
        _config = config,
        _destination = destination,
        _resolutionTable = resolutionTable ?? flutterDefaultResolutionTable(),
        _applicationState = ApplicationState.foreground,
        _networkState = NetworkState.available,
        _detector = detector {
    if (!_config.disableAutomaticBackgroundHandling) {
      _applicationStateSub =
          detector.applicationState.listen((applicationState) {
        // TODO (SDK-2187): plumb in debouncer here

        _applicationState = applicationState;
        _handleState();
      });
    }

    if (!_config.disableAutomaticNetworkHandling) {
      _networkStateSub = detector.networkState.listen((networkState) {
        // TODO (SDK-2187): plumb in debouncer here

        _networkState = networkState;
        _destination
            .setNetworkAvailability(networkState == NetworkState.available);
        _handleState();
      });
    }
  }

  void _handleState() {
    _logger.debug('Handling state: $_applicationState:$_networkState');

    final networkAvailable = _networkState == NetworkState.available;
    final inForeground = _applicationState == ApplicationState.foreground;

    final ConnectionMode resolved;
    if (_offline) {
      resolved = ConnectionMode.offline;
    } else if (_modeOverride != null) {
      resolved = _modeOverride!;
    } else {
      final modeState = ModeState(
        networkAvailable: networkAvailable,
        inForeground: inForeground,
        runInBackground: _config.runInBackground,
        foregroundConnectionMode: _config.foregroundConnectionMode,
        backgroundConnectionMode: _config.backgroundConnectionMode,
      );
      resolved = resolveConnectionMode(_resolutionTable, modeState);
    }

    if (!_offline && !inForeground && networkAvailable) {
      _destination.flush();
    }

    _destination.setMode(resolved);

    if (_offline || (!inForeground && !_config.runInBackground)) {
      _destination.setEventSendingEnabled(false, flush: false);
    } else {
      _destination.setEventSendingEnabled(true);
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
  void setMode(ConnectionMode? mode) {
    _modeOverride = mode;
    _handleState();
  }
}
