import 'package:launchdarkly_common_client/src/data_sources/fdv2/mode_resolution.dart';
import 'package:launchdarkly_common_client/src/fdv2_connection_mode.dart';
import 'package:launchdarkly_common_client/src/offline_detail.dart';
import 'package:launchdarkly_common_client/src/resolved_connection_mode.dart';
import 'package:test/test.dart';

void main() {
  test(
      'flutter default table: network down yields ResolvedOffline(OfflineNetworkUnavailable)',
      () {
    const state = ModeState(
      networkAvailable: false,
      inForeground: true,
      runInBackground: true,
      foregroundConnectionMode: FDv2ConnectionMode.streaming,
      backgroundConnectionMode: FDv2ConnectionMode.offline,
    );
    final r = resolveMode(
      flutterDefaultResolutionTable(),
      state,
    );
    expect(r, isA<ResolvedOffline>());
    expect((r as ResolvedOffline).detail, isA<OfflineNetworkUnavailable>());
    expect(r.connectionMode, FDv2ConnectionMode.offline);
  });

  test(
      'flutter default table: background without updates yields '
      'ResolvedOffline(OfflineBackgroundDisabled)', () {
    const state = ModeState(
      networkAvailable: true,
      inForeground: false,
      runInBackground: false,
      foregroundConnectionMode: FDv2ConnectionMode.streaming,
      backgroundConnectionMode: FDv2ConnectionMode.offline,
    );
    final r = resolveMode(
      flutterDefaultResolutionTable(),
      state,
    );
    expect(r, isA<ResolvedOffline>());
    expect((r as ResolvedOffline).detail, isA<OfflineBackgroundDisabled>());
  });

  test(
      'flutter default table: background slot offline yields '
      'ResolvedOffline(OfflineBackgroundDisabled), not OfflineSetOffline', () {
    const state = ModeState(
      networkAvailable: true,
      inForeground: false,
      runInBackground: true,
      foregroundConnectionMode: FDv2ConnectionMode.streaming,
      backgroundConnectionMode: FDv2ConnectionMode.offline,
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
      foregroundConnectionMode: FDv2ConnectionMode.polling,
      backgroundConnectionMode: FDv2ConnectionMode.offline,
    );
    final table = flutterDefaultResolutionTable();
    final resolved = resolveMode(table, state);
    expect(resolved, isA<ResolvedPolling>());
    expect(resolved.connectionMode, FDv2ConnectionMode.polling);
  });
}
