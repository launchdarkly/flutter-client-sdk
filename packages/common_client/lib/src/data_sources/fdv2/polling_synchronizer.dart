import 'dart:async';

import 'package:launchdarkly_dart_common/launchdarkly_dart_common.dart';

import 'calculate_poll_delay.dart';
import 'polling_initializer.dart' show PollFunction;
import 'source.dart';
import 'source_result.dart';

/// Constructs a [Timer] that fires once after [duration] and invokes
/// [callback]. Tests inject a fake to control time.
typedef TimerFactory = Timer Function(
    Duration duration, void Function() callback);

Timer _defaultTimerFactory(Duration duration, void Function() callback) =>
    Timer(duration, callback);

/// Long-lived polling synchronizer.
///
/// Exposes a single-subscription [Stream] of [FDv2SourceResult]s. On
/// subscription, polls immediately and then schedules the next poll
/// using [calculatePollDelay] over the freshness of the most recent
/// successful result. Cancelling the subscription (or calling [close])
/// stops the timer and closes the stream.
///
/// Each emission carries whatever the underlying poll returned, including
/// transient interrupted statuses. The orchestrator decides how to react.
final class FDv2PollingSynchronizer implements Synchronizer {
  final PollFunction _poll;
  final SelectorGetter _selectorGetter;
  final Duration _interval;
  final TimerFactory _timerFactory;
  final DateTime Function() _now;
  final LDLogger _logger;

  late final StreamController<FDv2SourceResult> _controller;
  Timer? _timer;
  // Single source of truth for "stop polling". Completed by either
  // close() (which also closes the controller and emits shutdown) or
  // _onCancel() (subscriber-initiated; no shutdown emission). All
  // event-loop callbacks (_doPoll, _scheduleNext) check this signal
  // before doing work.
  final Completer<void> _stoppedSignal = Completer<void>();
  DateTime? _lastFreshness;

  FDv2PollingSynchronizer({
    required PollFunction poll,
    required SelectorGetter selectorGetter,
    required Duration interval,
    required LDLogger logger,
    TimerFactory? timerFactory,
    DateTime Function()? now,
  })  : _poll = poll,
        _selectorGetter = selectorGetter,
        _interval = interval,
        _timerFactory = timerFactory ?? _defaultTimerFactory,
        _now = now ?? DateTime.now,
        _logger = logger.subLogger('FDv2PollingSynchronizer') {
    _controller = StreamController<FDv2SourceResult>(
      onListen: _onListen,
      onCancel: _onCancel,
    );
  }

  @override
  Stream<FDv2SourceResult> get results => _controller.stream;

  @override
  void close() {
    if (_stoppedSignal.isCompleted) return;
    _stoppedSignal.complete();
    _timer?.cancel();
    _timer = null;
    _controller.add(
        FDv2SourceResults.shutdown(message: 'Polling synchronizer closed'));
    _controller.close();
  }

  void _onListen() {
    // Kick off the first poll. Subsequent polls are scheduled from
    // inside _doPoll via the timer.
    unawaited(_doPoll());
  }

  Future<void> _onCancel() async {
    if (_stoppedSignal.isCompleted) return;
    _stoppedSignal.complete();
    _timer?.cancel();
    _timer = null;
    // Don't emit shutdown -- the subscriber asked for cancellation.
  }

  Future<void> _doPoll() async {
    if (_stoppedSignal.isCompleted) return;
    final FDv2SourceResult result;
    try {
      result = await _poll(basis: _selectorGetter());
    } catch (err) {
      // PollFunction is the FDv2PollingBase.pollOnce contract, which
      // already converts errors to StatusResult. A throw here means
      // someone wired a non-conforming function; treat defensively.
      _logger.error('Poll function threw unexpectedly: ${err.runtimeType}');
      if (!_stoppedSignal.isCompleted) {
        _controller.add(FDv2SourceResults.interrupted(
            message: 'Polling source raised error unexpectedly'));
      }
      _scheduleNext();
      return;
    }

    if (_stoppedSignal.isCompleted) return;

    if (result is ChangeSetResult && result.freshness != null) {
      _lastFreshness = result.freshness;
    }

    _controller.add(result);
    _scheduleNext();
  }

  void _scheduleNext() {
    if (_stoppedSignal.isCompleted) return;
    final delay = calculatePollDelay(
      now: _now(),
      interval: _interval,
      freshness: _lastFreshness,
    );
    _timer = _timerFactory(delay, _doPoll);
  }
}
