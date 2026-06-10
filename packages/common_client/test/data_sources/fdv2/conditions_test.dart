import 'dart:async';

import 'package:launchdarkly_common_client/src/data_sources/fdv2/conditions.dart';
import 'package:launchdarkly_common_client/src/data_sources/fdv2/payload.dart';
import 'package:launchdarkly_common_client/src/data_sources/fdv2/source_result.dart';
import 'package:test/test.dart';

class FakeTimer implements Timer {
  final Duration duration;
  void Function()? _callback;

  FakeTimer(this.duration, this._callback);

  void fire() {
    final callback = _callback;
    _callback = null;
    callback?.call();
  }

  @override
  void cancel() {
    _callback = null;
  }

  @override
  bool get isActive => _callback != null;

  @override
  int get tick => 0;
}

class FakeTimerFactory {
  final List<FakeTimer> timers = [];

  Timer call(Duration duration, void Function() callback) {
    final timer = FakeTimer(duration, callback);
    timers.add(timer);
    return timer;
  }

  FakeTimer? get activeTimer {
    for (var i = timers.length - 1; i >= 0; i--) {
      if (timers[i].isActive) {
        return timers[i];
      }
    }
    return null;
  }
}

ChangeSetResult _changeSet() => const ChangeSetResult(
      payload: Payload(type: PayloadType.full, updates: []),
      persist: true,
    );

void main() {
  test('fallback condition starts its timer on interrupted and fires',
      () async {
    final timers = FakeTimerFactory();
    final condition = createFallbackCondition(const Duration(seconds: 120),
        timerFactory: timers.call);

    expect(timers.activeTimer, isNull,
        reason: 'the timer does not start until an interruption');

    condition.inform(FDv2SourceResults.interrupted(message: 'down'));
    expect(timers.activeTimer, isNotNull);
    expect(timers.activeTimer!.duration, const Duration(seconds: 120));

    var fired = false;
    unawaited(condition.future.then((type) {
      expect(type, ConditionType.fallback);
      fired = true;
    }));
    timers.activeTimer!.fire();
    await Future<void>.delayed(Duration.zero);
    expect(fired, isTrue);
  });

  test('fallback condition cancels its timer when data arrives', () {
    final timers = FakeTimerFactory();
    final condition = createFallbackCondition(const Duration(seconds: 120),
        timerFactory: timers.call);

    condition.inform(FDv2SourceResults.interrupted(message: 'down'));
    expect(timers.activeTimer, isNotNull);

    condition.inform(_changeSet());
    expect(timers.activeTimer, isNull);
  });

  test('recovery condition starts immediately and ignores results', () async {
    final timers = FakeTimerFactory();
    final condition = createRecoveryCondition(const Duration(seconds: 300),
        timerFactory: timers.call);

    expect(timers.activeTimer, isNotNull);
    condition.inform(_changeSet());
    expect(timers.activeTimer, isNotNull,
        reason: 'data does not cancel recovery');

    var fired = false;
    unawaited(condition.future.then((type) {
      expect(type, ConditionType.recovery);
      fired = true;
    }));
    timers.activeTimer!.fire();
    await Future<void>.delayed(Duration.zero);
    expect(fired, isTrue);
  });

  test('a closed condition never completes', () async {
    final timers = FakeTimerFactory();
    final condition = createRecoveryCondition(const Duration(seconds: 300),
        timerFactory: timers.call);

    condition.close();
    expect(timers.activeTimer, isNull);

    var fired = false;
    unawaited(condition.future.then((_) {
      fired = true;
    }));
    await Future<void>.delayed(Duration.zero);
    expect(fired, isFalse);
  });

  group('getConditions', () {
    test('no conditions with a single available synchronizer', () {
      final group = getConditions(
        availableSynchronizerCount: 1,
        isPrimary: true,
      );
      expect(group.future, isNull);
    });

    test('primary synchronizer gets only a fallback condition', () {
      final timers = FakeTimerFactory();
      final group = getConditions(
        availableSynchronizerCount: 2,
        isPrimary: true,
        timerFactory: timers.call,
      );
      expect(group.future, isNotNull);
      expect(timers.activeTimer, isNull,
          reason: 'a recovery condition would have started a timer');
    });

    test('non-primary synchronizer also gets a recovery condition', () {
      final timers = FakeTimerFactory();
      final group = getConditions(
        availableSynchronizerCount: 2,
        isPrimary: false,
        timerFactory: timers.call,
      );
      expect(group.future, isNotNull);
      expect(timers.activeTimer, isNotNull,
          reason: 'the recovery timer starts immediately');
    });
  });
}
