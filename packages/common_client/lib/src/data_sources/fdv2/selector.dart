/// An opaque selector representing the SDK's current payload state and
/// version. The [state] string is sent back to the server as the `basis`
/// query parameter to enable delta-based updates.
///
/// A selector is either empty ([Selector.empty]) or carries both a
/// [state] and [version] provided by a LaunchDarkly data source. An
/// empty selector cannot be used as a basis for requesting incremental
/// updates.
final class Selector {
  /// An empty selector indicating no known state.
  static const Selector empty = Selector._empty();

  /// The opaque state string from the server, or null if this
  /// selector is empty.
  final String? state;

  /// The payload version associated with this selector. Zero when the
  /// selector is empty.
  final int version;

  /// Whether this selector is empty.
  final bool isEmpty;

  /// Creates a non-empty selector with the given [state] and [version].
  const Selector({required String this.state, required this.version})
      : isEmpty = false;

  const Selector._empty()
      : state = null,
        version = 0,
        isEmpty = true;

  bool get isNotEmpty => !isEmpty;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is Selector &&
          isEmpty == other.isEmpty &&
          state == other.state &&
          version == other.version;

  @override
  int get hashCode => Object.hash(isEmpty, state, version);

  @override
  String toString() => isEmpty
      ? 'Selector(empty)'
      : 'Selector(state: $state, version: $version)';
}
