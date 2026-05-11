import '../../connection_mode.dart';
import '../../offline_detail.dart';
import '../../resolved_connection_mode.dart';

/// Inputs for Layer-2 **automatic** mode resolution (lifecycle, network, mode slots).
///
/// When the client holds a connection mode override, the caller should apply
/// that mode directly and **not** invoke [resolveMode].
final class ModeState {
  final bool networkAvailable;

  /// Application lifecycle: true in foreground, false in background.
  final bool inForeground;

  /// When false, the app is treated as not allowed to receive updates while
  /// backgrounded (Flutter `ConnectionManagerConfig.runInBackground` uses the
  /// same flag name and semantics).
  final bool runInBackground;

  /// Configured foreground mode slot (CONNMODE table “foreground” column).
  final ConnectionMode foregroundConnectionMode;

  /// Configured background mode slot when the table selects the background row.
  final ConnectionMode backgroundConnectionMode;

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

  /// Resolved connection mode for this row; may read slots from [state].
  final ResolvedConnectionMode Function(ModeState state) resolve;

  const ModeResolutionEntry({
    required this.predicate,
    required this.resolve,
  });
}

/// First matching row in [table] wins. If none match, maps
/// [state.foregroundConnectionMode] to a [ResolvedConnectionMode].
///
/// Only for **automatic** resolution; do not call when an explicit connection
/// mode override is active (apply the override outside this API).
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

/// Default ordered table for Flutter mobile. When [ModeState.runInBackground]
/// is false while in the background, resolves to offline;
/// otherwise the background row uses [ModeState.backgroundConnectionMode]
/// (CONNMODE §2.2.1: Flutter default for that slot is [ConnectionMode.offline]).
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

ResolvedConnectionMode _resolvedFromConnectionMode(ConnectionMode mode) {
  return switch (mode) {
    ConnectionMode.streaming => const ResolvedStreaming(),
    ConnectionMode.polling => const ResolvedPolling(),
    ConnectionMode.background => const ResolvedBackground(),
    ConnectionMode.offline => const ResolvedOffline(OfflineSetOffline()),
  };
}

bool _networkDown(ModeState s) => !s.networkAvailable;

bool _backgroundWithoutUpdates(ModeState s) =>
    !s.inForeground && !s.runInBackground;

bool _inBackground(ModeState s) => !s.inForeground;

bool _alwaysTrue(ModeState s) => true;
