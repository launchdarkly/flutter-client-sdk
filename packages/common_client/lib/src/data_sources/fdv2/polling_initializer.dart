import 'dart:async';

import 'package:launchdarkly_dart_common/launchdarkly_dart_common.dart';

import 'selector.dart';
import 'source.dart';
import 'source_result.dart';

/// A single FDv2 poll. The orchestrator wires this to
/// [FDv2PollingBase.pollOnce]; tests inject scripted functions.
typedef PollFunction = Future<FDv2SourceResult> Function({Selector basis});

/// A function that delays for the given duration.
typedef DelayFunction = Future<void> Function(Duration duration);

Future<void> _defaultDelay(Duration duration) => Future.delayed(duration);

/// One-shot polling initializer.
///
/// Calls the injected [PollFunction] up to [_maxAttempts] times. Treats:
///
/// - [ChangeSetResult] as success — returned immediately.
/// - [SourceState.terminalError], [SourceState.goodbye], and
///   [SourceState.shutdown] as terminal — returned immediately without
///   further retries.
/// - [SourceState.interrupted] as transient — retried after
///   [_retryDelay] up to the attempt limit. After the limit, the last
///   interrupted result is converted into a [SourceState.terminalError]
///   so the orchestrator stops retrying at this layer of the chain.
///
/// Calling [close] before [run] completes signals an abort: any pending
/// retry delay returns immediately and [run] resolves to a
/// [SourceState.shutdown] result.
final class FDv2PollingInitializer implements Initializer {
  static const int _maxAttempts = 3;
  static const Duration _retryDelay = Duration(seconds: 1);

  final PollFunction _poll;
  final SelectorGetter _selectorGetter;
  final LDLogger _logger;
  final DelayFunction _delay;
  final Completer<void> _closedSignal = Completer<void>();

  FDv2PollingInitializer({
    required PollFunction poll,
    required SelectorGetter selectorGetter,
    required LDLogger logger,
    DelayFunction? delay,
  })  : _poll = poll,
        _selectorGetter = selectorGetter,
        _logger = logger.subLogger('FDv2PollingInitializer'),
        _delay = delay ?? _defaultDelay;

  @override
  Future<FDv2SourceResult> run() async {
    StatusResult? lastInterrupted;

    for (var attempt = 1; attempt <= _maxAttempts; attempt++) {
      if (_closedSignal.isCompleted) {
        return _shutdownResult();
      }

      final result = await _poll(basis: _selectorGetter());

      if (_closedSignal.isCompleted) {
        return _shutdownResult();
      }

      switch (result) {
        case ChangeSetResult():
          return result;
        case StatusResult(state: SourceState.interrupted):
          lastInterrupted = result;
          _logger.warn(
              'Polling initializer attempt $attempt/$_maxAttempts interrupted: '
              '${result.message}');
          if (attempt < _maxAttempts) {
            await _waitForRetry();
          }
        case StatusResult():
          // terminalError, goodbye, or shutdown -- pass through.
          return result;
      }
    }

    // All attempts produced interrupted. Escalate so the orchestrator
    // can fall through to the next source rather than retry forever.
    return FDv2SourceResults.terminalError(
      message: 'Polling initializer exhausted $_maxAttempts attempts; '
          'last error: ${lastInterrupted?.message}',
      statusCode: lastInterrupted?.statusCode,
      fdv1Fallback: lastInterrupted?.fdv1Fallback ?? false,
    );
  }

  @override
  void close() {
    if (!_closedSignal.isCompleted) {
      _closedSignal.complete();
    }
  }

  Future<void> _waitForRetry() async {
    await Future.any([_delay(_retryDelay), _closedSignal.future]);
  }

  StatusResult _shutdownResult() => FDv2SourceResults.shutdown(
        message: 'Polling initializer closed before completion',
      );
}
