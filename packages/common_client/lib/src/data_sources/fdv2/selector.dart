/// An opaque selector representing the SDK's current payload state and
/// version. The [state] string is sent back to the server as the `basis`
/// query parameter to enable delta-based updates.
///
/// An empty selector ([isEmpty]) means no known state — equivalent to
/// not having a selector at all.
final class Selector {
  /// An empty selector indicating no known state.
  static const Selector empty = Selector(state: '', version: 0);

  /// The opaque state string from the server.
  final String state;

  /// The payload version associated with this selector.
  final int version;

  const Selector({required this.state, required this.version});

  bool get isEmpty => state.isEmpty;
  bool get isNotEmpty => state.isNotEmpty;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is Selector && state == other.state && version == other.version;

  @override
  int get hashCode => state.hashCode ^ version.hashCode;

  @override
  String toString() => 'Selector(state: $state, version: $version)';
}
