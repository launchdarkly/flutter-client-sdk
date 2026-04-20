import 'package:launchdarkly_dart_common/launchdarkly_dart_common.dart';

import 'selector.dart';

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
          deleted == other.deleted &&
          _objectEquals(object, other.object);

  static bool _objectEquals(Map<String, dynamic>? a, Map<String, dynamic>? b) {
    if (a == null) return b == null;
    if (b == null) return false;
    return a.equals(b);
  }

  @override
  int get hashCode => Object.hash(
        kind,
        key,
        version,
        deleted,
        object == null
            ? null
            : Object.hashAllUnordered(
                object!.entries.map((e) => Object.hash(e.key, e.value))),
      );

  @override
  String toString() => 'Update(kind: $kind, key: $key, version: $version, '
      'deleted: $deleted, object: $object)';
}

/// A complete payload emitted by the protocol handler.
final class Payload {
  /// The selector for this payload. Contains the opaque state string
  /// and version from the server. [Selector.empty] when no selector
  /// was provided (e.g., cached data or intent-none).
  final Selector selector;

  /// Whether this is a full, partial, or no-op payload.
  final PayloadType type;

  /// The list of updates in this payload.
  final List<Update> updates;

  const Payload({
    this.selector = Selector.empty,
    required this.type,
    required this.updates,
  });

  @override
  String toString() => 'Payload(selector: $selector, type: $type, '
      'updates: ${updates.length})';
}
