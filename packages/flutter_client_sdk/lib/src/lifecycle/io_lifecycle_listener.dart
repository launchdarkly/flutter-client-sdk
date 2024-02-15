import 'dart:async';

import 'package:flutter/widgets.dart';

/// Lifecycle listener that uses the Flutter [AppLifecycleListener].
/// Unfortunately, the [AppLifecycleListener] does not support web very well at
/// the moment, so the [LDAppLifecycleListener] was created.
class LDAppLifecycleListener {
  late final StreamController<AppLifecycleState> _streamController;
  AppLifecycleListener? _underlyingListener;

  LDAppLifecycleListener() {
    _streamController = StreamController.broadcast(onListen: () {
      _underlyingListener = AppLifecycleListener(
          onStateChange: (state) => _streamController.add(state));
    }, onCancel: () {
      _underlyingListener?.dispose();
      _underlyingListener = null;
    });
  }

  Stream<AppLifecycleState> get stream => _streamController.stream;

  void close() {
    _streamController.close();
  }
}
