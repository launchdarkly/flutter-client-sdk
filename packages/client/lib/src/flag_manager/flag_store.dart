import '../item_descriptor.dart';

/// The flag store is an in-memory store for flag data.
/// It does not contain any logic related to the flag update process
/// it is just a key-value store.
final class FlagStore {
  final Map<String, ItemDescriptor> _flags = {};

  void init(Map<String, ItemDescriptor> newFlags) {
    _flags.clear();
    _flags.addAll(newFlags);
  }

  void insertOrUpdate(String key, ItemDescriptor update) {
    _flags[key] = update;
  }

  /// Attempts to get a flag by key from the current flags.
  ItemDescriptor? get(String key) => _flags[key];

  /// Gets all the current flags.
  Map<String, ItemDescriptor> getAll() {
    // The map itself will not be modifiable, but the contents are references.
    // They should not be propagated to the end-user without cloning them.
    return Map.unmodifiable(_flags);
  }
}
