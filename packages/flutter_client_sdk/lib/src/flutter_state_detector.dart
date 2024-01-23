import 'dart:async';

import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:flutter/scheduler.dart';
import 'package:flutter/widgets.dart';

import 'connection_manager.dart';

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

  late final AppLifecycleListener _lifecycleListener;
  late final StreamSubscription<ConnectivityResult> _connectivitySubscription;

  FlutterStateDetector() {
    final initialState = SchedulerBinding.instance.lifecycleState;
    if (initialState != null) {
      _handleApplicationLifecycle(initialState);
    }

    _lifecycleListener = AppLifecycleListener(
      onStateChange: (state) => _handleApplicationLifecycle(state),
    );

    Connectivity().checkConnectivity().then(_setConnectivity);

    // The changed event does not emit the initial state.
    _connectivitySubscription =
        Connectivity().onConnectivityChanged.listen(_setConnectivity);
  }

  void _setConnectivity(ConnectivityResult connectivityResult) {
    if (connectivityResult == ConnectivityResult.none) {
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
    _lifecycleListener.dispose();
    _applicationStateController.close();
    _networkStateController.close();
    _connectivitySubscription.cancel();
  }
}
