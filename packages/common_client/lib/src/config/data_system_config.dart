import '../data_sources/fdv2/mode_definition.dart';

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
  /// Connection mode definitions that override the built-in modes, keyed
  /// by mode name: `streaming`, `polling`, or `background`. A definition
  /// given here replaces the built-in definition for that mode entirely.
  final Map<String, ModeDefinition> customConnectionModes;

  const DataSystemConfig({
    this.customConnectionModes = const {},
  });
}
