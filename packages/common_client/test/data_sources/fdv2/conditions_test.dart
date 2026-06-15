import 'package:fake_async/fake_async.dart';
import 'package:launchdarkly_common_client/src/data_sources/fdv2/conditions.dart';
import 'package:launchdarkly_common_client/src/data_sources/fdv2/payload.dart';
import 'package:launchdarkly_common_client/src/data_sources/fdv2/source_result.dart';
import 'package:test/test.dart';

ChangeSetResult _changeSet() => const ChangeSetResult(
      changeSet: ChangeSet(type: PayloadType.full, updates: {}),
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

  test('fallback condition re-arms for an interruption after a cancel', () {
    fakeAsync((async) {
      final condition = createFallbackCondition(const Duration(seconds: 120));
      final emissions = <ConditionType>[];
      condition.events.listen(emissions.add);

      condition.inform(FDv2SourceResults.interrupted(message: 'down'));
      condition.inform(_changeSet());
      expect(async.pendingTimers, isEmpty);

      // A fresh interruption begins a new fallback period.
      condition.inform(FDv2SourceResults.interrupted(message: 'down again'));
      expect(async.pendingTimers, hasLength(1));

      async.elapse(const Duration(seconds: 120));
      expect(emissions, [ConditionType.fallback]);
    });
  });

  test('recovery condition starts when listened to and ignores results', () {
    fakeAsync((async) {
      final condition = createRecoveryCondition(const Duration(seconds: 300));
      final emissions = <ConditionType>[];

      expect(async.pendingTimers, isEmpty,
          reason: 'the recovery clock starts when the condition is observed');
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

  test('cancelling a subscription closes the condition and its timer', () {
    fakeAsync((async) {
      final condition = createRecoveryCondition(const Duration(seconds: 300));
      final emissions = <ConditionType>[];

      final subscription = condition.events.listen(emissions.add);
      expect(async.pendingTimers, hasLength(1));

      subscription.cancel();
      async.flushMicrotasks();
      expect(async.pendingTimers, isEmpty,
          reason: 'the condition lifetime is scoped to the subscription');

      async.elapse(const Duration(seconds: 300));
      expect(emissions, isEmpty);
    });
  });

  test('terminal statuses do not arm the fallback timer', () {
    fakeAsync((async) {
      final condition = createFallbackCondition(const Duration(seconds: 120));
      condition.events.listen((_) {});

      condition.inform(FDv2SourceResults.terminalError(message: 'denied'));
      condition.inform(FDv2SourceResults.shutdown(message: 'closed'));
      condition.inform(FDv2SourceResults.goodbyeResult(message: 'bye'));

      expect(async.pendingTimers, isEmpty,
          reason: 'the orchestrator reacts to terminal statuses '
              'immediately rather than waiting out a fallback period');
      condition.close();
    });
  });

  test('a second interruption does not extend the fallback deadline', () {
    fakeAsync((async) {
      final condition = createFallbackCondition(const Duration(seconds: 120));
      final emissions = <ConditionType>[];
      condition.events.listen(emissions.add);

      condition.inform(FDv2SourceResults.interrupted(message: 'down'));
      async.elapse(const Duration(seconds: 60));
      condition.inform(FDv2SourceResults.interrupted(message: 'still down'));
      async.elapse(const Duration(seconds: 60));

      expect(emissions, equals([ConditionType.fallback]),
          reason: 'the fallback period counts from the first interruption');
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

    test('emits exactly once when two member timers contend', () {
      fakeAsync((async) {
        final group = ConditionGroup([
          createFallbackCondition(const Duration(seconds: 120)),
          createRecoveryCondition(const Duration(seconds: 120)),
        ]);
        final emissions = <ConditionType>[];
        var done = false;
        group.events.listen(emissions.add, onDone: () => done = true);

        // Arm the fallback timer so both members are due at the same
        // instant.
        group.inform(FDv2SourceResults.interrupted(message: 'down'));
        expect(async.pendingTimers, hasLength(2));

        async.elapse(const Duration(seconds: 120));
        expect(emissions, hasLength(1),
            reason: 'the first member to fire wins; the loser must not '
                'produce a second emission');
        expect(done, isTrue);
      });
    });

    test('cancelling the subscription closes the group and member timers', () {
      fakeAsync((async) {
        final group = ConditionGroup([
          createFallbackCondition(const Duration(seconds: 120)),
          createRecoveryCondition(const Duration(seconds: 300)),
        ]);
        final emissions = <ConditionType>[];
        final subscription = group.events.listen(emissions.add);
        group.inform(FDv2SourceResults.interrupted(message: 'down'));
        expect(async.pendingTimers, hasLength(2));

        subscription.cancel();
        async.flushMicrotasks();
        expect(async.pendingTimers, isEmpty,
            reason: 'the group lifetime is scoped to the subscription');

        group.inform(FDv2SourceResults.interrupted(message: 'down again'));
        expect(async.pendingTimers, isEmpty,
            reason: 'a closed group does not forward informs');

        async.elapse(const Duration(seconds: 300));
        expect(emissions, isEmpty);
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

    test('an empty group never emits and closes when closed', () {
      fakeAsync((async) {
        final group = ConditionGroup(const []);
        final emissions = <ConditionType>[];
        var done = false;
        group.events.listen(emissions.add, onDone: () => done = true);

        group.inform(FDv2SourceResults.interrupted(message: 'down'));
        async.flushMicrotasks();
        expect(async.pendingTimers, isEmpty);
        expect(emissions, isEmpty);
        expect(done, isFalse,
            reason: 'no member conditions exist, so nothing can fire and '
                'the stream stays open until the group is closed');

        group.close();
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
        final emissions = <ConditionType>[];
        group.events.listen(emissions.add);

        group.inform(FDv2SourceResults.interrupted(message: 'down'));
        async.elapse(const Duration(hours: 1));
        expect(async.pendingTimers, isEmpty,
            reason: 'there is nowhere to fall back to, so no timers arm');
        expect(emissions, isEmpty);
        group.close();
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
