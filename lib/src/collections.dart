
/// Compare the contents of two lists using those items equality comparisons.
/// This does not recursively apply this operation to lists/maps within the
/// array. Items will be compared using `==`/`!=`, so nested/lists maps will
/// use reference comparison.
extension ListComparisons<T> on List<T> {
  bool equals(List<T> other) {
    if(length!=other.length) return false;
    for(var index = 0; index < length; index++) {
      if(this[index] != other[index]) {
        return false;
      }
    }
    return true;
  }
}

/// Compare the contents of two maps using those items equality comparisons.
/// This does not recursively apply this operation to lists/maps within the
/// map. Items will be compared using `==`/`!=`, so nested lists/maps will
/// use reference comparison.
extension MapComparisons<K, V> on Map<K, V> {
  bool equals(Map<K, V> other) {
    if(length != other.length) {
      return false;
    }
    for (var pair in entries) {
      if(!other.containsKey(pair.key)) {
        return false;
      }
      if(pair.value != other[pair.key]) {
        return false;
      }
    }
    return true;
  }
}
