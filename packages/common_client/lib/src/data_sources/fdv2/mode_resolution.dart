import '../../fdv2_connection_mode.dart';
import '../../offline_detail.dart';
import '../../resolved_connection_mode.dart';

/// Inputs for automatic mode resolution (lifecycle, network, mode slots).
final class ModeState {
  /// Whether the network is available.
  final bool networkAvailable;

  /// Application lifecycle: true in foreground, false in background.
  final bool inForeground;

  /// When false, the app is treated as not allowed to receive updates while
  /// backgrounded.
  final bool runInBackground;

  /// Configured foreground mode slot.
  final FDv2ConnectionMode foregroundConnectionMode;

  /// Configured background mode slot when the table selects the background row.
  final FDv2ConnectionMode backgroundConnectionMode;

  const ModeState({
    required this.networkAvailable,
    required this.inForeground,
    required this.runInBackground,
    required this.foregroundConnectionMode,
    required this.backgroundConnectionMode,
  });
}

/// One row in an ordered mode resolution table (first match wins).
final class ModeResolutionEntry {
  final bool Function(ModeState state) predicate;

  final ResolvedConnectionMode Function(ModeState state) resolve;

  const ModeResolutionEntry({
    required this.predicate,
    required this.resolve,
  });
}

/// First matching row in [table] wins. If none match, maps
/// [state.foregroundConnectionMode] to a [ResolvedConnectionMode].
///
ResolvedConnectionMode resolveMode(
  List<ModeResolutionEntry> table,
  ModeState state,
) {
  for (final entry in table) {
    if (entry.predicate(state)) {
      return entry.resolve(state);
    }
  }
  return _resolvedFromConnectionMode(state.foregroundConnectionMode);
}

/// Default ordered table for Flutter.
List<ModeResolutionEntry> flutterDefaultResolutionTable() {
  return const [
    ModeResolutionEntry(
      predicate: _networkDown,
      resolve: _offlineNetworkUnavailable,
    ),
    ModeResolutionEntry(
      predicate: _backgroundWithoutUpdates,
      resolve: _offlineBackgroundDisabled,
    ),
    ModeResolutionEntry(
      predicate: _inBackground,
      resolve: _backgroundSlotResolved,
    ),
    ModeResolutionEntry(
      predicate: _alwaysTrue,
      resolve: _foregroundSlotResolved,
    ),
  ];
}

ResolvedConnectionMode _offlineNetworkUnavailable(ModeState _) =>
    const ResolvedOffline(OfflineNetworkUnavailable());

ResolvedConnectionMode _offlineBackgroundDisabled(ModeState _) =>
    const ResolvedOffline(OfflineBackgroundDisabled());

ResolvedConnectionMode _backgroundSlotResolved(ModeState s) =>
    _resolvedFromConnectionMode(s.backgroundConnectionMode);

ResolvedConnectionMode _foregroundSlotResolved(ModeState s) =>
    _resolvedFromConnectionMode(s.foregroundConnectionMode);

ResolvedConnectionMode _resolvedFromConnectionMode(FDv2ConnectionMode mode) =>
    switch (mode) {
      FDv2Streaming() => const ResolvedStreaming(),
      FDv2Polling() => const ResolvedPolling(),
      FDv2Background() => const ResolvedBackground(),
      FDv2Offline() => const ResolvedOffline(OfflineSetOffline()),
    };

bool _networkDown(ModeState s) => !s.networkAvailable;

bool _backgroundWithoutUpdates(ModeState s) =>
    !s.inForeground && !s.runInBackground;

bool _inBackground(ModeState s) => !s.inForeground;

bool _alwaysTrue(ModeState s) => true;
