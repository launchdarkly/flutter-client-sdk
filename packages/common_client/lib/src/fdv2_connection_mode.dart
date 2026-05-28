/// Enumerates the built-in FDv2 connection modes. Each mode maps to a
/// pipeline of initializers and synchronizers that are active when the SDK
/// is operating in that mode.
///
/// This class is not stable, and not subject to any backwards compatibility
/// guarantees or semantic versioning. It is in early access. If you want
/// access to this feature please join the EAP.
/// https://launchdarkly.com/docs/sdk/features/data-saving-mode
///
/// This type is intentionally a class with private constructor and a closed
/// set of `static const` instances rather than a Dart `enum`. New modes can
/// be added in a future release without forcing downstream `switch`
/// expressions or statements to update.
///
/// Not to be confused with the FDv1 [ConnectionMode] enum
/// (`connection_mode.dart`), which is the public type used by existing
/// SDK configuration and `setMode` APIs. [FDv2ConnectionMode] is an FDv2
/// concept describing the desired data-acquisition pipeline; the FDv1
/// [ConnectionMode] continues to drive existing public APIs.
final class FDv2ConnectionMode {
  /// Foreground streaming mode. Cache + polling initializers, then streaming
  /// with polling fallback. Suitable for mobile foreground and desktop use.
  static const FDv2ConnectionMode streaming =
      FDv2ConnectionMode._('streaming');

  /// Polling-only mode at the configured polling interval.
  static const FDv2ConnectionMode polling = FDv2ConnectionMode._('polling');

  /// Offline mode. Cache initializer only; no synchronizers.
  static const FDv2ConnectionMode offline = FDv2ConnectionMode._('offline');

  /// Mobile background mode. Cache initializer and a reduced-rate polling
  /// synchronizer (one hour by default).
  static const FDv2ConnectionMode background =
      FDv2ConnectionMode._('background');

  final String _name;

  const FDv2ConnectionMode._(this._name);

  @override
  String toString() => _name;
}
