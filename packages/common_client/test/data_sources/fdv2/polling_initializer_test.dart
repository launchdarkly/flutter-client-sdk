import 'dart:async';

import 'package:launchdarkly_common_client/src/data_sources/fdv2/payload.dart';
import 'package:launchdarkly_common_client/src/data_sources/fdv2/polling_initializer.dart';
import 'package:launchdarkly_common_client/src/data_sources/fdv2/selector.dart';
import 'package:launchdarkly_common_client/src/data_sources/fdv2/source_result.dart';
import 'package:launchdarkly_dart_common/launchdarkly_dart_common.dart';
import 'package:test/test.dart';

/// Builds a [PollFunction] that returns scripted results in order. Each
/// call shifts the head off the list. The function records the basis it
/// was invoked with for assertions.
class ScriptedPoll {
  final List<FDv2SourceResult> _results;
  final List<Selector> _basisSeen = [];

  ScriptedPoll(List<FDv2SourceResult> results) : _results = List.of(results);

  List<Selector> get basisSeen => List.unmodifiable(_basisSeen);

  Future<FDv2SourceResult> call({Selector basis = Selector.empty}) async {
    _basisSeen.add(basis);
    if (_results.isEmpty) {
      throw StateError('ScriptedPoll exhausted');
    }
    return _results.removeAt(0);
  }
}

/// A delay function that does nothing (instant). Tests that need to
/// observe close-during-delay behavior use [HoldingDelay] instead.
Future<void> instantDelay(Duration _) async {}

/// A delay function whose returned future never completes on its own.
/// Used to model "still waiting for retry" so the test can call close()
/// and observe the early termination.
class HoldingDelay {
  final _completer = Completer<void>();

  Future<void> call(Duration duration) => _completer.future;
}

ChangeSetResult _changeSet({String flagKey = 'k', int version = 1}) =>
    ChangeSetResult(
      payload: Payload(
        type: PayloadType.full,
        updates: [
          Update(
              kind: 'flag-eval',
              key: flagKey,
              version: version,
              object: const {})
        ],
      ),
      persist: true,
      freshness: DateTime.utc(2026, 1, 1),
    );

void main() {
  final logger = LDLogger(level: LDLogLevel.error);

  test('first poll succeeds returns ChangeSetResult immediately', () async {
    final poll = ScriptedPoll([_changeSet()]);
    final init = FDv2PollingInitializer(
      poll: poll.call,
      selectorGetter: () => Selector.empty,
      logger: logger,
      delay: instantDelay,
    );

    final result = await init.run();

    expect(result, isA<ChangeSetResult>());
    expect(poll.basisSeen, hasLength(1));
  });

  test('terminal status (terminalError) returns immediately, no retry',
      () async {
    final poll = ScriptedPoll([
      FDv2SourceResults.terminalError(message: 'forbidden', statusCode: 403)
    ]);
    final init = FDv2PollingInitializer(
      poll: poll.call,
      selectorGetter: () => Selector.empty,
      logger: logger,
      delay: instantDelay,
    );

    final result = await init.run();

    expect((result as StatusResult).state, equals(SourceState.terminalError));
    expect(poll.basisSeen, hasLength(1));
  });

  test('goodbye returns immediately, no retry', () async {
    final poll =
        ScriptedPoll([FDv2SourceResults.goodbyeResult(message: 'maintenance')]);
    final init = FDv2PollingInitializer(
      poll: poll.call,
      selectorGetter: () => Selector.empty,
      logger: logger,
      delay: instantDelay,
    );

    final result = await init.run();

    expect((result as StatusResult).state, equals(SourceState.goodbye));
    expect(poll.basisSeen, hasLength(1));
  });

  test('retries on interrupted up to 3 attempts then succeeds', () async {
    final poll = ScriptedPoll([
      FDv2SourceResults.interrupted(message: 'transient'),
      FDv2SourceResults.interrupted(message: 'transient'),
      _changeSet(flagKey: 'after-retries'),
    ]);
    final init = FDv2PollingInitializer(
      poll: poll.call,
      selectorGetter: () => Selector.empty,
      logger: logger,
      delay: instantDelay,
    );

    final result = await init.run();

    expect(result, isA<ChangeSetResult>());
    expect(poll.basisSeen, hasLength(3));
  });

  test(
      'all 3 attempts interrupted converts to terminalError carrying the '
      'last context', () async {
    final poll = ScriptedPoll([
      FDv2SourceResults.interrupted(message: 'first', statusCode: 503),
      FDv2SourceResults.interrupted(message: 'second', statusCode: 503),
      FDv2SourceResults.interrupted(
          message: 'third', statusCode: 503, fdv1Fallback: true),
    ]);
    final init = FDv2PollingInitializer(
      poll: poll.call,
      selectorGetter: () => Selector.empty,
      logger: logger,
      delay: instantDelay,
    );

    final result = await init.run();

    final status = result as StatusResult;
    expect(status.state, equals(SourceState.terminalError));
    expect(status.statusCode, equals(503));
    expect(status.fdv1Fallback, isTrue);
    expect(status.message, contains('third'));
    expect(poll.basisSeen, hasLength(3));
  });

  test('selector is read lazily before each poll', () async {
    var calls = 0;
    final selectors = [
      Selector.empty,
      Selector(state: 'sel-after-first', version: 1),
      Selector(state: 'sel-after-second', version: 2),
    ];
    final poll = ScriptedPoll([
      FDv2SourceResults.interrupted(message: 'a'),
      FDv2SourceResults.interrupted(message: 'b'),
      _changeSet(),
    ]);
    final init = FDv2PollingInitializer(
      poll: poll.call,
      selectorGetter: () => selectors[calls++],
      logger: logger,
      delay: instantDelay,
    );

    await init.run();

    expect(poll.basisSeen[0].isEmpty, isTrue);
    expect(poll.basisSeen[1].state, equals('sel-after-first'));
    expect(poll.basisSeen[2].state, equals('sel-after-second'));
  });

  test('close during retry delay returns shutdown status', () async {
    final holdingDelay = HoldingDelay();
    final poll = ScriptedPoll([
      FDv2SourceResults.interrupted(message: 'wait'),
      _changeSet(), // never reached
    ]);
    final init = FDv2PollingInitializer(
      poll: poll.call,
      selectorGetter: () => Selector.empty,
      logger: logger,
      delay: holdingDelay.call,
    );

    final runFuture = init.run();
    // Yield so the initializer reaches the retry delay.
    await Future<void>.delayed(Duration.zero);
    init.close();

    final result = await runFuture;
    expect((result as StatusResult).state, equals(SourceState.shutdown));
    // Only the first poll ran; the retry was aborted.
    expect(poll.basisSeen, hasLength(1));
  });

  test('close before run returns shutdown without polling', () async {
    final poll = ScriptedPoll([_changeSet()]);
    final init = FDv2PollingInitializer(
      poll: poll.call,
      selectorGetter: () => Selector.empty,
      logger: logger,
      delay: instantDelay,
    );
    init.close();

    final result = await init.run();
    expect((result as StatusResult).state, equals(SourceState.shutdown));
    expect(poll.basisSeen, isEmpty);
  });

  test('close is idempotent', () {
    final init = FDv2PollingInitializer(
      poll: ScriptedPoll([_changeSet()]).call,
      selectorGetter: () => Selector.empty,
      logger: logger,
      delay: instantDelay,
    );
    init.close();
    expect(() => init.close(), returnsNormally);
  });
}
