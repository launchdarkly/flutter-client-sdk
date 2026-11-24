import 'dart:async';

import 'package:launchdarkly_common_client/src/data_sources/data_manager.dart';
import 'package:launchdarkly_common_client/src/data_sources/data_source_event_handler.dart';
import 'package:launchdarkly_common_client/src/data_sources/data_source_manager.dart';
import 'package:launchdarkly_common_client/src/data_sources/data_source_status_manager.dart';
import 'package:launchdarkly_common_client/src/fdv2_connection_mode.dart';
import 'package:launchdarkly_common_client/src/flag_manager/flag_manager.dart';
import 'package:launchdarkly_common_client/src/offline_detail.dart';
import 'package:launchdarkly_common_client/src/resolved_connection_mode.dart';
import 'package:launchdarkly_dart_common/launchdarkly_dart_common.dart';
import 'package:test/test.dart';

import '../mock_persistence.dart';
import 'mock_data_source.dart';

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

/// A cancellation that never happens.
final Future<void> _neverCancelled = Completer<void>().future;

void main() {
  group('FDv2DataManager', () {
    test('clears the selector on every identify', () {
      var clears = 0;
      final manager =
          FDv2DataManager(_managerWithoutFactories(), () => clears++);

      // The returned futures never complete (no factory delivers data); we
      // only care that each identify starts fresh.
      unawaited(manager.identify(_ctx('a'),
          waitForNetworkResults: false, cancelled: _neverCancelled));
      unawaited(manager.identify(_ctx('a'),
          waitForNetworkResults: false, cancelled: _neverCancelled));
      unawaited(manager.identify(_ctx('b'),
          waitForNetworkResults: false, cancelled: _neverCancelled));

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

      unawaited(manager.identify(_ctx('a'),
          waitForNetworkResults: false, cancelled: _neverCancelled));
      dataSourceManager.setMode(const ResolvedOffline(OfflineSetOffline()));
      unawaited(manager.identify(_ctx('b'),
          waitForNetworkResults: false, cancelled: _neverCancelled));
      dataSourceManager.setMode(const ResolvedStreaming());

      // Two identifies cleared; the offline/streaming switches did not.
      expect(clears, 2);
    });

    test('cancelling an identify ends its wait', () async {
      final manager = FDv2DataManager(_managerWithoutFactories(), () {});
      final cancellation = Completer<void>();

      // Identify with no data source to deliver data, and then cancel it.
      final identified = manager.identify(_ctx('a'),
          waitForNetworkResults: true, cancelled: cancellation.future);
      cancellation.complete();

      // The identify completes without data.
      await identified;
    });
  });

  group('FDv1DataManager', () {
    test('stops the previous data source before it loads the cache', () async {
      final logger = LDLogger(level: LDLogLevel.none);
      final statusManager = DataSourceStatusManager();
      final persistence = GatedPersistence(Future.value());
      final flagManager = FlagManager(
          persistence: persistence,
          sdkKey: 'sdk-key',
          maxCachedContexts: 5,
          logger: logger);
      final dataSources = <MockDataSource>[];
      final dataSourceManager = DataSourceManager(
          statusManager: statusManager,
          dataSourceEventHandler: DataSourceEventHandler(
              flagManager: flagManager,
              statusManager: statusManager,
              logger: logger),
          logger: logger);
      dataSourceManager.setFactories({
        const FDv2Streaming(): (_) {
          final dataSource = MockDataSource();
          dataSources.add(dataSource);
          return dataSource;
        },
      });
      final manager = FDv1DataManager(dataSourceManager, flagManager);
      await manager.identify(_ctx('a'),
          waitForNetworkResults: false, cancelled: _neverCancelled);

      final gate = Completer<void>();
      // B's cache read waits on the gate.
      persistence.gate = gate.future;
      unawaited(manager.identify(_ctx('b'),
          waitForNetworkResults: false, cancelled: _neverCancelled));
      await pumpEventQueue();

      // A's data source has stopped.
      expect(dataSources.first.stopCalled, isTrue);
    });
  });
}
