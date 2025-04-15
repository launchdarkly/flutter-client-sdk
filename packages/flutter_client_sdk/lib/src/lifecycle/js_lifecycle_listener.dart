import 'dart:async';
import 'dart:js_interop';
import 'package:web/web.dart' as web;

import 'package:flutter/widgets.dart';

/// Lifecycle listener that uses the underlying visibility of the html web
/// document to emit events.
class LDAppLifecycleListener {
  late final StreamController<AppLifecycleState> _streamController;

  LDAppLifecycleListener() {
    _streamController = StreamController.broadcast();

    void listenerFunc(web.Event event) =>
        _streamController.add(web.document.hidden == true
            ? AppLifecycleState.hidden
            : AppLifecycleState.resumed);

    _streamController.onListen = () {
      // web.document.addEventListener('visibilitychange', listenerFunc.toJS);
    };

    _streamController.onCancel = () {
      // web.document.removeEventListener('visibilitychange', listenerFunc.toJS);
    };
  }

  Stream<AppLifecycleState> get stream => _streamController.stream;

  void close() {
    _streamController.close();
  }
}
