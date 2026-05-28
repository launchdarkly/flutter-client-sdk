/// Identifies a built-in FDv2 connection mode. Each variant maps to a
/// pipeline of initializers and synchronizers that are active when the SDK
/// is operating in that mode.
///
/// This type is not stable, and not subject to any backwards compatibility
/// guarantees or semantic versioning. It is in early access. If you want
/// access to this feature please join the EAP.
/// https://launchdarkly.com/docs/sdk/features/data-saving-mode
///
/// Not to be confused with the FDv1 [ConnectionMode] enum
/// (`connection_mode.dart`), which is the public type used by existing
/// SDK configuration and `setMode` APIs. [FDv2ConnectionMode] is an FDv2
/// concept describing the desired data-acquisition pipeline; the FDv1
/// [ConnectionMode] continues to drive existing public APIs.
sealed class FDv2ConnectionMode {
  const FDv2ConnectionMode();

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) {
      return true;
    }
    return other is FDv2ConnectionMode && other.runtimeType == runtimeType;
  }

  @override
  int get hashCode => runtimeType.hashCode;
}

/// Foreground streaming mode. Cache + polling initializers, then streaming
/// with polling fallback. Suitable for mobile foreground and desktop use.
final class FDv2Streaming extends FDv2ConnectionMode {
  const FDv2Streaming();

  @override
  String toString() => 'streaming';
}

/// Polling-only mode at the configured polling interval.
final class FDv2Polling extends FDv2ConnectionMode {
  const FDv2Polling();

  @override
  String toString() => 'polling';
}

/// Offline mode. Cache initializer only; no synchronizers.
final class FDv2Offline extends FDv2ConnectionMode {
  const FDv2Offline();

  @override
  String toString() => 'offline';
}

/// Mobile background mode. Cache initializer and a reduced-rate polling
/// synchronizer (one hour by default).
final class FDv2Background extends FDv2ConnectionMode {
  const FDv2Background();

  @override
  String toString() => 'background';
}
