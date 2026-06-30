import 'dart:async';

import 'package:launchdarkly_common_client/launchdarkly_common_client.dart';
import 'package:launchdarkly_common_client/src/data_sources/data_source.dart';
import 'package:launchdarkly_common_client/src/data_sources/data_source_event_handler.dart';
import 'package:launchdarkly_common_client/src/data_sources/data_source_manager.dart';
import 'package:launchdarkly_common_client/src/data_sources/data_source_status.dart';
import 'package:launchdarkly_common_client/src/data_sources/data_source_status_manager.dart';
import 'package:launchdarkly_common_client/src/data_sources/fdv2/payload.dart';
import 'package:launchdarkly_common_client/src/data_sources/fdv2/selector.dart';
import 'package:launchdarkly_common_client/src/flag_manager/flag_manager.dart';
import 'package:launchdarkly_common_client/src/item_descriptor.dart';
import 'package:launchdarkly_dart_common/launchdarkly_dart_common.dart';
import 'package:test/test.dart';

final class MockDataSource implements DataSource {
  final StreamController<DataSourceEvent> controller = StreamController();
  final List<DataSourceEvent> _startEvents;

  bool startCalled = false;
  bool stopCalled = false;
  bool restartCalled = false;

  MockDataSource({List<DataSourceEvent>? startEvents})
      : _startEvents = startEvents ?? [DataEvent('put', '{}')];

  @override
  Stream<DataSourceEvent> get events => controller.stream;

  @override
  void start() {
    startCalled = true;
    for (final event in _startEvents) {
      controller.sink.add(event);
    }
  }

  @override
  void stop() {
    stopCalled = true;
    controller.close();
  }

  @override
  void restart() {
    restartCalled = true;
    Future.delayed(Duration(milliseconds: 10))
        .then((_) => controller.sink.add(DataEvent('put', '{}')));
  }
}

Map<FDv2ConnectionMode, DataSourceFactory> defaultFactories(
    Map<FDv2ConnectionMode, MockDataSource> dataSources) {
  return {
    const FDv2Streaming(): (context) {
      final dataSource = MockDataSource();
      dataSources[const FDv2Streaming()] = dataSource;
      return dataSource;
    },
    const FDv2Polling(): (context) {
      final dataSource = MockDataSource();
      dataSources[const FDv2Polling()] = dataSource;
      return dataSource;
    },
    const FDv2Background(): (context) {
      final dataSource = MockDataSource();
      dataSources[const FDv2Background()] = dataSource;
      return dataSource;
    },
  };
}

DataSourceManager makeManager(
    LDContext context, Map<FDv2ConnectionMode, DataSourceFactory> factories,
    {DataSourceStatusManager? inStatusManager}) {
  final statusManager = inStatusManager ?? DataSourceStatusManager();
  final logger = LDLogger();
  final flagManager =
      FlagManager(sdkKey: 'sdk-key', maxCachedContexts: 5, logger: logger);
  final dataSourceEventHandler = DataSourceEventHandler(
      flagManager: flagManager, statusManager: statusManager, logger: logger);
  final manager = DataSourceManager(
      statusManager: statusManager,
      dataSourceEventHandler: dataSourceEventHandler,
      logger: logger);

  manager.setFactories(factories);
  return manager;
}

void main() {
  test('it sets up an initial connection on start', () async {
    final dataSources = <FDv2ConnectionMode, MockDataSource>{};
    final context = LDContextBuilder().kind('user', 'bob').build();
    final manager = makeManager(context, defaultFactories(dataSources));
    final completer = Completer<void>();

    manager.identify(context, completer);
    final createdDataSource = dataSources[const FDv2Streaming()];
    expect(createdDataSource, isNotNull);
    expect(createdDataSource!.controller.hasListener, isTrue);
    expect(createdDataSource.startCalled, isTrue);
    expect(createdDataSource.stopCalled, isFalse);
    await completer.future;
  });

  test('it forwards events to the data source event handler', () {
    final statusManager = DataSourceStatusManager(stamper: () => DateTime(1));
    final dataSources = <FDv2ConnectionMode, MockDataSource>{};
    final context = LDContextBuilder().kind('user', 'bob').build();
    final manager = makeManager(context, defaultFactories(dataSources),
        inStatusManager: statusManager);
    final completer = Completer<void>();

    manager.identify(context, completer);

    expectLater(
        statusManager.changes,
        emits(
          DataSourceStatus(
              state: DataSourceState.valid, stateSince: DateTime(1)),
        ));
  });

  test('it applies an FDv2 payload event and completes identify', () async {
    final statusManager = DataSourceStatusManager(stamper: () => DateTime(1));
    final context = LDContextBuilder().kind('user', 'bob').build();
    final changeSet = ChangeSet(
        selector: const Selector(state: 'state-1', version: 1),
        type: PayloadType.full,
        updates: {
          'flag-a': ItemDescriptor(
            version: 3,
            flag: LDEvaluationResult(
              version: 3,
              detail: LDEvaluationDetail(
                  LDValue.ofBool(true), 0, LDEvaluationReason.off()),
            ),
          ),
        });
    final factories = <FDv2ConnectionMode, DataSourceFactory>{
      const FDv2Streaming(): (_) =>
          MockDataSource(startEvents: [PayloadEvent(changeSet)]),
      const FDv2Polling(): (_) => MockDataSource(),
      const FDv2Background(): (_) => MockDataSource(),
    };
    final manager =
        makeManager(context, factories, inStatusManager: statusManager);

    expectLater(
        statusManager.changes,
        emits(DataSourceStatus(
            state: DataSourceState.valid, stateSince: DateTime(1))));

    final completer = Completer<void>();
    manager.identify(context, completer);

    // The network payload (carrying a selector) reaches handlePayload, which
    // applies the change set; the manager marks the source valid and
    // completes the pending identify. (A dropped/no-op payload would leave
    // the identify hanging.)
    await completer.future;
  });

  test('a no-change payload after an interruption restores valid', () async {
    final statusManager = DataSourceStatusManager(stamper: () => DateTime(1));
    final context = LDContextBuilder().kind('user', 'bob').build();
    const networkBasis = ChangeSet(
        selector: Selector(state: 'state-1', version: 1),
        type: PayloadType.full,
        updates: {});
    const noChange = ChangeSet(type: PayloadType.none, updates: {});
    final factories = <FDv2ConnectionMode, DataSourceFactory>{
      const FDv2Streaming(): (_) => MockDataSource(startEvents: [
            // Healthy connection delivers basis data, then drops, then
            // reconnects and reports no changes.
            PayloadEvent(networkBasis),
            StatusEvent(ErrorKind.networkError, null, 'connection dropped'),
            PayloadEvent(noChange),
          ]),
      const FDv2Polling(): (_) => MockDataSource(),
      const FDv2Background(): (_) => MockDataSource(),
    };
    final manager =
        makeManager(context, factories, inStatusManager: statusManager);

    final completer = Completer<void>();
    manager.identify(context, completer);
    await completer.future;
    await pumpEventQueue();

    expect(statusManager.status.state, DataSourceState.valid,
        reason: 'a healthy reconnect reporting no changes carries no selector, '
            'but it is still a server response and must restore valid');
  });

  test('it can transition to offline and tear-down the previous connection',
      () {
    final statusManager = DataSourceStatusManager(stamper: () => DateTime(1));
    final dataSources = <FDv2ConnectionMode, MockDataSource>{};
    final context = LDContextBuilder().kind('user', 'bob').build();
    final manager = makeManager(context, defaultFactories(dataSources),
        inStatusManager: statusManager);
    final completer = Completer<void>();

    manager.identify(context, completer);
    manager.setMode(const ResolvedOffline(OfflineSetOffline()));
    expect(statusManager.status.state, DataSourceState.setOffline);
    final createdDataSource = dataSources[const FDv2Streaming()];
    expect(createdDataSource, isNotNull);
    expect(createdDataSource!.controller.hasListener, isFalse);
    expect(createdDataSource.startCalled, isTrue);
    expect(createdDataSource.stopCalled, isTrue);
  });

  test('offline with OfflineNetworkUnavailable sets networkUnavailable status',
      () {
    final statusManager = DataSourceStatusManager(stamper: () => DateTime(1));
    final dataSources = <FDv2ConnectionMode, MockDataSource>{};
    final context = LDContextBuilder().kind('user', 'bob').build();
    final manager = makeManager(context, defaultFactories(dataSources),
        inStatusManager: statusManager);
    final completer = Completer<void>();

    manager.identify(context, completer);
    manager.setMode(const ResolvedOffline(OfflineNetworkUnavailable()));
    expect(statusManager.status.state, DataSourceState.networkUnavailable);
  });

  test('offline with OfflineBackgroundDisabled sets backgroundDisabled', () {
    final statusManager = DataSourceStatusManager(stamper: () => DateTime(1));
    final dataSources = <FDv2ConnectionMode, MockDataSource>{};
    final context = LDContextBuilder().kind('user', 'bob').build();
    final manager = makeManager(context, defaultFactories(dataSources),
        inStatusManager: statusManager);
    final completer = Completer<void>();

    manager.identify(context, completer);
    manager.setMode(const ResolvedOffline(OfflineBackgroundDisabled()));
    expect(statusManager.status.state, DataSourceState.backgroundDisabled);
  });

  test('it can transition from streaming to polling', () {
    final dataSources = <FDv2ConnectionMode, MockDataSource>{};
    final context = LDContextBuilder().kind('user', 'bob').build();
    final manager = makeManager(context, defaultFactories(dataSources));
    final completer = Completer<void>();

    manager.identify(context, completer);
    manager.setMode(const ResolvedPolling());
    final streamingDataSource = dataSources[const FDv2Streaming()];
    expect(streamingDataSource, isNotNull);
    expect(streamingDataSource!.controller.hasListener, isFalse);
    expect(streamingDataSource.startCalled, isTrue);
    expect(streamingDataSource.stopCalled, isTrue);

    final pollingDataSource = dataSources[const FDv2Polling()];
    expect(pollingDataSource, isNotNull);
    expect(pollingDataSource!.controller.hasListener, isTrue);
    expect(pollingDataSource.startCalled, isTrue);
    expect(pollingDataSource.stopCalled, isFalse);
  });

  test(
      'ResolvedOffline(OfflineNetworkUnavailable) reports networkUnavailable and '
      'stops the data source', () async {
    final statusManager = DataSourceStatusManager(stamper: () => DateTime(1));
    final dataSources = <FDv2ConnectionMode, MockDataSource>{};
    final context = LDContextBuilder().kind('user', 'bob').build();
    final manager = makeManager(context, defaultFactories(dataSources),
        inStatusManager: statusManager);
    final completer = Completer<void>();

    manager.identify(context, completer);
    await completer.future;

    expectLater(
        statusManager.changes,
        emits(
          DataSourceStatus(
              state: DataSourceState.networkUnavailable,
              stateSince: DateTime(1)),
        ));
    manager.setMode(const ResolvedOffline(OfflineNetworkUnavailable()));
    final createdDataSource = dataSources[const FDv2Streaming()];
    expect(createdDataSource, isNotNull);
    expect(createdDataSource!.controller.hasListener, isFalse);
    expect(createdDataSource.startCalled, isTrue);
    expect(createdDataSource.stopCalled, isTrue);
  });

  test('it restarts the data source on bad data', () async {
    final statusManager = DataSourceStatusManager(stamper: () => DateTime(1));
    final dataSources = <FDv2ConnectionMode, MockDataSource>{};
    final context = LDContextBuilder().kind('user', 'bob').build();
    final manager = makeManager(context, defaultFactories(dataSources),
        inStatusManager: statusManager);
    final completer = Completer<void>();

    manager.identify(context, completer);
    final createdDataSource = dataSources[const FDv2Streaming()];

    expect(
        await statusManager.changes.first,
        DataSourceStatus(
            state: DataSourceState.valid, stateSince: DateTime(1)));

    createdDataSource!.controller.sink.add(DataEvent('patch', '#*(*@@'));

    expect(
        await statusManager.changes.first,
        DataSourceStatus(
            state: DataSourceState.interrupted,
            stateSince: DateTime(1),
            lastError: DataSourceStatusErrorInfo(
                kind: ErrorKind.invalidData,
                statusCode: null,
                message: 'Could not parse PATCH message',
                time: DateTime(1))));

    expect(
        await statusManager.changes.first,
        DataSourceStatus(
            state: DataSourceState.valid,
            stateSince: DateTime(1),
            lastError: DataSourceStatusErrorInfo(
                kind: ErrorKind.invalidData,
                statusCode: null,
                message: 'Could not parse PATCH message',
                time: DateTime(1))));

    expect(createdDataSource.controller.hasListener, isTrue);
    expect(createdDataSource.restartCalled, isTrue);
  });

  ChangeSet aChangeSet({Selector selector = Selector.empty}) =>
      ChangeSet(selector: selector, type: PayloadType.full, updates: {
        'flag-a': ItemDescriptor(
          version: 3,
          flag: LDEvaluationResult(
            version: 3,
            detail: LDEvaluationDetail(
                LDValue.ofBool(true), 0, LDEvaluationReason.off()),
          ),
        ),
      });

  test(
      'a cached identify resolves on the first applied payload, which marks '
      'the source valid', () async {
    final statusManager = DataSourceStatusManager(stamper: () => DateTime(1));
    final context = LDContextBuilder().kind('user', 'bob').build();
    final factories = <FDv2ConnectionMode, DataSourceFactory>{
      // A cache load (selector-less full) is enough for a cached identify.
      const FDv2Streaming(): (_) =>
          MockDataSource(startEvents: [PayloadEvent(aChangeSet())]),
      const FDv2Polling(): (_) => MockDataSource(),
      const FDv2Background(): (_) => MockDataSource(),
    };
    final manager =
        makeManager(context, factories, inStatusManager: statusManager);

    final completer = Completer<void>();
    // minimumDataAvailability defaults to cached: resolves on any applied data.
    manager.identify(context, completer);
    await completer.future;

    expect(statusManager.status.state, DataSourceState.valid,
        reason: 'applying any data while online marks the source valid');
  });

  test(
      'a wait-for-network identify resolves on the initialized event, not '
      'earlier data', () async {
    final statusManager = DataSourceStatusManager(stamper: () => DateTime(1));
    final context = LDContextBuilder().kind('user', 'bob').build();
    final factories = <FDv2ConnectionMode, DataSourceFactory>{
      const FDv2Streaming(): (_) => MockDataSource(startEvents: [
            // Cache data, then the orchestrator's initialized signal.
            PayloadEvent(aChangeSet()),
            InitializedEvent(),
          ]),
      const FDv2Polling(): (_) => MockDataSource(),
      const FDv2Background(): (_) => MockDataSource(),
    };
    final manager =
        makeManager(context, factories, inStatusManager: statusManager);

    final completer = Completer<void>();
    manager.identify(context, completer,
        minimumDataAvailability: DataAvailability.fresh);
    await completer.future;

    expect(statusManager.status.state, DataSourceState.valid);
  });

  test('an identify requiring fresh data does not resolve on cache alone',
      () async {
    final context = LDContextBuilder().kind('user', 'bob').build();
    final factories = <FDv2ConnectionMode, DataSourceFactory>{
      const FDv2Streaming(): (_) =>
          MockDataSource(startEvents: [PayloadEvent(aChangeSet())]),
      const FDv2Polling(): (_) => MockDataSource(),
      const FDv2Background(): (_) => MockDataSource(),
    };
    final manager = makeManager(context, factories);

    final completer = Completer<void>();
    manager.identify(context, completer,
        minimumDataAvailability: DataAvailability.fresh);
    await pumpEventQueue();

    expect(completer.isCompleted, isFalse,
        reason:
            'cache data alone must not satisfy a wait-for-network identify');
  });

  test(
      'offline runs its data source to load cache but keeps the offline status',
      () async {
    final statusManager = DataSourceStatusManager(stamper: () => DateTime(1));
    final context = LDContextBuilder().kind('user', 'bob').build();
    var offlineStarted = false;
    final factories = <FDv2ConnectionMode, DataSourceFactory>{
      const FDv2Streaming(): (_) => MockDataSource(),
      const FDv2Polling(): (_) => MockDataSource(),
      const FDv2Background(): (_) => MockDataSource(),
      const FDv2Offline(): (_) {
        offlineStarted = true;
        // Offline cannot reach the network, so the identify resolves on the
        // selector-less cache payload -- but the manager must keep the
        // offline status rather than report valid.
        return MockDataSource(startEvents: [PayloadEvent(aChangeSet())]);
      },
    };
    final manager =
        makeManager(context, factories, inStatusManager: statusManager);

    manager.setMode(const ResolvedOffline(OfflineSetOffline()));
    final completer = Completer<void>();
    manager.identify(context, completer);
    await completer.future;

    expect(offlineStarted, isTrue,
        reason: 'offline is a pipeline mode that runs its data source');
    expect(statusManager.status.state, DataSourceState.setOffline,
        reason: 'a cache load while offline must not report valid');
  });
}
