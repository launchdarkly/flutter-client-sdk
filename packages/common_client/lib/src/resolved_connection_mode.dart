import 'fdv2_connection_mode.dart';
import 'offline_detail.dart';

/// Unlike [FDv2ConnectionMode] alone, [ResolvedOffline] also carries
/// resolution details such as [OfflineDetail].
sealed class ResolvedConnectionMode {
  const ResolvedConnectionMode();

  /// Underlying mode.
  FDv2ConnectionMode get connectionMode;

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) {
      return true;
    }
    return other is ResolvedConnectionMode &&
        switch ((this, other)) {
          (ResolvedStreaming(), ResolvedStreaming()) => true,
          (ResolvedPolling(), ResolvedPolling()) => true,
          (ResolvedBackground(), ResolvedBackground()) => true,
          (final ResolvedOffline r1, final ResolvedOffline r2) =>
            r1.detail == r2.detail,
          _ => false,
        };
  }

  @override
  int get hashCode => switch (this) {
        ResolvedStreaming() => 1,
        ResolvedPolling() => 2,
        ResolvedBackground() => 3,
        ResolvedOffline(:final detail) => 4 ^ detail.hashCode,
      };
}

final class ResolvedStreaming extends ResolvedConnectionMode {
  const ResolvedStreaming();

  @override
  FDv2ConnectionMode get connectionMode => const FDv2Streaming();
}

final class ResolvedPolling extends ResolvedConnectionMode {
  const ResolvedPolling();

  @override
  FDv2ConnectionMode get connectionMode => const FDv2Polling();
}

final class ResolvedBackground extends ResolvedConnectionMode {
  const ResolvedBackground();

  @override
  FDv2ConnectionMode get connectionMode => const FDv2Background();
}

final class ResolvedOffline extends ResolvedConnectionMode {
  final OfflineDetail detail;

  const ResolvedOffline(this.detail);

  @override
  FDv2ConnectionMode get connectionMode => const FDv2Offline();
}
