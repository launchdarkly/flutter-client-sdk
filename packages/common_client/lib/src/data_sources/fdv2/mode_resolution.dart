import '../../connection_mode.dart';

/// Inputs for Layer-2 **automatic** mode resolution (lifecycle, network, mode slots).
///
/// When the client holds a connection mode override, the caller should apply
/// that mode directly and **not** invoke [resolveConnectionMode].
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

  /// Resolved [ConnectionMode] for this row; may read slots from [state].
  final ConnectionMode Function(ModeState state) resolve;

  const ModeResolutionEntry({required this.predicate, required this.resolve});
}

/// First matching row in [table] wins. If none match, returns
/// [state.foregroundConnectionMode].
///
/// Only for **automatic** resolution; do not call when an explicit connection
/// mode override is active (apply the override outside this API).
ConnectionMode resolveConnectionMode(
  List<ModeResolutionEntry> table,
  ModeState state,
) {
  for (final entry in table) {
    if (entry.predicate(state)) {
      return entry.resolve(state);
    }
  }
  return state.foregroundConnectionMode;
}

/// Default ordered table for Flutter mobile. When [ModeState.runInBackground]
/// is false while in the background, resolves to offline;
/// otherwise the background row uses [ModeState.backgroundConnectionMode]
/// (CONNMODE §2.2.1: Flutter default for that slot is [ConnectionMode.offline]).
List<ModeResolutionEntry> flutterDefaultResolutionTable() {
  return const [
    ModeResolutionEntry(
      predicate: _networkDown,
      resolve: _offline,
    ),
    ModeResolutionEntry(
      predicate: _backgroundWithoutUpdates,
      resolve: _offline,
    ),
    ModeResolutionEntry(
      predicate: _inBackground,
      resolve: _backgroundSlot,
    ),
    ModeResolutionEntry(
      predicate: _alwaysTrue,
      resolve: _foregroundSlot,
    ),
  ];
}

ConnectionMode _offline(ModeState s) => ConnectionMode.offline;

bool _networkDown(ModeState s) => !s.networkAvailable;

bool _backgroundWithoutUpdates(ModeState s) =>
    !s.inForeground && !s.runInBackground;

bool _inBackground(ModeState s) => !s.inForeground;

ConnectionMode _backgroundSlot(ModeState s) => s.backgroundConnectionMode;

bool _alwaysTrue(ModeState s) => true;

ConnectionMode _foregroundSlot(ModeState s) => s.foregroundConnectionMode;
