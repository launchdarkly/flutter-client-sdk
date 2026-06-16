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
  final LDLogger _logger;

  final StreamController<DataSourceEvent> _controller =
      StreamController<DataSourceEvent>();

  bool _started = false;
  bool _closed = false;
  bool _emittedPayload = false;

  /// Resolves the outcome of the active synchronizer run. Set while a
  /// synchronizer is running; [restart] and [stop] use it to interrupt
  /// the run.
  void Function(_SynchronizerOutcome outcome)? _resolveCurrentOutcome;

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
  })  : _initializerFactories = initializerFactories,
        _synchronizerSlots = synchronizerSlots,
        _selectorUpdater = selectorUpdater,
        _statusManager = statusManager,
        _fallbackTimeout = fallbackTimeout,
        _recoveryTimeout = recoveryTimeout,
        _recycleDelay = recycleDelay,
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
    // Wake the active synchronizer run so it can observe the closed
    // state.
    _resolveCurrentOutcome?.call(_SynchronizerOutcome.stop);
    if (!_controller.isClosed) {
      _controller.close();
    }
  }

  @override
  void restart() {
    if (_closed) return;
    _logger.debug('Restart requested; recycling the active synchronizer.');
    _resolveCurrentOutcome?.call(_SynchronizerOutcome.recycle);
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
    if (result.changeSet.type != PayloadType.none) {
      _selectorUpdater(result.changeSet.selector);
    }
    _emittedPayload = true;
    _controller.add(
        PayloadEvent(result.changeSet, environmentId: result.environmentId));
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
    if (result.fdv1Fallback && _sourceManager.hasFdv1FallbackConfigured) {
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
          if (result.changeSet.type != PayloadType.none) {
            _emitPayload(result);

            if (_handleFdv1Fallback(result)) {
              // Data was received but the server directed FDv1 fallback;
              // move on to synchronizers where the fallback tier runs.
              return;
            }

            if (result.changeSet.selector.isNotEmpty) {
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
    if (cacheOnlyDataSystem && !_emittedPayload && !errorDuringInit) {
      _emitPayload(const ChangeSetResult(
        changeSet: ChangeSet(type: PayloadType.none, updates: {}),
        persist: false,
      ));
    }
  }

  Future<void> _runSynchronizers() async {
    // A data system with no sources at all has nothing to do; an empty
    // payload marks it valid so a pending identify completes.
    if (_initializerFactories.isEmpty && _synchronizerSlots.isEmpty) {
      _emitPayload(const ChangeSetResult(
        changeSet: ChangeSet(type: PayloadType.none, updates: {}),
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
        if (!_emittedPayload) {
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

  /// Runs a single synchronizer instance until something decides its
  /// outcome.
  ///
  /// Consumption is subscription-driven: one listener on the
  /// synchronizer's results, one on the merged condition stream, and a
  /// resolve hook for [restart] and [stop]. Nothing is attached
  /// per-result, so a healthy synchronizer that streams change sets
  /// indefinitely holds constant memory. (Racing long-lived futures per
  /// result would attach an irremovable listener to them each
  /// iteration; future listeners are only released on completion.)
  Future<_SynchronizerOutcome> _runSynchronizer(
      Synchronizer synchronizer) async {
    final conditions = getConditions(
      availableSynchronizerCount: _sourceManager.availableSynchronizerCount,
      isPrimary: _sourceManager.isPrimarySynchronizer,
      fallbackTimeout: _fallbackTimeout,
      recoveryTimeout: _recoveryTimeout,
    );

    final outcome = Completer<_SynchronizerOutcome>();
    void resolve(_SynchronizerOutcome decision) {
      if (!outcome.isCompleted) {
        outcome.complete(decision);
      }
    }

    _resolveCurrentOutcome = resolve;

    final conditionSubscription = conditions.events.listen((type) {
      switch (type) {
        case ConditionType.fallback:
          _logger.warn('Fallback condition fired; moving to the next '
              'synchronizer.');
          resolve(_SynchronizerOutcome.advance);
        case ConditionType.recovery:
          _logger.info('Recovery condition fired; returning to the '
              'primary synchronizer.');
          resolve(_SynchronizerOutcome.recover);
      }
    });

    final resultSubscription = synchronizer.results.listen((result) {
      if (outcome.isCompleted || _closed) return;

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
                resolve(_SynchronizerOutcome.advance);
                return;
              }
              _sourceManager.blockCurrentSynchronizer();
              resolve(_SynchronizerOutcome.advance);
              return;
            case SourceState.shutdown:
              // A synchronizer that shuts itself down before the system
              // has reached a usable state would otherwise leave a
              // pending identify with nothing to resolve it. Emit a
              // shutdown status so identify fails rather than hangs,
              // mirroring the source-exhaustion path. (No shipped source
              // reaches here while the system is still live, but a future
              // synchronizer could.)
              if (!_emittedPayload) {
                _halt('FDv2 synchronizer shut down without delivering data');
              }
              resolve(_SynchronizerOutcome.stop);
              return;
            case SourceState.goodbye:
              _logger.info('Server requested disconnect (goodbye); '
                  're-establishing the synchronizer.');
              resolve(_SynchronizerOutcome.recycle);
              return;
          }
      }

      if (_handleFdv1Fallback(result)) {
        resolve(_SynchronizerOutcome.advance);
      }
    }, onDone: () {
      if (outcome.isCompleted || _closed) return;
      // The stream ended without a directive. Terminal paths emit a
      // final result first, which is handled above, so this indicates
      // the source shut itself down unexpectedly. Re-establish it.
      _logger.warn('Synchronizer stream ended unexpectedly; '
          're-establishing.');
      resolve(_SynchronizerOutcome.recycle);
    });

    try {
      final decision = await outcome.future;
      return _closed ? _SynchronizerOutcome.stop : decision;
    } finally {
      _resolveCurrentOutcome = null;
      conditions.close();
      await conditionSubscription.cancel();
      await resultSubscription.cancel();
      synchronizer.close();
    }
  }
}
