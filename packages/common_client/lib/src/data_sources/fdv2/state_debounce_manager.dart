import 'dart:async';

import 'package:launchdarkly_dart_common/launchdarkly_dart_common.dart'
    show LDLogger;

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

  static const _unset = Object();

  const DebouncedState({
    required this.networkAvailable,
    required this.inForeground,
    required this.requestedMode,
  });

  DebouncedState _copyWith({
    bool? networkAvailable,
    bool? inForeground,
    Object? requestedMode = _unset,
  }) {
    return DebouncedState(
      networkAvailable: networkAvailable ?? this.networkAvailable,
      inForeground: inForeground ?? this.inForeground,
      requestedMode: identical(requestedMode, _unset)
          ? this.requestedMode
          : requestedMode as FDv2ConnectionMode?,
    );
  }
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
/// signals into a single reconciliation callback.
///
/// Each `setX` call updates the relevant component of the pending state
/// and resets the debounce timer. When the timer fires, [onReconcile] is
/// invoked with the final [DebouncedState]. Per-setter early-return
/// suppresses unchanged values; the consumer is responsible for deciding
/// whether the resolved state requires action.
///
/// A [debounceWindow] of [Duration.zero] bypasses the timer entirely:
/// state changes fire [onReconcile] synchronously inside the setter that
/// produced them. With this configuration, [onReconcile] must not call
/// back into any [StateDebounceManager] setter on the same instance --
/// doing so would recurse into [_scheduleOrFire] before the outer call
/// returns. Intended for tests and FDv1-style immediate-application paths.
///
/// Exceptions thrown from [onReconcile] are caught and (when [logger] is
/// supplied) logged at error level. The [DebouncedState] that was about to
/// be delivered is retained as the new baseline -- subsequent setter calls
/// dedupe against it as if the reconcile had succeeded.
final class StateDebounceManager {
  final Duration _debounceWindow;
  final OnDebounceReconcile _onReconcile;
  final DebounceTimerFactory _timerFactory;
  final LDLogger? _logger;

  DebouncedState _pending;
  Timer? _timer;
  bool _closed = false;

  StateDebounceManager({
    required DebouncedState initialState,
    required Duration debounceWindow,
    required OnDebounceReconcile onReconcile,
    DebounceTimerFactory? timerFactory,
    LDLogger? logger,
  })  : _pending = initialState,
        _debounceWindow = debounceWindow,
        _onReconcile = onReconcile,
        _timerFactory = timerFactory ?? _defaultTimerFactory,
        _logger = logger;

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
      _invokeReconcile();
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
    _invokeReconcile();
  }

  void _invokeReconcile() {
    try {
      _onReconcile(_pending);
    } catch (error, stackTrace) {
      _logger?.error(
          'State debounce reconcile callback threw: $error\n$stackTrace');
    }
  }
}
