final class IndexEntry {
  final String id;
  int msTimestamp;

  IndexEntry(this.id, this.msTimestamp);

  IndexEntry.fromJson(Map<String, dynamic> json)
      : id = json['id'],
        msTimestamp = json['msTimestamp'];

  Map<String, dynamic> toJson() {
    return {'id': id, 'msTimestamp': msTimestamp};
  }
}

/// Used internally to track which contexts have flag data that has been
/// persisted.
///
/// This exists because we can't assume that the persistent store mechanism has
/// an "enumerate all the keys that exist under such-and-such prefix" capability,
/// so we need a table of contents at a fixed location. The only information
/// being tracked here is, for each flag data set that exists in storage,
/// 1. a context identifier (hashed fully-qualified key) and
/// 2. timestamp when it was last accessed, to support an LRU
/// eviction pattern.
///
final class ContextIndex {
  final List<IndexEntry> _index;

  List<IndexEntry> get entries {
    return List.unmodifiable(_index);
  }

  ContextIndex() : _index = [];

  ContextIndex.fromJson(Map<String, dynamic> json)
      : _index = (json['index'] as List<dynamic>)
            .map((entry) => IndexEntry.fromJson(entry))
            .toList();

  Map<String, dynamic> toJson() {
    return {'index': _index.map((entry) => entry.toJson()).toList()};
  }

  /// Notice that a context has been used, and when it was used. This will
  /// update an existing record with the given timestamp, or create a new
  /// record if one doesn't exist.
  void notice(String id, DateTime timestamp) {
    var found = false;
    // This could use firstWhereOrNull, but it requires using package:collection.
    // If we someday add that dependency, then we could simplify this.
    for (var pos = 0; pos < _index.length; pos++) {
      final entry = _index[pos];
      if (entry.id == id) {
        entry.msTimestamp = timestamp.millisecondsSinceEpoch;
        found = true;
        break;
      }
    }
    if (!found) {
      _index.add(IndexEntry(id, timestamp.millisecondsSinceEpoch));
    }
  }

  /// Prune the index to the specified max size and then return the IDs
  /// of the pruned items.
  List<String> prune(int maxContexts) {
    List<String> removed = [];
    if (_index.length <= maxContexts) {
      return removed;
    }

    _index.sort((a, b) => b.msTimestamp.compareTo(a.msTimestamp));

    while (_index.length > maxContexts) {
      final removedEntry = _index.removeLast();
      removed.add(removedEntry.id);
    }
    return removed;
  }
}
