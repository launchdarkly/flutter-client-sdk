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
    test('clears the selector on every identify', () {
      var clears = 0;
      final manager =
          FDv2DataManager(_managerWithoutFactories(), () => clears++);

      // The returned futures never complete (no factory delivers data); we
      // only care that each identify starts fresh.
      unawaited(manager.identify(_ctx('a'), waitForNetworkResults: false));
      unawaited(manager.identify(_ctx('a'), waitForNetworkResults: false));
      unawaited(manager.identify(_ctx('b'), waitForNetworkResults: false));

      // Every identify clears, including re-identifying the same context.
      expect(clears, 3);
    });

    test('mode switches do not clear the selector, only identifies do', () {
      // The clear is driven at identify time. Mode switches reach the data
      // source manager directly (not this manager), so they keep the held
      // selector and resume rather than re-initializing.
      var clears = 0;
      final dataSourceManager = _managerWithoutFactories();
      final manager = FDv2DataManager(dataSourceManager, () => clears++);

      unawaited(manager.identify(_ctx('a'), waitForNetworkResults: false));
      dataSourceManager.setMode(const ResolvedOffline(OfflineSetOffline()));
      unawaited(manager.identify(_ctx('b'), waitForNetworkResults: false));
      dataSourceManager.setMode(const ResolvedStreaming());

      // Two identifies cleared; the offline/streaming switches did not.
      expect(clears, 2);
    });
  });
}
