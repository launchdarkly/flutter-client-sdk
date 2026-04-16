/// An opaque selector representing the SDK's current payload state and
/// version. The [state] string is sent back to the server as the `basis`
/// query parameter to enable delta-based updates.
final class Selector {
  /// An empty selector indicating no known state.
  static const Selector empty = Selector._(state: '', version: 0);

  /// The opaque state string from the server.
  final String state;

  /// The payload version associated with this selector.
  final int version;

  const Selector._({required this.state, required this.version});

  /// Creates a selector from a server-provided [state] string and
  /// payload [version]. Returns [empty] if [state] is null or empty.
  factory Selector.from(String? state, {int version = 0}) {
    if (state == null || state.isEmpty) {
      return empty;
    }
    return Selector._(state: state, version: version);
  }

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
