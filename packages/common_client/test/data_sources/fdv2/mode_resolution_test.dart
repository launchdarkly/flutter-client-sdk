import 'package:launchdarkly_common_client/launchdarkly_common_client.dart';
import 'package:test/test.dart';

void main() {
  test('flutter default table: network down yields ResolvedOffline(OfflineNetworkUnavailable)',
      () {
    const state = ModeState(
      networkAvailable: false,
      inForeground: true,
      runInBackground: true,
      foregroundConnectionMode: ConnectionMode.streaming,
      backgroundConnectionMode: ConnectionMode.offline,
    );
    final r = resolveMode(
      flutterDefaultResolutionTable(),
      state,
    );
    expect(r, isA<ResolvedOffline>());
    expect((r as ResolvedOffline).detail, isA<OfflineNetworkUnavailable>());
    expect(r.connectionMode, ConnectionMode.offline);
  });

  test(
      'flutter default table: background without updates yields '
      'ResolvedOffline(OfflineBackgroundDisabled)',
      () {
    const state = ModeState(
      networkAvailable: true,
      inForeground: false,
      runInBackground: false,
      foregroundConnectionMode: ConnectionMode.streaming,
      backgroundConnectionMode: ConnectionMode.offline,
    );
    final r = resolveMode(
      flutterDefaultResolutionTable(),
      state,
    );
    expect(r, isA<ResolvedOffline>());
    expect((r as ResolvedOffline).detail, isA<OfflineBackgroundDisabled>());
  });

  test('resolveMode foreground slot exposes connectionMode', () {
    const state = ModeState(
      networkAvailable: true,
      inForeground: true,
      runInBackground: true,
      foregroundConnectionMode: ConnectionMode.polling,
      backgroundConnectionMode: ConnectionMode.offline,
    );
    final table = flutterDefaultResolutionTable();
    final resolved = resolveMode(table, state);
    expect(resolved, isA<ResolvedPolling>());
    expect(resolved.connectionMode, ConnectionMode.polling);
  });
}
