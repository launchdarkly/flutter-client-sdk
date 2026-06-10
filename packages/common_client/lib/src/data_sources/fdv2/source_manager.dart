import 'entry_factories.dart';
import 'source.dart';

/// State of a synchronizer slot.
enum SynchronizerSlotState {
  /// Can be selected for use.
  available,

  /// Cannot be selected (terminal error, or an FDv1 fallback slot that has
  /// not been activated).
  blocked,
}

/// A slot in the synchronizer list, wrapping a factory with state.
final class SynchronizerSlot {
  final SynchronizerFactory factory;

  /// True when this slot is the FDv1 fallback adapter. FDv1 slots start
  /// blocked and are only activated by a server fallback directive.
  final bool isFdv1Fallback;

  SynchronizerSlotState state;

  SynchronizerSlot({
    required this.factory,
    this.isFdv1Fallback = false,
    SynchronizerSlotState? initialState,
  }) : state = initialState ??
            (isFdv1Fallback
                ? SynchronizerSlotState.blocked
                : SynchronizerSlotState.available);
}

/// Manages the state of initializers and synchronizers, tracks which
/// source is active, and handles source transitions for the orchestrator.
///
/// Every transition closes the previously active source: producing the
/// next initializer or synchronizer, re-creating the current
/// synchronizer, engaging the FDv1 fallback, exhausting the initializer
/// list, and shutting the manager down.
final class SourceManager {
  final List<InitializerFactory> _initializerFactories;
  final List<SynchronizerSlot> _synchronizerSlots;
  final SelectorGetter _selectorGetter;

  Initializer? _activeInitializer;
  Synchronizer? _activeSynchronizer;
  int _initializerIndex = -1;

  /// Scan cursor for the synchronizer rotation. Advanced by
  /// [nextAvailableSynchronizer]; reset by [resetSynchronizerIndex] and
  /// [engageFdv1Fallback].
  int _synchronizerIndex = -1;

  /// The slot of the active synchronizer, distinct from the scan
  /// cursor: the cursor can move (recovery reset, fallback engagement)
  /// while a synchronizer is still active.
  int? _activeSlotIndex;

  bool _shutdown = false;

  SourceManager({
    required List<InitializerFactory> initializerFactories,
    required List<SynchronizerSlot> synchronizerSlots,
    required SelectorGetter selectorGetter,
  })  : _initializerFactories = initializerFactories,
        _synchronizerSlots = synchronizerSlots,
        _selectorGetter = selectorGetter;

  bool get isShutdown => _shutdown;

  void _closeActiveSource() {
    _activeInitializer?.close();
    _activeInitializer = null;
    _activeSynchronizer?.close();
    _activeSynchronizer = null;
    _activeSlotIndex = null;
  }

  int _firstAvailableIndex() => _synchronizerSlots
      .indexWhere((slot) => slot.state == SynchronizerSlotState.available);

  /// Get the next initializer and set it as the active source. Closes the
  /// previous active source. Returns null when all initializers are
  /// exhausted; exhaustion also closes the last active source, so a
  /// terminal null leaves no source running.
  Initializer? nextInitializer() {
    if (_shutdown) return null;

    _initializerIndex += 1;
    if (_initializerIndex >= _initializerFactories.length) {
      _closeActiveSource();
      return null;
    }

    _closeActiveSource();
    final initializer =
        _initializerFactories[_initializerIndex].create(_selectorGetter);
    _activeInitializer = initializer;
    return initializer;
  }

  /// Get the next available (non-blocked) synchronizer and set it as the
  /// active source, scanning forward from the current position and
  /// wrapping around. Closes the previous active source. Returns null
  /// when no synchronizer is available.
  Synchronizer? nextAvailableSynchronizer() {
    if (_shutdown || _synchronizerSlots.isEmpty) return null;

    var visited = 0;
    while (visited < _synchronizerSlots.length) {
      _synchronizerIndex += 1;
      if (_synchronizerIndex >= _synchronizerSlots.length) {
        _synchronizerIndex = 0;
      }

      final candidate = _synchronizerSlots[_synchronizerIndex];
      if (candidate.state == SynchronizerSlotState.available) {
        _closeActiveSource();
        final synchronizer = candidate.factory.create(_selectorGetter);
        _activeSynchronizer = synchronizer;
        _activeSlotIndex = _synchronizerIndex;
        return synchronizer;
      }
      visited += 1;
    }

    return null;
  }

  /// Close the active synchronizer and create a fresh instance from its
  /// slot, without advancing the scan position. Used when a source must
  /// drop its connection and re-establish it (goodbye, invalid data).
  /// Returns null if no synchronizer is active or its slot is no longer
  /// available.
  Synchronizer? recreateCurrentSynchronizer() {
    if (_shutdown) return null;
    final slotIndex = _activeSlotIndex;
    if (slotIndex == null) return null;

    final slot = _synchronizerSlots[slotIndex];
    if (slot.state != SynchronizerSlotState.available) {
      return null;
    }
    _closeActiveSource();
    final synchronizer = slot.factory.create(_selectorGetter);
    _activeSynchronizer = synchronizer;
    _activeSlotIndex = slotIndex;
    return synchronizer;
  }

  /// Mark the active synchronizer's slot as blocked (e.g. after a
  /// terminal error). Blocking does not close the running synchronizer;
  /// the next transition does. No effect when no synchronizer is active.
  void blockCurrentSynchronizer() {
    if (_activeSlotIndex case final slotIndex?) {
      _synchronizerSlots[slotIndex].state = SynchronizerSlotState.blocked;
    }
  }

  /// Reset the synchronizer scan position so the next call to
  /// [nextAvailableSynchronizer] starts from the beginning.
  void resetSynchronizerIndex() {
    _synchronizerIndex = -1;
  }

  /// Block all non-FDv1 synchronizers and unblock FDv1 synchronizers,
  /// closing the active source. No effect when no FDv1 fallback slot is
  /// configured: a fallback directive must not be able to leave the SDK
  /// with no usable synchronizer tier.
  void engageFdv1Fallback() {
    if (!hasFdv1FallbackConfigured) return;
    _closeActiveSource();
    for (final slot in _synchronizerSlots) {
      slot.state = slot.isFdv1Fallback
          ? SynchronizerSlotState.available
          : SynchronizerSlotState.blocked;
    }
    _synchronizerIndex = -1;
  }

  /// True if the active synchronizer is the first available (primary).
  /// False when no synchronizer is active.
  bool get isPrimarySynchronizer =>
      _activeSlotIndex != null && _activeSlotIndex == _firstAvailableIndex();

  /// Count of synchronizers in the available state.
  int get availableSynchronizerCount => _synchronizerSlots
      .where((slot) => slot.state == SynchronizerSlotState.available)
      .length;

  /// True if any synchronizer slot is configured as an FDv1 fallback,
  /// regardless of whether the fallback has been engaged.
  bool get hasFdv1FallbackConfigured =>
      _synchronizerSlots.any((slot) => slot.isFdv1Fallback);

  /// Close the active source and mark the manager as shut down.
  void close() {
    _shutdown = true;
    _closeActiveSource();
  }
}
