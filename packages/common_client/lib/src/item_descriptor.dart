import 'package:launchdarkly_dart_common/launchdarkly_dart_common.dart';

/// An item descriptor is an abstraction that allows for Flag data to be
/// handled using the same type in both a put or a patch.
final class ItemDescriptor {
  /// An item, even a placeholder, must have a version. In the case of a
  /// non-placeholder this data is duplicated in the flag.
  final int version;

  /// The flag, or null if this is a placeholder item.
  final LDEvaluationResult? flag;

  const ItemDescriptor({required this.version, this.flag});

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is ItemDescriptor && version == other.version && flag == other.flag;

  @override
  int get hashCode => version.hashCode ^ flag.hashCode;

  @override
  String toString() {
    return 'ItemDescriptor{version: $version, flag: $flag}';
  }
}
