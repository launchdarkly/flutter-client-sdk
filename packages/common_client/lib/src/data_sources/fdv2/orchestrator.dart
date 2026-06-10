import 'dart:async';

import 'package:launchdarkly_dart_common/launchdarkly_dart_common.dart'
    show LDLogger;

import '../data_source.dart';
import '../data_source_status.dart';
import '../data_source_status_manager.dart';
import 'conditions.dart';
import 'entry_factories.dart';
import 'payload.dart';
import 'selector.dart';
import 'source.dart';
import 'source_manager.dart';
import 'source_result.dart';

/// Receives the selector from each applied payload so it can be carried
/// across data source instances (mode switches, reconnects).
typedef SelectorUpdater = void Function(Selector selector);

/// Outcome of running a single synchronizer instance, directing what the
/// synchronizer loop does next.
enum _SynchronizerOutcome {
  /// Move to the next available synchronizer.
  advance,

  /// Re-create the current synchronizer (goodbye or restart request).
  recycle,

  /// Reset to the primary synchronizer (recovery condition fired).
  recover,

  /// Stop the orchestration loop entirely.
  stop,
}

sealed class _RaceResult {}

final class _SourceResult extends _RaceResult {
  final FDv2SourceResult? result;
  _SourceResult(this.result);
}

final class _ConditionFired extends _RaceResult {
  final ConditionType type;
  _ConditionFired(this.type);
}

final class _RecycleRequested extends _RaceResult {}

/// The FDv2 data source orchestrator.
///
/// Runs the initializer chain to bring the SDK to a usable state, then
/// drives the synchronizer tier with fallback and recovery transitions.
/// Implements the existing [DataSource] interface so the
/// DataSourceManager pipeline consumes it unchanged: change sets are
/// emitted as [PayloadEvent]s, and a [StatusEvent] with `shutdown: true`
/// is emitted only when the data system halts without having delivered
/// data. Transient interruptions are reported directly through the
/// [DataSourceStatusManager], matching the FDv1 streaming source's
/// behavior of not failing an in-flight identify for recoverable errors.
final class FDv2DataSourceOrchestrator implements DataSource {
  final SourceManager _sourceManager;
  final List<InitializerFactory> _initializerFactories;
  final List<SynchronizerSlot> _synchronizerSlots;
  final SelectorUpdater _selectorUpdater;
  final DataSourceStatusManager _statusManager;
  final Duration _fallbackTimeout;
  final Duration _recoveryTimeout;
  final Duration _recycleDelay;
  final ConditionTimerFactory? _conditionTimerFactory;
  final LDLogger _logger;

  final StreamController<DataSourceEvent> _controller =
      StreamController<DataSourceEvent>();

  bool _started = false;
  bool _closed = false;
  bool _dataEmitted = false;

  /// Completed by [restart] to ask the active synchronizer loop to drop
  /// its connection and re-establish it. Re-armed for each synchronizer
  /// iteration.
  Completer<void> _recycleSignal = Completer<void>();

  FDv2DataSourceOrchestrator({
    required List<InitializerFactory> initializerFactories,
    required List<SynchronizerSlot> synchronizerSlots,
    required SelectorGetter selectorGetter,
    required SelectorUpdater selectorUpdater,
    required DataSourceStatusManager statusManager,
    required LDLogger logger,
    Duration fallbackTimeout = defaultFallbackTimeout,
    Duration recoveryTimeout = defaultRecoveryTimeout,
    Duration recycleDelay = const Duration(seconds: 1),
    ConditionTimerFactory? conditionTimerFactory,
  })  : _initializerFactories = initializerFactories,
        _synchronizerSlots = synchronizerSlots,
        _selectorUpdater = selectorUpdater,
        _statusManager = statusManager,
        _fallbackTimeout = fallbackTimeout,
        _recoveryTimeout = recoveryTimeout,
        _recycleDelay = recycleDelay,
        _conditionTimerFactory = conditionTimerFactory,
        _logger = logger.subLogger('FDv2Orchestrator'),
        _sourceManager = SourceManager(
          initializerFactories: initializerFactories,
          synchronizerSlots: synchronizerSlots,
          selectorGetter: selectorGetter,
        );

  @override
  Stream<DataSourceEvent> get events => _controller.stream;

  @override
  void start() {
    if (_started || _closed) {
      return;
    }
    _started = true;
    unawaited(_run());
  }

  @override
  void stop() {
    if (_closed) return;
    _closed = true;
    _sourceManager.close();
    if (!_recycleSignal.isCompleted) {
      // Wake the synchronizer loop so it can observe the closed state.
      _recycleSignal.complete();
    }
    if (!_controller.isClosed) {
      _controller.close();
    }
  }

  @override
  void restart() {
    if (_closed) return;
    _logger.debug('Restart requested; recycling the active synchronizer.');
    if (!_recycleSignal.isCompleted) {
      _recycleSignal.complete();
    }
  }

  Future<void> _run() async {
    try {
      await _runInitializers();
      if (!_closed) {
        await _runSynchronizers();
      }
    } catch (err, stack) {
      _logger.error('Orchestration raised unexpectedly: ${err.runtimeType}');
      _logger.debug('Orchestration error stack:\n$stack');
      _halt('FDv2 data system encountered an unexpected error');
    }
  }

  void _emitPayload(ChangeSetResult result) {
    if (_closed || _controller.isClosed) return;
    // An intent of "none" means the SDK is already up to date; it carries
    // no selector and must not regress the one we hold.
    if (result.payload.type != PayloadType.none) {
      _selectorUpdater(result.payload.selector);
    }
    _dataEmitted = true;
    _controller
        .add(PayloadEvent(result.payload, environmentId: result.environmentId));
  }

  void _reportTransientError(StatusResult result) {
    final message = result.message ?? 'FDv2 data source reported an error';
    if (result.statusCode case final statusCode?) {
      _statusManager.setErrorResponse(statusCode, message);
    } else {
      _statusManager.setErrorByKind(ErrorKind.networkError, message);
    }
  }

  /// Halts the data system. Emits a shutdown status event so a pending
  /// identify fails and the status reflects that no further data will
  /// arrive.
  void _halt(String message) {
    if (_closed || _controller.isClosed) return;
    _logger.warn('FDv2 data system halted: $message');
    _controller
        .add(StatusEvent(ErrorKind.unknown, null, message, shutdown: true));
  }

  /// True when the source indicated an FDv1 fallback directive and a
  /// fallback tier exists to engage.
  bool _handleFdv1Fallback(FDv2SourceResult result) {
    if (result.fdv1Fallback && _sourceManager.hasFdv1Fallback) {
      _logger.warn('Server directed fallback to FDv1; engaging the FDv1 '
          'fallback synchronizer.');
      _sourceManager.engageFdv1Fallback();
      return true;
    }
    return false;
  }

  Future<void> _runInitializers() async {
    var errorDuringInit = false;

    while (!_closed) {
      final initializer = _sourceManager.nextInitializer();
      if (initializer == null) {
        break;
      }

      final result = await initializer.run();
      if (_closed) return;

      switch (result) {
        case ChangeSetResult():
          if (result.payload.type != PayloadType.none) {
            _emitPayload(result);

            if (_handleFdv1Fallback(result)) {
              // Data was received but the server directed FDv1 fallback;
              // move on to synchronizers where the fallback tier runs.
              return;
            }

            if (result.payload.selector.isNotEmpty) {
              // Basis data with a selector: initialization is complete.
              return;
            }
            // Data without a selector (e.g. cache); keep initializing.
          }
        case StatusResult():
          switch (result.state) {
            case SourceState.interrupted:
            case SourceState.terminalError:
              _logger.warn('Initializer failed: '
                  '${result.message ?? 'unknown error'}');
              _reportTransientError(result);
              errorDuringInit = true;
            case SourceState.shutdown:
              return;
            case SourceState.goodbye:
              break;
          }
          if (_handleFdv1Fallback(result)) {
            return;
          }
      }
    }

    if (_closed) return;

    // All initializers exhausted. A data system whose only sources are
    // cache initializers must still complete initialization on a cache
    // miss -- there is nowhere else for data to come from. Emit an empty
    // payload so the pipeline reaches a valid state, unless an error has
    // already been reported.
    final cacheOnlyDataSystem = _initializerFactories.isNotEmpty &&
        _initializerFactories.every((f) => f.isCache) &&
        _synchronizerSlots.isEmpty;
    if (cacheOnlyDataSystem && !_dataEmitted && !errorDuringInit) {
      _emitPayload(const ChangeSetResult(
        payload: Payload(type: PayloadType.none, updates: []),
        persist: false,
      ));
    }
  }

  Future<void> _runSynchronizers() async {
    // A data system with no sources at all has nothing to do; an empty
    // payload marks it valid so a pending identify completes.
    if (_initializerFactories.isEmpty && _synchronizerSlots.isEmpty) {
      _emitPayload(const ChangeSetResult(
        payload: Payload(type: PayloadType.none, updates: []),
        persist: false,
      ));
      return;
    }

    Synchronizer? synchronizer;
    var recycleCurrent = false;

    while (!_closed) {
      if (recycleCurrent) {
        recycleCurrent = false;
        if (_recycleDelay > Duration.zero) {
          await Future<void>.delayed(_recycleDelay);
          if (_closed) return;
        }
        synchronizer = _sourceManager.recreateCurrentSynchronizer();
      } else {
        synchronizer = _sourceManager.nextAvailableSynchronizer();
      }

      if (synchronizer == null) {
        if (!_dataEmitted) {
          _halt('All FDv2 data sources exhausted without receiving data');
        } else if (_synchronizerSlots.isNotEmpty) {
          _logger.warn('No available FDv2 synchronizer remains; the SDK '
              'will not receive further updates.');
        }
        return;
      }

      final outcome = await _runSynchronizer(synchronizer);
      switch (outcome) {
        case _SynchronizerOutcome.advance:
          break;
        case _SynchronizerOutcome.recycle:
          recycleCurrent = true;
        case _SynchronizerOutcome.recover:
          _sourceManager.resetSynchronizerIndex();
        case _SynchronizerOutcome.stop:
          return;
      }
    }
  }

  Future<_SynchronizerOutcome> _runSynchronizer(
      Synchronizer synchronizer) async {
    final conditions = getConditions(
      availableSynchronizerCount: _sourceManager.availableSynchronizerCount,
      isPrimary: _sourceManager.isPrimarySynchronizer,
      fallbackTimeout: _fallbackTimeout,
      recoveryTimeout: _recoveryTimeout,
      timerFactory: _conditionTimerFactory,
    );

    // Arm the recycle signal for this synchronizer instance.
    if (_recycleSignal.isCompleted) {
      _recycleSignal = Completer<void>();
    }

    final iterator = StreamIterator(synchronizer.results);
    try {
      while (!_closed) {
        final racers = <Future<_RaceResult>>[
          iterator.moveNext().then(
              (hasNext) => _SourceResult(hasNext ? iterator.current : null)),
          _recycleSignal.future.then((_) => _RecycleRequested()),
          if (conditions.future case final conditionFuture?)
            conditionFuture.then(_ConditionFired.new),
        ];

        final winner = await Future.any(racers);
        if (_closed) return _SynchronizerOutcome.stop;

        switch (winner) {
          case _RecycleRequested():
            // Either restart() was called or stop() raced us; stop() was
            // checked above, so this is a restart request.
            return _SynchronizerOutcome.recycle;

          case _ConditionFired(:final type):
            switch (type) {
              case ConditionType.fallback:
                _logger.warn('Fallback condition fired; moving to the next '
                    'synchronizer.');
                return _SynchronizerOutcome.advance;
              case ConditionType.recovery:
                _logger.info('Recovery condition fired; returning to the '
                    'primary synchronizer.');
                return _SynchronizerOutcome.recover;
            }

          case _SourceResult(:final result):
            if (result == null) {
              // The stream ended without a directive. Terminal paths emit
              // a final result first, which is handled below before the
              // next moveNext, so this indicates the source shut itself
              // down unexpectedly. Re-establish it.
              _logger.warn('Synchronizer stream ended unexpectedly; '
                  're-establishing.');
              return _SynchronizerOutcome.recycle;
            }

            conditions.inform(result);

            switch (result) {
              case ChangeSetResult():
                _emitPayload(result);
              case StatusResult():
                switch (result.state) {
                  case SourceState.interrupted:
                    _logger.warn('Synchronizer interrupted: '
                        '${result.message ?? 'unknown error'}');
                    _reportTransientError(result);
                  case SourceState.terminalError:
                    _logger.warn('Synchronizer terminal error: '
                        '${result.message ?? 'unknown error'}');
                    _reportTransientError(result);
                    if (_handleFdv1Fallback(result)) {
                      return _SynchronizerOutcome.advance;
                    }
                    _sourceManager.blockCurrentSynchronizer();
                    return _SynchronizerOutcome.advance;
                  case SourceState.shutdown:
                    return _SynchronizerOutcome.stop;
                  case SourceState.goodbye:
                    _logger.info('Server requested disconnect (goodbye); '
                        're-establishing the synchronizer.');
                    return _SynchronizerOutcome.recycle;
                }
            }

            if (_handleFdv1Fallback(result)) {
              return _SynchronizerOutcome.advance;
            }
        }
      }
      return _SynchronizerOutcome.stop;
    } finally {
      conditions.close();
      await iterator.cancel();
      synchronizer.close();
    }
  }
}
