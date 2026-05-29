import 'dart:async';

import '../../fdv2_connection_mode.dart';

/// Snapshot of the desired state accumulated within a debounce window.
///
/// Each field is one of the axes that participate in debouncing per the
/// FDv2 connection-mode resolution spec: network availability, application
/// lifecycle, and the user-requested mode (when set via the public
/// `setMode` API). `identify` calls intentionally do not participate.
final class DebouncedState {
  final bool networkAvailable;
  final bool inForeground;
  final FDv2ConnectionMode? requestedMode;

  const DebouncedState({
    required this.networkAvailable,
    required this.inForeground,
    required this.requestedMode,
  });

  DebouncedState _copyWith({
    bool? networkAvailable,
    bool? inForeground,
    Object? requestedMode = _sentinel,
  }) {
    return DebouncedState(
      networkAvailable: networkAvailable ?? this.networkAvailable,
      inForeground: inForeground ?? this.inForeground,
      requestedMode: identical(requestedMode, _sentinel)
          ? this.requestedMode
          : requestedMode as FDv2ConnectionMode?,
    );
  }

  static const _sentinel = Object();
}

/// Callback fired when the debounce window closes with the final
/// accumulated [DebouncedState].
typedef OnDebounceReconcile = void Function(DebouncedState state);

/// Factory that produces a one-shot timer used to schedule the debounce
/// fire. Exists primarily so tests can substitute a controllable
/// implementation (e.g. via `fake_async`).
typedef DebounceTimerFactory = Timer Function(
    Duration duration, void Function() callback);

Timer _defaultTimerFactory(Duration d, void Function() cb) => Timer(d, cb);

/// Debounces network availability, lifecycle, and user-requested mode
/// signals into a single reconciliation callback, per CSFDV2 CONNMODE
/// section 3.5.
///
/// Each `setX` call updates the relevant component of the pending state
/// and resets the debounce timer. When the timer fires, [onReconcile] is
/// invoked with the final [DebouncedState]. Per-setter early-return
/// suppresses unchanged values; the consumer is responsible for deciding
/// whether the resolved state requires action.
///
/// A [debounceWindow] of [Duration.zero] bypasses the timer entirely:
/// state changes fire [onReconcile] synchronously. Useful for tests and
/// FDv1-style immediate-application paths.
final class StateDebounceManager {
  final Duration _debounceWindow;
  final OnDebounceReconcile _onReconcile;
  final DebounceTimerFactory _timerFactory;

  DebouncedState _pending;
  Timer? _timer;
  bool _closed = false;

  StateDebounceManager({
    required DebouncedState initialState,
    required Duration debounceWindow,
    required OnDebounceReconcile onReconcile,
    DebounceTimerFactory? timerFactory,
  })  : _pending = initialState,
        _debounceWindow = debounceWindow,
        _onReconcile = onReconcile,
        _timerFactory = timerFactory ?? _defaultTimerFactory;

  void setNetworkAvailable(bool available) {
    if (_pending.networkAvailable == available) {
      return;
    }
    _pending = _pending._copyWith(networkAvailable: available);
    _scheduleOrFire();
  }

  void setInForeground(bool inForeground) {
    if (_pending.inForeground == inForeground) {
      return;
    }
    _pending = _pending._copyWith(inForeground: inForeground);
    _scheduleOrFire();
  }

  void setRequestedMode(FDv2ConnectionMode? mode) {
    if (_pending.requestedMode == mode) {
      return;
    }
    _pending = _pending._copyWith(requestedMode: mode);
    _scheduleOrFire();
  }

  void close() {
    _closed = true;
    _timer?.cancel();
    _timer = null;
  }

  void _scheduleOrFire() {
    if (_closed) {
      return;
    }
    if (_debounceWindow == Duration.zero) {
      _onReconcile(_pending);
      return;
    }
    _timer?.cancel();
    _timer = _timerFactory(_debounceWindow, _onTimer);
  }

  void _onTimer() {
    _timer = null;
    if (_closed) {
      return;
    }
    _onReconcile(_pending);
  }
}
