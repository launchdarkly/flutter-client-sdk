/// Compare the contents of two lists using those items equality comparisons.
/// This does not recursively apply this operation to lists/maps within the
/// array. Items will be compared using `==`/`!=`, so nested/lists maps will
/// use reference comparison.
extension ListComparisons<T> on List<T> {
  bool equals(List<T> other) {
    if (length != other.length) return false;
    for (var index = 0; index < length; index++) {
      if (this[index] != other[index]) {
        return false;
      }
    }
    return true;
  }
}

extension SetComparisons<T> on Set<T> {
  /// Compare the contents of two sets. The sets must be the same size and
  /// contain all the same objects.
  bool equals(Set<T> other) {
    if (length != other.length) return false;

    return containsAll(other);
  }
}

extension IterableWhere<T> on Iterable<T> {
  /// Find the first item matching a prerequisite or null.
  ///
  /// This functionality is also provided by collection package. If we ever
  /// add that package as a dependency, then we should remove this implementation.
  T? firstWhereOrNull(bool Function(T) prerequisite) {
    for (var item in this) {
      if (prerequisite(item)) {
        return item;
      }
    }
    return null;
  }
}

extension IterableAsync<TItem> on Iterable<TItem> {
  Future<TResult> asyncReduce<TResult>(
      Future<TResult> Function(TItem current, TResult accumulator) reducer,
      TResult initial) async {
    TResult accumulator = initial;
    for (var item in this) {
      accumulator = await reducer(item, accumulator);
    }
    return accumulator;
  }
}

/// Compare the contents of two maps using those items equality comparisons.
/// This does not recursively apply this operation to lists/maps within the
/// map. Items will be compared using `==`/`!=`, so nested lists/maps will
/// use reference comparison.
extension MapComparisons<K, V> on Map<K, V> {
  bool equals(Map<K, V> other) {
    if (length != other.length) {
      return false;
    }
    for (var pair in entries) {
      if (!other.containsKey(pair.key)) {
        return false;
      }
      if (pair.value != other[pair.key]) {
        return false;
      }
    }
    return true;
  }
}
