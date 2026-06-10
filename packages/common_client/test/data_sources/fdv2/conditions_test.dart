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
  test('fallback condition starts its timer on interrupted and emits',
      () async {
    final timers = FakeTimerFactory();
    final condition = createFallbackCondition(const Duration(seconds: 120),
        timerFactory: timers.call);
    final emissions = <ConditionType>[];
    condition.events.listen(emissions.add);

    expect(timers.activeTimer, isNull,
        reason: 'the timer does not start until an interruption');

    condition.inform(FDv2SourceResults.interrupted(message: 'down'));
    expect(timers.activeTimer, isNotNull);
    expect(timers.activeTimer!.duration, const Duration(seconds: 120));

    timers.activeTimer!.fire();
    await Future<void>.delayed(Duration.zero);
    expect(emissions, equals([ConditionType.fallback]));
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
    final emissions = <ConditionType>[];
    condition.events.listen(emissions.add);

    expect(timers.activeTimer, isNotNull);
    condition.inform(_changeSet());
    expect(timers.activeTimer, isNotNull,
        reason: 'data does not cancel recovery');

    timers.activeTimer!.fire();
    await Future<void>.delayed(Duration.zero);
    expect(emissions, equals([ConditionType.recovery]));
  });

  test('a fired condition emits exactly once and closes its stream', () async {
    final timers = FakeTimerFactory();
    final condition = createFallbackCondition(const Duration(seconds: 120),
        timerFactory: timers.call);

    final expectation = expectLater(
        condition.events, emitsInOrder([ConditionType.fallback, emitsDone]));

    condition.inform(FDv2SourceResults.interrupted(message: 'down'));
    timers.activeTimer!.fire();
    // After firing, further informs cannot re-arm the timer.
    condition.inform(FDv2SourceResults.interrupted(message: 'down again'));
    expect(timers.activeTimer, isNull);

    await expectation;
  });

  test('a closed condition closes its stream without emitting', () async {
    final timers = FakeTimerFactory();
    final condition = createRecoveryCondition(const Duration(seconds: 300),
        timerFactory: timers.call);

    final expectation = expectLater(condition.events, emitsDone);
    condition.close();
    expect(timers.activeTimer, isNull);
    await expectation;
  });

  test('cancelling a subscription detaches the consumer', () async {
    final timers = FakeTimerFactory();
    final condition = createRecoveryCondition(const Duration(seconds: 300),
        timerFactory: timers.call);
    final emissions = <ConditionType>[];

    final subscription = condition.events.listen(emissions.add);
    await subscription.cancel();

    timers.activeTimer?.fire();
    await Future<void>.delayed(Duration.zero);
    expect(emissions, isEmpty);
    condition.close();
  });

  group('ConditionGroup', () {
    test('emits the first member condition to fire, then closes', () async {
      final timers = FakeTimerFactory();
      final fallback = createFallbackCondition(const Duration(seconds: 120),
          timerFactory: timers.call);
      final recovery = createRecoveryCondition(const Duration(seconds: 300),
          timerFactory: timers.call);
      final group = ConditionGroup([fallback, recovery]);

      final expectation = expectLater(
          group.events, emitsInOrder([ConditionType.recovery, emitsDone]));

      // Only the recovery timer is running; fire it.
      timers.activeTimer!.fire();
      await expectation;
    });

    test('inform reaches every member condition', () {
      final timers = FakeTimerFactory();
      final fallback = createFallbackCondition(const Duration(seconds: 120),
          timerFactory: timers.call);
      final group = ConditionGroup([fallback]);

      expect(timers.activeTimer, isNull);
      group.inform(FDv2SourceResults.interrupted(message: 'down'));
      expect(timers.activeTimer, isNotNull);
      group.close();
    });

    test('an empty group closes without emitting', () async {
      final group = ConditionGroup(const []);
      await expectLater(group.events, emitsDone);
    });

    test('close closes the members and the merged stream without emitting',
        () async {
      final timers = FakeTimerFactory();
      final recovery = createRecoveryCondition(const Duration(seconds: 300),
          timerFactory: timers.call);
      final group = ConditionGroup([recovery]);

      final expectation = expectLater(group.events, emitsDone);
      group.close();
      expect(timers.activeTimer, isNull,
          reason: 'closing the group cancels member timers');
      await expectation;
    });
  });

  group('getConditions', () {
    test('no conditions with a single available synchronizer', () async {
      final group = getConditions(
        availableSynchronizerCount: 1,
        isPrimary: true,
      );
      await expectLater(group.events, emitsDone);
    });

    test('primary synchronizer gets only a fallback condition', () {
      final timers = FakeTimerFactory();
      final group = getConditions(
        availableSynchronizerCount: 2,
        isPrimary: true,
        timerFactory: timers.call,
      );
      group.events.listen((_) {});
      expect(timers.activeTimer, isNull,
          reason: 'a recovery condition would have started a timer');
      group.close();
    });

    test('non-primary synchronizer also gets a recovery condition', () {
      final timers = FakeTimerFactory();
      final group = getConditions(
        availableSynchronizerCount: 2,
        isPrimary: false,
        timerFactory: timers.call,
      );
      group.events.listen((_) {});
      expect(timers.activeTimer, isNotNull,
          reason: 'the recovery timer starts immediately');
      group.close();
    });
  });
}
