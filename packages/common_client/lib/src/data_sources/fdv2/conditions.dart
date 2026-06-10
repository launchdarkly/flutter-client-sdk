import 'dart:async';

import 'source_result.dart';

/// Default time a synchronizer may remain interrupted before the
/// orchestrator falls back to the next available synchronizer.
const Duration defaultFallbackTimeout = Duration(seconds: 120);

/// Default time a non-primary synchronizer runs before the orchestrator
/// attempts to recover back to the primary synchronizer.
const Duration defaultRecoveryTimeout = Duration(seconds: 300);

/// The kind of condition that fired, determining the orchestrator's
/// response.
enum ConditionType {
  /// Move to the next available synchronizer.
  fallback,

  /// Reset to the primary synchronizer.
  recovery,
}

/// A timed condition raced against the active synchronizer's results.
/// When the condition fires, its [future] completes with a
/// [ConditionType] that the orchestration loop uses to decide what to do.
abstract interface class Condition {
  /// Completes when the condition fires. Never completes if the condition
  /// is closed first.
  Future<ConditionType> get future;

  /// Inform the condition about a synchronizer result. Some conditions
  /// use this to start or cancel their timers.
  void inform(FDv2SourceResult result);

  /// Cancel any pending timers. After closing, [future] never completes.
  void close();
}

/// Constructs a [Timer] that fires once after a duration. Tests inject a
/// fake to control time.
typedef ConditionTimerFactory = Timer Function(
    Duration duration, void Function() callback);

Timer _defaultTimerFactory(Duration duration, void Function() callback) =>
    Timer(duration, callback);

final class _TimedCondition implements Condition {
  final Duration _timeout;
  final ConditionType _type;
  final void Function(FDv2SourceResult result,
      {required void Function() start,
      required void Function() cancel})? _informHandler;
  final ConditionTimerFactory _timerFactory;

  final Completer<ConditionType> _completer = Completer<ConditionType>();
  Timer? _timer;
  bool _closed = false;

  _TimedCondition({
    required Duration timeout,
    required ConditionType type,
    void Function(FDv2SourceResult result,
            {required void Function() start, required void Function() cancel})?
        informHandler,
    ConditionTimerFactory? timerFactory,
  })  : _timeout = timeout,
        _type = type,
        _informHandler = informHandler,
        _timerFactory = timerFactory ?? _defaultTimerFactory {
    // Without an inform handler the timer starts immediately (recovery
    // behavior). With one, the handler decides when to start it.
    if (_informHandler == null) {
      _startTimer();
    }
  }

  void _startTimer() {
    if (_timer != null || _closed) return;
    _timer = _timerFactory(_timeout, () {
      _timer = null;
      if (!_closed && !_completer.isCompleted) {
        _completer.complete(_type);
      }
    });
  }

  void _cancelTimer() {
    _timer?.cancel();
    _timer = null;
  }

  @override
  Future<ConditionType> get future => _completer.future;

  @override
  void inform(FDv2SourceResult result) {
    if (_closed) return;
    _informHandler?.call(result, start: _startTimer, cancel: _cancelTimer);
  }

  @override
  void close() {
    _closed = true;
    _cancelTimer();
  }
}

/// Creates a fallback condition. The condition starts its timer when an
/// interrupted status is received and cancels it when a change set is
/// received. If the timer fires, the condition resolves with
/// [ConditionType.fallback].
Condition createFallbackCondition(Duration timeout,
    {ConditionTimerFactory? timerFactory}) {
  return _TimedCondition(
    timeout: timeout,
    type: ConditionType.fallback,
    timerFactory: timerFactory,
    informHandler: (result, {required start, required cancel}) {
      switch (result) {
        case ChangeSetResult():
          cancel();
        case StatusResult(state: SourceState.interrupted):
          start();
        case StatusResult():
          break;
      }
    },
  );
}

/// Creates a recovery condition. The timer starts immediately and the
/// condition resolves with [ConditionType.recovery] when it fires.
/// Results do not affect it.
Condition createRecoveryCondition(Duration timeout,
    {ConditionTimerFactory? timerFactory}) {
  return _TimedCondition(
    timeout: timeout,
    type: ConditionType.recovery,
    timerFactory: timerFactory,
  );
}

/// A group of conditions managed together. The group races all conditions
/// and broadcasts results to all of them.
final class ConditionGroup {
  final List<Condition> _conditions;

  ConditionGroup(this._conditions);

  /// Completes when the first condition fires. Null when the group is
  /// empty.
  Future<ConditionType>? get future =>
      _conditions.isEmpty ? null : Future.any(_conditions.map((c) => c.future));

  /// Broadcast a result to all conditions.
  void inform(FDv2SourceResult result) {
    for (final condition in _conditions) {
      condition.inform(result);
    }
  }

  /// Close all conditions.
  void close() {
    for (final condition in _conditions) {
      condition.close();
    }
  }
}

/// Determines which conditions apply to the active synchronizer.
///
/// - With at most one available synchronizer there is nowhere to fall
///   back to, so no conditions are created.
/// - The primary (first available) synchronizer gets only a fallback
///   condition.
/// - A non-primary synchronizer gets both fallback and recovery
///   conditions.
ConditionGroup getConditions({
  required int availableSynchronizerCount,
  required bool isPrimary,
  Duration fallbackTimeout = defaultFallbackTimeout,
  Duration recoveryTimeout = defaultRecoveryTimeout,
  ConditionTimerFactory? timerFactory,
}) {
  if (availableSynchronizerCount <= 1) {
    return ConditionGroup(const []);
  }

  if (isPrimary) {
    return ConditionGroup(
        [createFallbackCondition(fallbackTimeout, timerFactory: timerFactory)]);
  }

  return ConditionGroup([
    createFallbackCondition(fallbackTimeout, timerFactory: timerFactory),
    createRecoveryCondition(recoveryTimeout, timerFactory: timerFactory),
  ]);
}
