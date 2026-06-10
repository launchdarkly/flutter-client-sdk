import 'package:fake_async/fake_async.dart';
import 'package:launchdarkly_common_client/src/data_sources/fdv2/conditions.dart';
import 'package:launchdarkly_common_client/src/data_sources/fdv2/payload.dart';
import 'package:launchdarkly_common_client/src/data_sources/fdv2/source_result.dart';
import 'package:test/test.dart';

ChangeSetResult _changeSet() => const ChangeSetResult(
      payload: Payload(type: PayloadType.full, updates: []),
      persist: true,
    );

void main() {
  test('fallback condition starts its timer on interrupted and emits', () {
    fakeAsync((async) {
      final condition = createFallbackCondition(const Duration(seconds: 120));
      final emissions = <ConditionType>[];
      condition.events.listen(emissions.add);

      expect(async.pendingTimers, isEmpty,
          reason: 'the timer does not start until an interruption');

      condition.inform(FDv2SourceResults.interrupted(message: 'down'));
      expect(async.pendingTimers, hasLength(1));
      expect(async.pendingTimers.single.duration, const Duration(seconds: 120));

      async.elapse(const Duration(seconds: 120));
      expect(emissions, equals([ConditionType.fallback]));
    });
  });

  test('fallback condition cancels its timer when data arrives', () {
    fakeAsync((async) {
      final condition = createFallbackCondition(const Duration(seconds: 120));
      final emissions = <ConditionType>[];
      condition.events.listen(emissions.add);

      condition.inform(FDv2SourceResults.interrupted(message: 'down'));
      expect(async.pendingTimers, hasLength(1));

      condition.inform(_changeSet());
      expect(async.pendingTimers, isEmpty);

      async.elapse(const Duration(seconds: 300));
      expect(emissions, isEmpty);
    });
  });

  test('recovery condition starts immediately and ignores results', () {
    fakeAsync((async) {
      final condition = createRecoveryCondition(const Duration(seconds: 300));
      final emissions = <ConditionType>[];
      condition.events.listen(emissions.add);

      expect(async.pendingTimers, hasLength(1));
      condition.inform(_changeSet());
      expect(async.pendingTimers, hasLength(1),
          reason: 'data does not cancel recovery');

      async.elapse(const Duration(seconds: 300));
      expect(emissions, equals([ConditionType.recovery]));
    });
  });

  test('a fired condition emits exactly once and closes its stream', () {
    fakeAsync((async) {
      final condition = createFallbackCondition(const Duration(seconds: 120));
      final emissions = <ConditionType>[];
      var done = false;
      condition.events.listen(emissions.add, onDone: () => done = true);

      condition.inform(FDv2SourceResults.interrupted(message: 'down'));
      async.elapse(const Duration(seconds: 120));

      // After firing, further informs cannot re-arm the timer.
      condition.inform(FDv2SourceResults.interrupted(message: 'down again'));
      expect(async.pendingTimers, isEmpty);

      async.flushMicrotasks();
      expect(emissions, equals([ConditionType.fallback]));
      expect(done, isTrue);
    });
  });

  test('a closed condition closes its stream without emitting', () {
    fakeAsync((async) {
      final condition = createRecoveryCondition(const Duration(seconds: 300));
      final emissions = <ConditionType>[];
      var done = false;
      condition.events.listen(emissions.add, onDone: () => done = true);

      condition.close();
      expect(async.pendingTimers, isEmpty);

      async.elapse(const Duration(seconds: 300));
      expect(emissions, isEmpty);
      expect(done, isTrue);
    });
  });

  test('cancelling a subscription detaches the consumer', () {
    fakeAsync((async) {
      final condition = createRecoveryCondition(const Duration(seconds: 300));
      final emissions = <ConditionType>[];

      final subscription = condition.events.listen(emissions.add);
      subscription.cancel();

      async.elapse(const Duration(seconds: 300));
      expect(emissions, isEmpty);
      condition.close();
    });
  });

  group('ConditionGroup', () {
    test('emits the first member condition to fire, then closes', () {
      fakeAsync((async) {
        final group = ConditionGroup([
          createFallbackCondition(const Duration(seconds: 120)),
          createRecoveryCondition(const Duration(seconds: 300)),
        ]);
        final emissions = <ConditionType>[];
        var done = false;
        group.events.listen(emissions.add, onDone: () => done = true);

        // Only the recovery timer is running; fire it.
        async.elapse(const Duration(seconds: 300));
        expect(emissions, equals([ConditionType.recovery]));
        expect(done, isTrue);
      });
    });

    test('inform reaches every member condition', () {
      fakeAsync((async) {
        final group = ConditionGroup(
            [createFallbackCondition(const Duration(seconds: 120))]);
        group.events.listen((_) {});

        expect(async.pendingTimers, isEmpty);
        group.inform(FDv2SourceResults.interrupted(message: 'down'));
        expect(async.pendingTimers, hasLength(1));
        group.close();
      });
    });

    test('an empty group closes without emitting', () {
      fakeAsync((async) {
        final group = ConditionGroup(const []);
        final emissions = <ConditionType>[];
        var done = false;
        group.events.listen(emissions.add, onDone: () => done = true);

        async.flushMicrotasks();
        expect(emissions, isEmpty);
        expect(done, isTrue);
      });
    });

    test('close closes the members and the merged stream without emitting', () {
      fakeAsync((async) {
        final group = ConditionGroup(
            [createRecoveryCondition(const Duration(seconds: 300))]);
        final emissions = <ConditionType>[];
        var done = false;
        group.events.listen(emissions.add, onDone: () => done = true);

        group.close();
        expect(async.pendingTimers, isEmpty,
            reason: 'closing the group cancels member timers');

        async.elapse(const Duration(seconds: 300));
        expect(emissions, isEmpty);
        expect(done, isTrue);
      });
    });
  });

  group('getConditions', () {
    test('no conditions with a single available synchronizer', () {
      fakeAsync((async) {
        final group = getConditions(
          availableSynchronizerCount: 1,
          isPrimary: true,
        );
        var done = false;
        group.events.listen((_) {}, onDone: () => done = true);

        async.flushMicrotasks();
        expect(done, isTrue);
      });
    });

    test('primary synchronizer gets only a fallback condition', () {
      fakeAsync((async) {
        final group = getConditions(
          availableSynchronizerCount: 2,
          isPrimary: true,
        );
        group.events.listen((_) {});

        expect(async.pendingTimers, isEmpty,
            reason: 'a recovery condition would have started a timer');
        group.close();
      });
    });

    test('non-primary synchronizer also gets a recovery condition', () {
      fakeAsync((async) {
        final group = getConditions(
          availableSynchronizerCount: 2,
          isPrimary: false,
        );
        final emissions = <ConditionType>[];
        group.events.listen(emissions.add);

        expect(async.pendingTimers, hasLength(1),
            reason: 'the recovery timer starts immediately');
        async.elapse(const Duration(seconds: 300));
        expect(emissions, equals([ConditionType.recovery]));
      });
    });
  });
}
