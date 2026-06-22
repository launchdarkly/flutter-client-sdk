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
/// The manager assumes a single, sequential driver and relies on these
/// contracts:
///
/// - At most one source is active at a time. Activating a source closes
///   the previously active one, exhausting the initializer list closes
///   the final initializer, and [close] closes whatever remains.
/// - The synchronizer scan cursor doubles as the active-slot pointer:
///   from an activation ([nextAvailableSynchronizer] or
///   [recreateCurrentSynchronizer]) until the next cursor mutation
///   ([resetSynchronizerIndex] or [engageFdv1Fallback]), the cursor
///   identifies the running synchronizer's slot. [isPrimarySynchronizer]
///   and [blockCurrentSynchronizer] read the cursor and are only
///   meaningful inside that window. After mutating the cursor, activate
///   a new synchronizer before consulting either of them.
final class SourceManager {
  final List<InitializerFactory> _initializerFactories;
  final List<SynchronizerSlot> _synchronizerSlots;
  final SelectorGetter _selectorGetter;

  Initializer? _activeInitializer;
  Synchronizer? _activeSynchronizer;
  int _initializerIndex = -1;
  int _synchronizerIndex = -1;
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
  }

  int _firstAvailableIndex() => _synchronizerSlots
      .indexWhere((slot) => slot.state == SynchronizerSlotState.available);

  /// Get the next initializer and set it as the active source. Closes the
  /// previous active source. Returns null when all initializers are
  /// exhausted; exhaustion also closes the final initializer, so a
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
        return synchronizer;
      }
      visited += 1;
    }

    return null;
  }

  /// Close the active synchronizer and create a fresh instance from the
  /// current slot, without advancing the scan position. Used when a
  /// source must drop its connection and re-establish it (goodbye,
  /// invalid data). Returns null if the current slot is not available
  /// or no synchronizer has been started yet.
  Synchronizer? recreateCurrentSynchronizer() {
    if (_shutdown ||
        _synchronizerIndex < 0 ||
        _synchronizerIndex >= _synchronizerSlots.length) {
      return null;
    }
    final slot = _synchronizerSlots[_synchronizerIndex];
    if (slot.state != SynchronizerSlotState.available) {
      return null;
    }
    _closeActiveSource();
    final synchronizer = slot.factory.create(_selectorGetter);
    _activeSynchronizer = synchronizer;
    return synchronizer;
  }

  /// Mark the active synchronizer's slot as blocked (e.g. after a
  /// terminal error). Reads the scan cursor, so it must only be called
  /// while the cursor identifies the active slot (see the class
  /// contract).
  void blockCurrentSynchronizer() {
    if (_synchronizerIndex >= 0 &&
        _synchronizerIndex < _synchronizerSlots.length) {
      _synchronizerSlots[_synchronizerIndex].state =
          SynchronizerSlotState.blocked;
    }
  }

  /// Reset the synchronizer scan cursor so the next call to
  /// [nextAvailableSynchronizer] starts from the beginning. After a
  /// reset the cursor no longer identifies the active slot; activate a
  /// new synchronizer before consulting [isPrimarySynchronizer] or
  /// [blockCurrentSynchronizer].
  void resetSynchronizerIndex() {
    _synchronizerIndex = -1;
  }

  /// Block all non-FDv1 synchronizers, unblock the FDv1 fallback, and
  /// reset the scan cursor so the next activation selects the fallback.
  /// Does nothing when no FDv1 fallback slot is configured, since
  /// blocking every slot without unblocking one would leave nothing to
  /// activate. The active source keeps running until the next
  /// activation closes it.
  void engageFdv1Fallback() {
    if (!hasFdv1FallbackConfigured) {
      return;
    }
    for (final slot in _synchronizerSlots) {
      slot.state = slot.isFdv1Fallback
          ? SynchronizerSlotState.available
          : SynchronizerSlotState.blocked;
    }
    _synchronizerIndex = -1;
  }

  /// True if the active synchronizer occupies the first available slot
  /// (the primary). Reads the scan cursor, so it is only meaningful
  /// while the cursor identifies the active slot (see the class
  /// contract).
  bool get isPrimarySynchronizer =>
      _synchronizerIndex == _firstAvailableIndex();

  /// Count of synchronizers in the available state.
  int get availableSynchronizerCount => _synchronizerSlots
      .where((slot) => slot.state == SynchronizerSlotState.available)
      .length;

  /// True if any synchronizer slot is the FDv1 fallback, whether or not
  /// it has been engaged.
  bool get hasFdv1FallbackConfigured =>
      _synchronizerSlots.any((slot) => slot.isFdv1Fallback);

  /// True when the active synchronizer is the FDv1 fallback. Reads the scan
  /// cursor, so it is only meaningful while the cursor identifies the active
  /// slot (see the class contract). Used to ignore a repeat fallback
  /// directive once the SDK is already on FDv1.
  bool get isCurrentSynchronizerFdv1Fallback =>
      _synchronizerIndex >= 0 &&
      _synchronizerIndex < _synchronizerSlots.length &&
      _synchronizerSlots[_synchronizerIndex].isFdv1Fallback;

  /// Close the active source and mark the manager as shut down.
  void close() {
    _shutdown = true;
    _closeActiveSource();
  }
}
