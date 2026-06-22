import 'dart:async';

import 'package:launchdarkly_common_client/src/data_sources/data_manager.dart';
import 'package:launchdarkly_common_client/src/data_sources/data_source_event_handler.dart';
import 'package:launchdarkly_common_client/src/data_sources/data_source_manager.dart';
import 'package:launchdarkly_common_client/src/data_sources/data_source_status_manager.dart';
import 'package:launchdarkly_common_client/src/flag_manager/flag_manager.dart';
import 'package:launchdarkly_common_client/src/offline_detail.dart';
import 'package:launchdarkly_common_client/src/resolved_connection_mode.dart';
import 'package:launchdarkly_dart_common/launchdarkly_dart_common.dart';
import 'package:test/test.dart';

/// A data source manager with no factories. Its identify is a no-op
/// connection-wise (no factory builds a source), which is all these tests
/// need: they exercise the data manager's own logic, not the connection.
DataSourceManager _managerWithoutFactories() {
  final logger = LDLogger(level: LDLogLevel.none);
  final statusManager = DataSourceStatusManager();
  return DataSourceManager(
    statusManager: statusManager,
    dataSourceEventHandler: DataSourceEventHandler(
        flagManager: FlagManager(
            sdkKey: 'sdk-key', maxCachedContexts: 5, logger: logger),
        statusManager: statusManager,
        logger: logger),
    logger: logger,
  );
}

LDContext _ctx(String key) => LDContextBuilder().kind('user', key).build();

void main() {
  group('FDv2DataManager', () {
    test('clears the selector on a context change but not when it repeats', () {
      var clears = 0;
      final manager =
          FDv2DataManager(_managerWithoutFactories(), () => clears++);

      // The returned futures never complete (no factory delivers data); we
      // only care that the clear-selector decision fires correctly.
      unawaited(manager.identify(_ctx('a'), waitForNetworkResults: false));
      unawaited(manager.identify(_ctx('a'), waitForNetworkResults: false));
      unawaited(manager.identify(_ctx('b'), waitForNetworkResults: false));
      unawaited(manager.identify(_ctx('a'), waitForNetworkResults: false));

      // a (first), b, a-again -> 3 clears. The repeated 'a' keeps its selector.
      expect(clears, 3);
    });

    test(
        'clears the selector on a context change regardless of intervening '
        'mode switches', () {
      // The clear is driven at identify time, not by the data source factory,
      // so a mode switch between identifies (e.g. going offline) cannot leave
      // a stale selector behind for the next context. Mode switches go through
      // DataSourceManager.setMode and never reach this manager, so they do not
      // clear the selector themselves.
      var clears = 0;
      final dataSourceManager = _managerWithoutFactories();
      final manager = FDv2DataManager(dataSourceManager, () => clears++);

      unawaited(manager.identify(_ctx('a'), waitForNetworkResults: false));
      dataSourceManager.setMode(const ResolvedOffline(OfflineSetOffline()));
      unawaited(manager.identify(_ctx('b'), waitForNetworkResults: false));
      dataSourceManager.setMode(const ResolvedStreaming());

      // Clear fired for 'a' and 'b'; the offline/online switches did not.
      expect(clears, 2);
    });
  });
}
