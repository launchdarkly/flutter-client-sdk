import 'dart:async';

import 'package:launchdarkly_common_client/src/data_sources/fdv2/payload.dart';
import 'package:launchdarkly_common_client/src/data_sources/fdv2/polling_synchronizer.dart';
import 'package:launchdarkly_common_client/src/data_sources/fdv2/selector.dart';
import 'package:launchdarkly_common_client/src/data_sources/fdv2/source_result.dart';
import 'package:launchdarkly_dart_common/launchdarkly_dart_common.dart';
import 'package:test/test.dart';

class ScriptedPoll {
  final List<FDv2SourceResult> _results;
  final List<Selector> basisSeen = [];

  ScriptedPoll(List<FDv2SourceResult> results) : _results = List.of(results);

  int get callCount => basisSeen.length;

  Future<FDv2SourceResult> call({Selector basis = Selector.empty}) async {
    basisSeen.add(basis);
    if (_results.isEmpty) {
      // Don't throw -- a test may not predict exactly how many polls
      // fire before tearing down. Emit a benign interrupted instead.
      return FDv2SourceResults.interrupted(message: 'no more scripted');
    }
    return _results.removeAt(0);
  }
}

/// A timer factory that records each requested delay and lets the test
/// trigger the callback on demand. Cancellation marks the timer
/// inactive but the request stays in the history list, so tests can
/// still inspect what was originally scheduled.
class FakeTimerFactory {
  final List<FakeTimer> timers = [];

  Timer call(Duration duration, void Function() callback) {
    final t = FakeTimer(duration, callback);
    timers.add(t);
    return t;
  }

  /// Fires the most recently scheduled active timer.
  void fireLatest() {
    for (var i = timers.length - 1; i >= 0; i--) {
      if (timers[i].isActive) {
        timers[i].fire();
        return;
      }
    }
    fail('no active timer to fire');
  }

  /// The duration of the most recent scheduling request, regardless of
  /// whether it has since been cancelled.
  Duration? get latestRequestedDelay =>
      timers.isEmpty ? null : timers.last.duration;
}

class FakeTimer implements Timer {
  final Duration duration;
  final void Function() _callback;
  bool _cancelled = false;
  bool _fired = false;

  FakeTimer(this.duration, this._callback);

  void fire() {
    if (_cancelled || _fired) return;
    _fired = true;
    _callback();
  }

  @override
  void cancel() {
    _cancelled = true;
  }

  @override
  bool get isActive => !_cancelled && !_fired;

  @override
  int get tick => 0;
}

ChangeSetResult _changeSet({DateTime? freshness, String? selectorState}) =>
    ChangeSetResult(
      payload: Payload(
        type: PayloadType.full,
        selector: selectorState != null
            ? Selector(state: selectorState, version: 1)
            : Selector.empty,
        updates: const [],
      ),
      persist: true,
      freshness: freshness ?? DateTime.utc(2026, 1, 1),
    );

void main() {
  final logger = LDLogger(level: LDLogLevel.error);
  const interval = Duration(seconds: 30);

  test('polls immediately on subscribe and emits the result', () async {
    final poll = ScriptedPoll([_changeSet()]);
    final timerFactory = FakeTimerFactory();
    final sync = FDv2PollingSynchronizer(
      poll: poll.call,
      selectorGetter: () => Selector.empty,
      interval: interval,
      logger: logger,
      timerFactory: timerFactory.call,
    );

    final emissions = <FDv2SourceResult>[];
    final sub = sync.results.listen(emissions.add);
    await Future<void>.delayed(Duration.zero);

    expect(emissions, hasLength(1));
    expect(emissions[0], isA<ChangeSetResult>());
    expect(poll.callCount, equals(1));

    await sub.cancel();
    sync.close();
  });

  test('schedules the next poll using the freshness of the last result',
      () async {
    final freshness = DateTime.utc(2026, 1, 1, 12, 0, 0);
    final now = DateTime.utc(2026, 1, 1, 12, 0, 10); // 10s after freshness
    final poll = ScriptedPoll([_changeSet(freshness: freshness)]);
    final timerFactory = FakeTimerFactory();

    final sync = FDv2PollingSynchronizer(
      poll: poll.call,
      selectorGetter: () => Selector.empty,
      interval: interval,
      logger: logger,
      timerFactory: timerFactory.call,
      now: () => now,
    );

    final sub = sync.results.listen((_) {});
    await Future<void>.delayed(Duration.zero);

    expect(
        timerFactory.latestRequestedDelay, equals(const Duration(seconds: 20)));

    await sub.cancel();
    sync.close();
  });

  test('subsequent timer fire triggers another poll and another emission',
      () async {
    final poll = ScriptedPoll([
      _changeSet(selectorState: 'first'),
      _changeSet(selectorState: 'second'),
    ]);
    final timerFactory = FakeTimerFactory();

    final sync = FDv2PollingSynchronizer(
      poll: poll.call,
      selectorGetter: () => Selector.empty,
      interval: interval,
      logger: logger,
      timerFactory: timerFactory.call,
    );

    final emissions = <FDv2SourceResult>[];
    final sub = sync.results.listen(emissions.add);

    await Future<void>.delayed(Duration.zero);
    expect(emissions, hasLength(1));

    timerFactory.fireLatest();
    await Future<void>.delayed(Duration.zero);

    expect(emissions, hasLength(2));
    expect(
      (emissions[1] as ChangeSetResult).payload.selector.state,
      equals('second'),
    );

    await sub.cancel();
    sync.close();
  });

  test('interrupted result is emitted but does not advance freshness',
      () async {
    final freshness = DateTime.utc(2026, 1, 1, 12, 0, 0);
    var nowCallCount = 0;
    final nows = [
      DateTime.utc(2026, 1, 1, 12, 0, 5), // after first poll
      DateTime.utc(2026, 1, 1, 12, 0, 5), // after second poll (interrupted)
    ];
    final poll = ScriptedPoll([
      _changeSet(freshness: freshness),
      FDv2SourceResults.interrupted(message: 'transient'),
    ]);
    final timerFactory = FakeTimerFactory();

    final sync = FDv2PollingSynchronizer(
      poll: poll.call,
      selectorGetter: () => Selector.empty,
      interval: interval,
      logger: logger,
      timerFactory: timerFactory.call,
      now: () => nows[nowCallCount++],
    );

    final emissions = <FDv2SourceResult>[];
    final sub = sync.results.listen(emissions.add);
    await Future<void>.delayed(Duration.zero);

    expect(emissions, hasLength(1));
    expect(
        timerFactory.latestRequestedDelay, equals(const Duration(seconds: 25)));

    timerFactory.fireLatest();
    await Future<void>.delayed(Duration.zero);

    expect(emissions, hasLength(2));
    expect(emissions[1], isA<StatusResult>());
    // Freshness was NOT updated by the interrupted result -- the next
    // delay is still computed against the original freshness.
    expect(
        timerFactory.latestRequestedDelay, equals(const Duration(seconds: 25)));

    await sub.cancel();
    sync.close();
  });

  test('selector is read lazily before each poll', () async {
    final selectors = [
      Selector.empty,
      Selector(state: 'second-basis', version: 1),
    ];
    var idx = 0;
    final poll = ScriptedPoll([_changeSet(), _changeSet()]);
    final timerFactory = FakeTimerFactory();

    final sync = FDv2PollingSynchronizer(
      poll: poll.call,
      selectorGetter: () => selectors[idx++],
      interval: interval,
      logger: logger,
      timerFactory: timerFactory.call,
    );

    final sub = sync.results.listen((_) {});
    await Future<void>.delayed(Duration.zero);
    timerFactory.fireLatest();
    await Future<void>.delayed(Duration.zero);

    expect(poll.basisSeen[0].isEmpty, isTrue);
    expect(poll.basisSeen[1].state, equals('second-basis'));

    await sub.cancel();
    sync.close();
  });

  test('close cancels the pending timer and emits shutdown then closes',
      () async {
    final poll = ScriptedPoll([_changeSet()]);
    final timerFactory = FakeTimerFactory();
    final sync = FDv2PollingSynchronizer(
      poll: poll.call,
      selectorGetter: () => Selector.empty,
      interval: interval,
      logger: logger,
      timerFactory: timerFactory.call,
    );

    final emissions = <FDv2SourceResult>[];
    final doneCompleter = Completer<void>();
    sync.results.listen(emissions.add, onDone: doneCompleter.complete);

    await Future<void>.delayed(Duration.zero);
    expect(emissions, hasLength(1));

    sync.close();
    await doneCompleter.future;

    expect(emissions, hasLength(2));
    expect((emissions[1] as StatusResult).state, equals(SourceState.shutdown));
    expect(timerFactory.timers.last.isActive, isFalse);
  });

  test('subscription cancel stops polling without emitting shutdown', () async {
    final poll = ScriptedPoll([_changeSet(), _changeSet(), _changeSet()]);
    final timerFactory = FakeTimerFactory();
    final sync = FDv2PollingSynchronizer(
      poll: poll.call,
      selectorGetter: () => Selector.empty,
      interval: interval,
      logger: logger,
      timerFactory: timerFactory.call,
    );

    final emissions = <FDv2SourceResult>[];
    final sub = sync.results.listen(emissions.add);
    await Future<void>.delayed(Duration.zero);
    expect(emissions, hasLength(1));

    await sub.cancel();
    final pollsBeforeFire = poll.callCount;
    if (timerFactory.latestRequestedDelay != null &&
        timerFactory.timers.last.isActive) {
      timerFactory.fireLatest();
      await Future<void>.delayed(Duration.zero);
    }
    expect(poll.callCount, equals(pollsBeforeFire));
  });

  test('close is idempotent', () {
    final sync = FDv2PollingSynchronizer(
      poll: ScriptedPoll([_changeSet()]).call,
      selectorGetter: () => Selector.empty,
      interval: interval,
      logger: logger,
      timerFactory: FakeTimerFactory().call,
    );
    sync.close();
    expect(() => sync.close(), returnsNormally);
  });
}
