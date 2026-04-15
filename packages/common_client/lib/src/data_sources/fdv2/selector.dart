/// An opaque selector representing the SDK's current payload version.
/// Sent back to the server as the `basis` query parameter to enable
/// delta-based updates.
final class Selector {
  /// An empty selector indicating no known state.
  static const Selector empty = Selector._('');

  /// The opaque state string from the server.
  final String state;

  const Selector._(this.state);

  /// Creates a selector from a server-provided state string.
  /// Returns [empty] if [state] is null or empty.
  factory Selector.from(String? state) {
    if (state == null || state.isEmpty) {
      return empty;
    }
    return Selector._(state);
  }

  bool get isEmpty => state.isEmpty;
  bool get isNotEmpty => state.isNotEmpty;

  @override
  bool operator ==(Object other) =>
      identical(this, other) || other is Selector && state == other.state;

  @override
  int get hashCode => state.hashCode;

  @override
  String toString() => 'Selector($state)';
}
