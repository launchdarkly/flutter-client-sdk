import 'dart:async';

import 'package:launchdarkly_common_client/src/data_sources/data_manager.dart';
import 'package:launchdarkly_common_client/src/data_sources/data_source.dart';
import 'package:launchdarkly_common_client/src/data_sources/data_source_event_handler.dart';
import 'package:launchdarkly_common_client/src/data_sources/data_source_status.dart';
import 'package:launchdarkly_common_client/src/data_sources/data_source_manager.dart';
import 'package:launchdarkly_common_client/src/data_sources/data_source_status_manager.dart';
import 'package:launchdarkly_common_client/src/fdv2_connection_mode.dart';
import 'package:launchdarkly_common_client/src/flag_manager/flag_manager.dart';
import 'package:launchdarkly_common_client/src/offline_detail.dart';
import 'package:launchdarkly_common_client/src/persistence/persistence.dart';
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

/// An FDv1 data manager over [persistence]. Each data source it creates sends
/// [startEvents] when it starts, and is added to [dataSources].
(FDv1DataManager, FlagManager) _fdv1Manager(
    Persistence persistence, List<MockDataSource> dataSources,
    {List<DataSourceEvent>? startEvents}) {
  final logger = LDLogger(level: LDLogLevel.none);
  final statusManager = DataSourceStatusManager();
  final flagManager = FlagManager(
      persistence: persistence,
      sdkKey: 'sdk-key',
      maxCachedContexts: 5,
      logger: logger);
  final dataSourceManager = DataSourceManager(
      statusManager: statusManager,
      dataSourceEventHandler: DataSourceEventHandler(
          flagManager: flagManager,
          statusManager: statusManager,
          logger: logger),
      logger: logger);
  dataSourceManager.setFactories({
    const FDv2Streaming(): (_) {
      final dataSource = MockDataSource(startEvents: startEvents);
      dataSources.add(dataSource);
      return dataSource;
    },
  });
  return (FDv1DataManager(dataSourceManager, flagManager), flagManager);
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
      final persistence = GatedPersistence(Future.value());
      final dataSources = <MockDataSource>[];
      final (manager, _) = _fdv1Manager(persistence, dataSources);
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

    test('cancelling an identify ends its wait during the cache read',
        () async {
      // The cache read never finishes.
      final persistence = GatedPersistence(Completer<void>().future);
      final (manager, _) = _fdv1Manager(persistence, [], startEvents: []);
      final cancellation = Completer<void>();

      final identified = manager.identify(_ctx('a'),
          waitForNetworkResults: true, cancelled: cancellation.future);
      cancellation.complete();

      // The identify completes while the cache read waits.
      await identified;
    });

    test('a cache read that finishes after cancellation does not apply',
        () async {
      final gate = Completer<void>();
      final persistence = GatedPersistence(gate.future);
      persistence.storage['LaunchDarkly_${encodePersistenceKey('sdk-key')}'] = {
        encodePersistenceKey(_ctx('a').canonicalKey): '{"flagA":{'
            '"version":1,"value":"cached","variation":0,'
            '"reason":{"kind":"OFF"}}}',
      };
      final (manager, flagManager) =
          _fdv1Manager(persistence, [], startEvents: []);
      final cancellation = Completer<void>();

      final identified = manager.identify(_ctx('a'),
          waitForNetworkResults: false, cancelled: cancellation.future);
      cancellation.complete();
      await identified;
      // The cache read finishes after the cancellation.
      gate.complete();
      await pumpEventQueue();

      // The cached flags do not apply.
      expect(flagManager.getAll(), isEmpty);
    });

    test('a cache read applies its flags', () async {
      final persistence = GatedPersistence(Future.value());
      persistence.storage['LaunchDarkly_${encodePersistenceKey('sdk-key')}'] = {
        encodePersistenceKey(_ctx('a').canonicalKey): '{"flagA":{'
            '"version":1,"value":"cached","variation":0,'
            '"reason":{"kind":"OFF"}}}',
      };
      final (manager, flagManager) =
          _fdv1Manager(persistence, [], startEvents: []);

      await manager.identify(_ctx('a'),
          waitForNetworkResults: false, cancelled: _neverCancelled);

      expect(flagManager.getAll(), contains('flagA'));
    });

    test('a shutdown after a cancelled identify is not an uncaught error',
        () async {
      // The cache read never finishes.
      final persistence = GatedPersistence(Completer<void>().future);
      // The data source shuts down as soon as it starts.
      final (manager, _) = _fdv1Manager(persistence, [], startEvents: [
        StatusEvent(ErrorKind.unknown, null, 'stopped', shutdown: true),
      ]);
      final cancellation = Completer<void>();

      final identified = manager.identify(_ctx('a'),
          waitForNetworkResults: true, cancelled: cancellation.future);
      cancellation.complete();
      await identified;
      // Let the shutdown reach the identify's completer.
      await pumpEventQueue();
    });
  });
}
