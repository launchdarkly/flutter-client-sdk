import '../data_sources/fdv2/mode_definition.dart';

// Maintainer note (not public API): ConnectionModeId is a sealed
// hierarchy rather than an enum so a custom-mode variant can be added
// later without changing this surface. The planned extension is a custom
// variant constructed as `ConnectionModeId.custom('custom-my-mode')`:
//
//   factory ConnectionModeId.custom(String name) = _CustomConnectionMode;
//   final class _CustomConnectionMode extends ConnectionModeId {
//     final String name;
//     const _CustomConnectionMode(this.name);
//     // value equality on name so it works as an override-map key
//   }
//
// A custom name must be namespaced (e.g. a `custom-` prefix) so it cannot
// collide with a current or future built-in mode; validate the name and
// reject a collision before using it.
//
// Equality split: the built-in values are const singletons relying on
// canonical-instance identity, which lets a connectionModes map of only
// built-in keys be a const map. A runtime-constructed custom variant must
// carry value equality, so an override map holding a custom key would be
// non-const. The built-in variant therefore must not override
// `==`/`hashCode`.

/// Identifies a built-in connection mode whose data-source pipeline can be
/// overridden through [DataSystemConfig.connectionModes]: [streaming],
/// [polling], or [background].
sealed class ConnectionModeId {
  const ConnectionModeId();

  /// The built-in streaming mode.
  static const ConnectionModeId streaming = _BuiltInConnectionMode('streaming');

  /// The built-in polling mode.
  static const ConnectionModeId polling = _BuiltInConnectionMode('polling');

  /// The built-in background mode.
  static const ConnectionModeId background =
      _BuiltInConnectionMode('background');
}

final class _BuiltInConnectionMode extends ConnectionModeId {
  final String name;

  const _BuiltInConnectionMode(this.name);

  @override
  String toString() => 'ConnectionModeId.$name';
}

/// Configuration for the FDv2 data system.
///
/// Providing a [DataSystemConfig] (even an empty one) opts the SDK into
/// the FDv2 data acquisition protocol. When absent the SDK uses the
/// FDv1 data sources.
///
/// This feature is not stable, and not subject to any backwards
/// compatibility guarantees or semantic versioning. It is in early
/// access. If you want access to this feature please join the EAP.
final class DataSystemConfig {
  /// Overrides for built-in connection modes. A definition given here
  /// replaces the built-in pipeline for that mode; modes not present keep
  /// their built-in definition.
  final Map<ConnectionModeId, ModeDefinition> connectionModes;

  const DataSystemConfig({
    this.connectionModes = const {},
  });
}
