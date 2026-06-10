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

/// A timed condition observed alongside the active synchronizer's
/// results. When the condition fires, its [events] stream emits a
/// [ConditionType] that the orchestration loop uses to decide what to
/// do.
///
/// Conditions are streams rather than futures so a consumer can detach:
/// cancelling a stream subscription releases the consumer's listener,
/// whereas a listener on a never-completing future can never be
/// removed and would be retained for the condition's whole lifetime.
abstract interface class Condition {
  /// Single-subscription stream that emits at most one [ConditionType]
  /// when the condition fires and then closes. Closes without emitting
  /// if the condition is closed first.
  Stream<ConditionType> get events;

  /// Inform the condition about a synchronizer result. Some conditions
  /// use this to start or cancel their timers.
  void inform(FDv2SourceResult result);

  /// Cancel any pending timers and close [events]. Idempotent.
  void close();
}

final class _TimedCondition implements Condition {
  final Duration _timeout;
  final ConditionType _type;
  final void Function(FDv2SourceResult result,
      {required void Function() start,
      required void Function() cancel})? _informHandler;

  final StreamController<ConditionType> _controller =
      StreamController<ConditionType>();
  Timer? _timer;
  bool _closed = false;

  _TimedCondition({
    required Duration timeout,
    required ConditionType type,
    void Function(FDv2SourceResult result,
            {required void Function() start, required void Function() cancel})?
        informHandler,
  })  : _timeout = timeout,
        _type = type,
        _informHandler = informHandler {
    // Without an inform handler the timer starts immediately (recovery
    // behavior). With one, the handler decides when to start it.
    if (_informHandler == null) {
      _startTimer();
    }
  }

  void _startTimer() {
    if (_timer != null || _closed) return;
    _timer = Timer(_timeout, () {
      _timer = null;
      if (_closed) return;
      _closed = true;
      // The controller buffers the event if the subscription has not
      // started yet, so firing before listen is not lost.
      _controller.add(_type);
      _controller.close();
    });
  }

  void _cancelTimer() {
    _timer?.cancel();
    _timer = null;
  }

  @override
  Stream<ConditionType> get events => _controller.stream;

  @override
  void inform(FDv2SourceResult result) {
    if (_closed) return;
    _informHandler?.call(result, start: _startTimer, cancel: _cancelTimer);
  }

  @override
  void close() {
    if (_closed) return;
    _closed = true;
    _cancelTimer();
    _controller.close();
  }
}

/// Creates a fallback condition. The condition starts its timer when an
/// interrupted status is received and cancels it when a change set is
/// received. If the timer fires, the condition emits
/// [ConditionType.fallback].
Condition createFallbackCondition(Duration timeout) {
  return _TimedCondition(
    timeout: timeout,
    type: ConditionType.fallback,
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
/// condition emits [ConditionType.recovery] when it fires. Results do
/// not affect it.
Condition createRecoveryCondition(Duration timeout) {
  return _TimedCondition(
    timeout: timeout,
    type: ConditionType.recovery,
  );
}

/// A group of conditions managed together. The group merges the member
/// streams and broadcasts results to all of them.
final class ConditionGroup {
  final List<Condition> _conditions;
  final List<StreamSubscription<ConditionType>> _subscriptions = [];

  late final StreamController<ConditionType> _controller =
      StreamController<ConditionType>(onListen: _subscribe);
  bool _fired = false;
  bool _closed = false;

  ConditionGroup(List<Condition> conditions) : _conditions = conditions;

  /// Single-subscription stream that emits at most one [ConditionType]
  /// (the first member condition to fire) and then closes. Closes
  /// without emitting if the group is empty or closed first.
  Stream<ConditionType> get events => _controller.stream;

  void _subscribe() {
    if (_closed) return;
    if (_conditions.isEmpty) {
      _controller.close();
      return;
    }
    for (final condition in _conditions) {
      _subscriptions.add(condition.events.listen((type) {
        // First member to fire wins; member timers firing in the same
        // event-loop turn cannot produce a second emission.
        if (_fired || _closed) return;
        _fired = true;
        _controller.add(type);
        _finish();
      }));
    }
  }

  /// Broadcast a result to all conditions.
  void inform(FDv2SourceResult result) {
    for (final condition in _conditions) {
      condition.inform(result);
    }
  }

  /// Close all conditions and the merged stream. Idempotent.
  void close() {
    if (_closed) return;
    _finish();
  }

  void _finish() {
    _closed = true;
    for (final subscription in _subscriptions) {
      subscription.cancel();
    }
    _subscriptions.clear();
    for (final condition in _conditions) {
      condition.close();
    }
    if (!_controller.isClosed) {
      _controller.close();
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
}) {
  if (availableSynchronizerCount <= 1) {
    return ConditionGroup(const []);
  }

  if (isPrimary) {
    return ConditionGroup([createFallbackCondition(fallbackTimeout)]);
  }

  return ConditionGroup([
    createFallbackCondition(fallbackTimeout),
    createRecoveryCondition(recoveryTimeout),
  ]);
}
