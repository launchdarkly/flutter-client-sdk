import 'dart:async';

import 'package:launchdarkly_dart_common/launchdarkly_dart_common.dart';
import '../item_descriptor.dart';
import 'flag_store.dart';

/// This event indicates that the details associated with one or more flags
/// have changed.
///
/// This could be the value of the flag, but it could also include changes
/// to the evaluation reason, such as being included in an experiment.
///
/// It can include new or deleted flags as well, so an evaluation may result
/// in a FLAG_NOT_FOUND reason.
///
/// This event does not include the value of the flag. It is expected that you
/// will call a variation method for flag values which you require.
final class FlagsChangedEvent {
  /// The keys for flags that have changed.
  final List<String> keys;

  FlagsChangedEvent({required this.keys});

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is FlagsChangedEvent && keys.equals(other.keys);

  @override
  int get hashCode => keys.hashCode;

  @override
  String toString() {
    return 'FlagsChangedEvent{keys: $keys}';
  }
}

/// The flag updater handles logic required during the flag update process.
/// It handles versions checking to handle out of order flag updates and
/// also handles flag comparisons for change notification.
final class FlagUpdater {
  final FlagStore _flagStore;
  final LDLogger _logger;
  String? _activeContextKey;
  final StreamController<FlagsChangedEvent> _controller =
      StreamController<FlagsChangedEvent>.broadcast();

  Stream<FlagsChangedEvent> get changes {
    return _controller.stream;
  }

  FlagUpdater({required FlagStore flagStore, required LDLogger logger})
      : _flagStore = flagStore,
        _logger = logger.subLogger('FlagUpdater');

  void init(LDContext context, Map<String, ItemDescriptor> newFlags,
      {String? environmentId}) {
    _activeContextKey = context.canonicalKey;
    final oldFlags = _flagStore.getAll();
    _flagStore.init(newFlags, environmentId: environmentId);
    _handleChanges(oldFlags, newFlags);
  }

  void initCached(LDContext context, Map<String, ItemDescriptor> newFlags,
      {String? environmentId}) {
    // The store has been initialized from our data source for this context,
    // so we can discard this update.
    // This would happen because the network response was faster than loading
    // data from persistence.
    if (_activeContextKey == context.canonicalKey) {
      return;
    }

    init(context, newFlags, environmentId: environmentId);
  }

  /// Create, update, or delete the item for the specific key. If the item
  /// Items are versioned and if an update is received out of order, then
  /// the update will not be performed and false will be returned. If the update
  /// completes successfully, then true will be returned.
  bool upsert(LDContext context, String key, ItemDescriptor item) {
    // The update is not for the active context. This scenario would indicate
    // that a data source connection was active for an inactive context, or
    // that we received a patch without having receives a put or having loaded
    // previously cached values.
    if (_activeContextKey != context.canonicalKey) {
      _logger.warn('Received an update for an inactive context.');
      return false;
    }
    final currentValue = _flagStore.get(key);

    if (currentValue != null && currentValue.version >= item.version) {
      // This represents an out of order update, so there is no work to be done.
      return false;
    }
    if (_controller.hasListener &&
        _hasChanged(key, _flagStore.get(key), item)) {
      _sendNotifications([key]);
    }
    _flagStore.insertOrUpdate(key, item);
    return true;
  }

  void close() {
    _controller.close();
  }

  bool _hasChanged(
      String flagKey, ItemDescriptor? oldItem, ItemDescriptor? newItem) {
    if (oldItem?.flag?.detail == newItem?.flag?.detail) {
      return false;
    }
    return true;
  }

  void _sendNotifications(List<String> keys) {
    _controller.sink.add(FlagsChangedEvent(keys: keys));
  }

  void _handleChanges(Map<String, ItemDescriptor> oldItems,
      Map<String, ItemDescriptor> newItems) {
    if (_controller.hasListener) {
      final List<String> changedKeys = [];
      for (final MapEntry(key: key, value: newDescriptor) in newItems.entries) {
        final existing = oldItems[key];
        if (_hasChanged(key, existing, newDescriptor)) {
          changedKeys.add(key);
        }
      }

      for (final MapEntry(key: key) in oldItems.entries) {
        final stillExists = newItems.containsKey(key);
        if (!stillExists) {
          // Item was in the old data, but not the new, so it was deleted.
          changedKeys.add(key);
        }
      }

      if (changedKeys.isNotEmpty) {
        _sendNotifications(changedKeys);
      }
    }
  }
}
