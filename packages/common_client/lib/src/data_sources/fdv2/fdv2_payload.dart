/// The type of payload transfer.
enum PayloadType {
  /// The updates represent the complete state and replace everything.
  full,

  /// The updates are incremental changes to apply.
  partial,

  /// No changes are needed; the SDK is up-to-date.
  none,
}

/// A single update within a payload.
final class Update {
  /// The kind of object (e.g., 'flag-eval' for client-side).
  final String kind;

  /// The key identifying this object.
  final String key;

  /// The version of this update envelope.
  final int version;

  /// The object data, or null if this is a deletion.
  final Map<String, dynamic>? object;

  /// True if this update represents a deletion.
  final bool deleted;

  const Update({
    required this.kind,
    required this.key,
    required this.version,
    this.object,
    this.deleted = false,
  });

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is Update &&
          kind == other.kind &&
          key == other.key &&
          version == other.version &&
          deleted == other.deleted;

  @override
  int get hashCode =>
      kind.hashCode ^ key.hashCode ^ version.hashCode ^ deleted.hashCode;

  @override
  String toString() =>
      'Update(kind: $kind, key: $key, version: $version, deleted: $deleted)';
}

/// A complete payload emitted by the protocol handler.
final class Payload {
  /// The version of this payload.
  final int version;

  /// The opaque selector state. Present when the payload comes from an
  /// authoritative (network) source. Null for cached data.
  final String? state;

  /// Whether this is a full, partial, or no-op payload.
  final PayloadType type;

  /// The list of updates in this payload.
  final List<Update> updates;

  const Payload({
    required this.version,
    this.state,
    required this.type,
    required this.updates,
  });

  @override
  String toString() =>
      'Payload(version: $version, state: $state, type: $type, '
      'updates: ${updates.length})';
}
