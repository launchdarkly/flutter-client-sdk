import '../data_sources/fdv2/mode_definition.dart';

/// Identifies a connection mode whose data-source pipeline can be
/// overridden through [DataSystemConfig.connectionModes].
///
/// Only the built-in modes are nameable today: a user can override a
/// built-in mode's pipeline but cannot register a new mode. This is a
/// sealed hierarchy rather than an enum specifically so a custom-mode
/// variant can be added later without changing this surface. The planned
/// extension is a custom variant constructed as
/// `ConnectionModeId.custom('custom-my-mode')`:
///
/// ```dart
/// final class _CustomConnectionMode extends ConnectionModeId {
///   final String name;
///   const _CustomConnectionMode(this.name);
///   // value equality on name so it works as an override-map key
/// }
/// // on ConnectionModeId:
/// //   factory ConnectionModeId.custom(String name) = _CustomConnectionMode;
/// ```
///
/// A custom name must be namespaced (e.g. a `custom-` prefix) so it cannot
/// collide with a current or future built-in mode; the data system would
/// validate the name and reject a collision before using it.
///
/// Note the equality split this implies. The built-in values are `const`
/// singletons and rely on canonical-instance identity, which is what lets
/// a `connectionModes` map of only built-in keys be a `const` map. A
/// custom variant, constructed at runtime, must instead carry value
/// equality on its name to work as a map key, so an override map holding a
/// custom key would be non-`const`. The built-in variant therefore must
/// not override `==`/`hashCode`.
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

/// A built-in connection mode. Instances are the canonical `const`
/// singletons on [ConnectionModeId]; this class is not constructible by
/// users and intentionally keeps identity equality so an override map of
/// built-in keys can be `const`.
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
  /// their built-in definition. Only built-in modes can be named (see
  /// [ConnectionModeId]); custom modes are not supported.
  final Map<ConnectionModeId, ModeDefinition> connectionModes;

  const DataSystemConfig({
    this.connectionModes = const {},
  });
}
