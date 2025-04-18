import 'dart:async';
// ignore: deprecated_member_use
import 'dart:html' as html;

import 'package:flutter/widgets.dart';

/// Lifecycle listener that uses the underlying visibility of the html web
/// document to emit events.
class LDAppLifecycleListener {
  late final StreamController<AppLifecycleState> _streamController;

  LDAppLifecycleListener() {
    _streamController = StreamController.broadcast();

    void listenerFunc(event) =>
        _streamController.add(html.document.hidden == true
            ? AppLifecycleState.hidden
            : AppLifecycleState.resumed);

    _streamController.onListen = () {
      html.document.addEventListener('visibilitychange', listenerFunc);
    };

    _streamController.onCancel = () {
      html.document.removeEventListener('visibilitychange', listenerFunc);
    };
  }

  Stream<AppLifecycleState> get stream => _streamController.stream;

  void close() {
    _streamController.close();
  }
}
