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
  void setMode(ResolvedConnectionMode mode);

  void setNetworkAvailability(bool available);

  void setEventSendingEnabled(bool enabled, {bool flush = true});

  void flush();
}

/// Basic adapter that turns an LDCommonClient into a ConnectionDestination.
final class DartClientAdapter implements ConnectionDestination {
  final LDCommonClient _client;

  DartClientAdapter(this._client);

  @override
  void setMode(ResolvedConnectionMode mode) {
    _client.setResolvedMode(mode);
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
  final ConnectionMode initialConnectionMode;

  /// Configured background connection mode used as the automatic resolution
  /// background slot.
  ///
  /// Defaults to [const FDv2Offline()].
  final FDv2ConnectionMode backgroundConnectionMode;

  /// An initial mode override applied at construction, equivalent to calling
  /// [ConnectionManager.setMode] immediately after creation. When non-null
  /// the manager starts in this mode and suppresses automatic resolution
  /// until the override is cleared.
  ///
  /// Defaults to null (automatic resolution from construction).
  final FDv2ConnectionMode? initialModeOverride;

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
  /// and background. This means that an application will not automatically
  /// disconnect when entering background state, and it will not automatically
  /// re-establish a connection entering the foreground, beyond the standard
  /// retry logic.
  final bool disableAutomaticBackgroundHandling;

  /// Window across which lifecycle, network, and user-mode-override signals
  /// are debounced before automatic resolution runs. A value of
  /// [Duration.zero] disables debouncing (signals apply synchronously).
  /// Defaults to one second.
  final Duration debounceWindow;

  /// The application's lifecycle state at construction time. Used to seed
  /// the manager's initial lifecycle assumption so the SDK doesn't default
  /// to foreground when the host platform already knows the app launched
  /// into the background. Callers that can query the platform synchronously
  /// (e.g. via [SchedulerBinding.instance.lifecycleState]) should pass the
  /// resolved value here; callers without that information should leave
  /// the default.
  ///
  /// Defaults to [ApplicationState.foreground].
  final ApplicationState initialApplicationState;

  ConnectionManagerConfig({
    this.initialConnectionMode = ConnectionMode.streaming,
    this.backgroundConnectionMode = const FDv2Offline(),
    this.initialModeOverride,
    this.runInBackground = true,
    this.disableAutomaticBackgroundHandling = false,
    this.disableAutomaticNetworkHandling = false,
    this.debounceWindow = const Duration(seconds: 1),
    this.initialApplicationState = ApplicationState.foreground,
  });
}

/// This class tracks the state of the application, network, configuration,
/// and desired network state. It uses this information to request specific
/// connection modes.
///
/// Automatic resolution uses [resolveMode] with
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
  late final StateDebounceManager _debouncer;
  late final StreamSubscription<DebouncedState> _debounceSub;

  StreamSubscription<ApplicationState>? _applicationStateSub;
  StreamSubscription<NetworkState>? _networkStateSub;

  /// When non-null, [resolveMode] is skipped and this mode is
  /// applied regardless of lifecycle/network. Seeded from
  /// [ConnectionManagerConfig.initialModeOverride].
  FDv2ConnectionMode? _modeOverride;

  ApplicationState _applicationState;
  NetworkState _networkState;

  bool _offline = false;

  /// Whether the SDK has been explicitly placed in the offline state.
  ///
  /// Assigning this property synchronously drives the resolved mode to
  /// offline (or back to automatic resolution when set to `false`). It
  /// intentionally bypasses the debounce window.
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
        _modeOverride = config.initialModeOverride,
        _applicationState = config.initialApplicationState,
        // Network has no synchronous platform API; start optimistic. If
        // the network is actually unavailable, the first detector emission
        // will trigger a debounced reconcile that flips us to offline.
        // The common case (network available) is the best performing default.
        _networkState = NetworkState.available,
        _detector = detector {
    _debouncer = StateDebounceManager(
      initialState: DebouncedState(
        networkAvailable: true,
        inForeground:
            config.initialApplicationState == ApplicationState.foreground,
        requestedMode: config.initialModeOverride,
      ),
      debounceWindow: config.debounceWindow,
    );
    _debounceSub = _debouncer.stream.listen(_onDebounceReconcile);

    if (!_config.disableAutomaticBackgroundHandling) {
      _applicationStateSub =
          detector.applicationState.listen(_onApplicationStateChanged);
    }

    if (!_config.disableAutomaticNetworkHandling) {
      _networkStateSub = detector.networkState.listen(_onNetworkStateChanged);
    }
  }

  void _onApplicationStateChanged(ApplicationState newState) {
    // Flushing on transition to background must not be debounced
    if (newState == ApplicationState.background &&
        _applicationState == ApplicationState.foreground &&
        !_offline) {
      _destination.flush();
    }
    _applicationState = newState;
    _debouncer.setInForeground(newState == ApplicationState.foreground);
  }

  void _onNetworkStateChanged(NetworkState newState) {
    _networkState = newState;
    // Network-availability propagation to the destination is not debounced.
    // It informs the underlying client's analytics-sending state, separate
    // from the mode-resolution decision that the debouncer governs.
    _destination.setNetworkAvailability(newState == NetworkState.available);
    _debouncer.setNetworkAvailable(newState == NetworkState.available);
  }

  void _onDebounceReconcile(DebouncedState _) {
    // The debouncer's snapshot is intentionally ignored; this manager owns
    // the canonical view of lifecycle, network, override, and offline state.
    _handleState();
  }

  void _handleState() {
    _logger.debug('Handling state: $_applicationState:$_networkState');

    final networkAvailable = _networkState == NetworkState.available;
    final inForeground = _applicationState == ApplicationState.foreground;

    final ResolvedConnectionMode resolved;
    if (_offline) {
      resolved = const ResolvedOffline(OfflineSetOffline());
    } else if (_modeOverride case final mode?) {
      resolved = switch (mode) {
        FDv2Streaming() => const ResolvedStreaming(),
        FDv2Polling() => const ResolvedPolling(),
        FDv2Background() => const ResolvedBackground(),
        FDv2Offline() => const ResolvedOffline(OfflineSetOffline()),
      };
    } else {
      final modeState = ModeState(
        networkAvailable: networkAvailable,
        inForeground: inForeground,
        runInBackground: _config.runInBackground,
        foregroundConnectionMode: _fdv2FromFdv1(_config.initialConnectionMode),
        backgroundConnectionMode: _config.backgroundConnectionMode,
      );
      resolved = resolveMode(_resolutionTable, modeState);
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
    _debounceSub.cancel();
    _debouncer.close();
    _detector.dispose();
  }

  /// Set the desired connection mode for the SDK. Setting an override takes
  /// effect synchronously so subsequent automatic transitions are suppressed
  /// immediately; applying the resolved mode is debounced. Passing null
  /// clears the override and resumes automatic mode resolution.
  void setMode(FDv2ConnectionMode? mode) {
    _modeOverride = mode;
    _debouncer.setRequestedMode(mode);
  }
}

FDv2ConnectionMode _fdv2FromFdv1(ConnectionMode mode) => switch (mode) {
      ConnectionMode.streaming => const FDv2Streaming(),
      ConnectionMode.polling => const FDv2Polling(),
      ConnectionMode.offline => const FDv2Offline(),
    };
