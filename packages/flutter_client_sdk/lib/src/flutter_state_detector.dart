import 'dart:async';

import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:flutter/scheduler.dart';

import 'connection_manager.dart';
import 'lifecycle/stub_lifecycle_listener.dart'
    if (dart.library.io) 'lifecycle/io_lifecycle_listener.dart'
    if (dart.library.js_interop) 'lifecycle/js_lifecycle_listener.dart';

/// This class detects the application and network state for flutter.
final class FlutterStateDetector implements StateDetector {
  final StreamController<ApplicationState> _applicationStateController =
      StreamController();
  final StreamController<NetworkState> _networkStateController =
      StreamController();

  @override
  Stream<ApplicationState> get applicationState =>
      _applicationStateController.stream;

  @override
  Stream<NetworkState> get networkState => _networkStateController.stream;

  /// The application lifecycle state read synchronously at construction
  /// time. Suitable for seeding [ConnectionManagerConfig.initialApplicationState].
  ///
  /// [SchedulerBinding.instance.lifecycleState] returns a cached value
  /// populated by the framework when the OS pushes lifecycle messages.
  /// The read is synchronous and depends only on
  /// [WidgetsFlutterBinding.ensureInitialized] having been called -- which
  /// the SDK already requires for [FlutterStateDetector] to function.
  final ApplicationState initialApplicationState;

  late final LDAppLifecycleListener _lifecycleListener;
  late final StreamSubscription<dynamic> _connectivitySubscription;

  FlutterStateDetector()
      : initialApplicationState =
            _resolveLifecycleState(SchedulerBinding.instance.lifecycleState) {
    final initialState = SchedulerBinding.instance.lifecycleState;
    if (initialState != null) {
      _handleApplicationLifecycle(initialState);
    }

    _lifecycleListener = LDAppLifecycleListener();
    _lifecycleListener.stream.listen(_handleApplicationLifecycle);

    Connectivity().checkConnectivity().then(_setConnectivity);

    // The changed event does not emit the initial state.
    _connectivitySubscription =
        Connectivity().onConnectivityChanged.listen(_setConnectivity);
  }

  static ApplicationState _resolveLifecycleState(AppLifecycleState? state) =>
      switch (state) {
        AppLifecycleState.resumed => ApplicationState.foreground,
        AppLifecycleState.hidden ||
        AppLifecycleState.paused =>
          ApplicationState.background,
        AppLifecycleState.detached ||
        AppLifecycleState.inactive ||
        null =>
          ApplicationState.foreground,
      };

  void _setConnectivity(dynamic connectivityResult) {
    // TODO: This is a temporary fix to handle the breaking change in
    // connectivity_plus v6
    final resultsList =
        connectivityResult is List ? connectivityResult : [connectivityResult];
    final isUnavailable =
        resultsList.any((result) => result == ConnectivityResult.none);

    if (isUnavailable) {
      _networkStateController.sink.add(NetworkState.unavailable);
    } else {
      _networkStateController.sink.add(NetworkState.available);
    }
  }

  /// The application lifecycle is as follows.
  /// Diagram based on: https://api.flutter.dev/flutter/widgets/AppLifecycleListener-class.html
  /// +-----------+       onStart             +-----------+
  /// |           +--------------------------->           |
  /// | Detached  |                           | Resumed   |
  /// |           |                           |           |
  /// +--------^--+                           +-^-------+-+
  ///          |                                |       |
  ///          |onDetach              onInactive|       |onResume
  ///          |                                |       |
  ///          |  onPause                       |       |
  /// +--------+--+       +-----------+onHide +-+-------v-+
  /// |           <-------+           <-------+           |
  /// | Paused    |       | Hidden    |       | Inactive  |
  /// |           +------->           +------->           |
  /// +-----------+       +-----------+onShow +-----------+
  ///             onRestart
  ///
  /// On iOS/Android the hidden state is synthesized in the process of pausing,
  /// so it will always hide before being paused. On desktop/web platforms
  /// hidden may happen when the app is covered.
  void _handleApplicationLifecycle(AppLifecycleState state) {
    switch (state) {
      case AppLifecycleState.detached:
        break;
      case AppLifecycleState.resumed:
        // From connectivity_plus:
        //
        // "Connectivity changes are no longer communicated to Android apps in
        // the background starting with Android O (8.0). You should always check
        // for connectivity status when your app is resumed. The broadcast is
        // only useful when your application is in the foreground."
        // https://github.com/fluttercommunity/plus_plugins/tree/main/packages/connectivity_plus/connectivity_plus
        //
        // So, when we detect an that we have been resumed, we query the current
        // connectivity state and emit an event.
        // There is some excess checking here, especially during app load, but
        // our reaction to the state depends on it being different, so reporting
        // the same state, in excess, has minimal impact and is better than
        // missing an active state transition.
        Connectivity().checkConnectivity().then(_setConnectivity);
        _applicationStateController.sink.add(ApplicationState.foreground);
      case AppLifecycleState.inactive:
        break;
      case AppLifecycleState.hidden:
      case AppLifecycleState.paused:
        _applicationStateController.sink.add(ApplicationState.background);
    }
  }

  @override
  void dispose() {
    _lifecycleListener.close();
    _applicationStateController.close();
    _networkStateController.close();
    _connectivitySubscription.cancel();
  }
}
