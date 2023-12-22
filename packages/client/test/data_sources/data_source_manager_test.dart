import 'dart:async';

import 'package:launchdarkly_dart_client/ld_client.dart';
import 'package:launchdarkly_dart_client/src/data_sources/data_source.dart';
import 'package:launchdarkly_dart_client/src/data_sources/data_source_event_handler.dart';
import 'package:launchdarkly_dart_client/src/data_sources/data_source_manager.dart';
import 'package:launchdarkly_dart_client/src/data_sources/data_source_status.dart';
import 'package:launchdarkly_dart_client/src/data_sources/data_source_status_manager.dart';
import 'package:launchdarkly_dart_client/src/flag_manager/flag_manager.dart';
import 'package:test/test.dart';

final class MockDataSource implements DataSource {
  final StreamController<DataSourceEvent> controller = StreamController();

  bool startCalled = false;
  bool stopCalled = false;

  @override
  Stream<DataSourceEvent> get events => controller.stream;

  @override
  void start() {
    startCalled = true;
    controller.sink.add(DataEvent('put', '{}'));
  }

  @override
  void stop() {
    stopCalled = true;
  }
}

Map<ConnectionMode, DataSourceFactory> defaultFactories(
    Map<ConnectionMode, MockDataSource> dataSources,
    {bool withBackground = false}) {
  final factories = {
    ConnectionMode.foregroundStreaming: (context) {
      final dataSource = MockDataSource();
      dataSources[ConnectionMode.foregroundStreaming] = dataSource;
      return dataSource;
    },
    ConnectionMode.foregroundPolling: (context) {
      final dataSource = MockDataSource();
      dataSources[ConnectionMode.foregroundPolling] = dataSource;
      return dataSource;
    }
  };
  if (withBackground) {
    factories[ConnectionMode.backgroundPolling] = (context) {
      final dataSource = MockDataSource();
      dataSources[ConnectionMode.backgroundPolling] = dataSource;
      return dataSource;
    };
  }
  return factories;
}

DataSourceManager makeManager(LDContext context,
    Map<ConnectionMode, DataSourceFactory> factories,
    {DataSourceStatusManager? inStatusManager}) {
  final statusManager = inStatusManager ?? DataSourceStatusManager();
  final logger = LDLogger();
  final flagManager =
  FlagManager(sdkKey: 'sdk-key', maxCachedContexts: 5, logger: logger);
  final dataSourceEventHandler = DataSourceEventHandler(
      context: context,
      flagManager: flagManager,
      statusManager: statusManager,
      logger: logger);
  final manager = DataSourceManager(
      statusManager: statusManager,
      dataSourceEventHandler: dataSourceEventHandler,
      logger: logger,
      dataSourceFactories: factories);
  return manager;
}

void main() {
  test('it sets up an initial connection on start', () {
    final dataSources = <ConnectionMode, MockDataSource>{};
    final context = LDContextBuilder().kind('user', 'bob').build();
    final manager = makeManager(context, defaultFactories(dataSources));

    manager.identify(context);
    final createdDataSource = dataSources[ConnectionMode.foregroundStreaming];
    expect(createdDataSource, isNotNull);
    expect(createdDataSource!.controller.hasListener, isTrue);
    expect(createdDataSource.startCalled, isTrue);
    expect(createdDataSource.stopCalled, isFalse);
  });

  test('it forwards events to the data source event handler', () {
    final statusManager = DataSourceStatusManager(stamper: () => DateTime(1));
    final dataSources = <ConnectionMode, MockDataSource>{};
    final context = LDContextBuilder().kind('user', 'bob').build();
    final manager = makeManager(context, defaultFactories(dataSources),
        inStatusManager: statusManager);

    manager.identify(context);

    expectLater(
        statusManager.changes,
        emits(
          DataSourceStatus(
              state: DataSourceState.valid, stateSince: DateTime(1)),
        ));
  });

  test('it can transition to offline and tear-down the previous connection',
          () {
        final dataSources = <ConnectionMode, MockDataSource>{};
        final context = LDContextBuilder().kind('user', 'bob').build();
        final manager = makeManager(context, defaultFactories(dataSources));

        manager.identify(context);
        manager.setMode(ConnectionMode.offline);
        final createdDataSource = dataSources[ConnectionMode
            .foregroundStreaming];
        expect(createdDataSource, isNotNull);
        expect(createdDataSource!.controller.hasListener, isFalse);
        expect(createdDataSource.startCalled, isTrue);
        expect(createdDataSource.stopCalled, isTrue);
      });

  test('it can transition from streaming to polling', () {
    final dataSources = <ConnectionMode, MockDataSource>{};
    final context = LDContextBuilder().kind('user', 'bob').build();
    final manager = makeManager(context, defaultFactories(dataSources));

    manager.identify(context);
    manager.setMode(ConnectionMode.foregroundPolling);
    final streamingDataSource = dataSources[ConnectionMode.foregroundStreaming];
    expect(streamingDataSource, isNotNull);
    expect(streamingDataSource!.controller.hasListener, isFalse);
    expect(streamingDataSource.startCalled, isTrue);
    expect(streamingDataSource.stopCalled, isTrue);

    final pollingDataSource = dataSources[ConnectionMode.foregroundPolling];
    expect(pollingDataSource, isNotNull);
    expect(pollingDataSource!.controller.hasListener, isTrue);
    expect(pollingDataSource.startCalled, isTrue);
    expect(pollingDataSource.stopCalled, isFalse);
  });

  test('it can detect when background polling is not supported', () {
    final statusManager = DataSourceStatusManager(stamper: () => DateTime(1));
    final dataSources = <ConnectionMode, MockDataSource>{};
    final context = LDContextBuilder().kind('user', 'bob').build();
    final manager = makeManager(context, defaultFactories(dataSources),
        inStatusManager: statusManager);

    expectLater(
        statusManager.changes,
        emits(
          DataSourceStatus(
              state: DataSourceState.backgroundDisabled,
              stateSince: DateTime(1)),
        ));

    manager.identify(context);

    manager.setMode(ConnectionMode.backgroundPolling);
    final createdDataSource = dataSources[ConnectionMode.foregroundStreaming];
    expect(createdDataSource, isNotNull);
    expect(createdDataSource!.controller.hasListener, isFalse);
    expect(createdDataSource.startCalled, isTrue);
    expect(createdDataSource.stopCalled, isTrue);
  });

  test('it can transition to network unavailable', () {
    final statusManager = DataSourceStatusManager(stamper: () => DateTime(1));
    final dataSources = <ConnectionMode, MockDataSource>{};
    final context = LDContextBuilder().kind('user', 'bob').build();
    final manager = makeManager(context, defaultFactories(dataSources),
        inStatusManager: statusManager);

    expectLater(
        statusManager.changes,
        emits(
          DataSourceStatus(
              state: DataSourceState.networkUnavailable,
              stateSince: DateTime(1)),
        ));

    manager.identify(context);

    manager.setMode(ConnectionMode.networkUnavailable);
    final createdDataSource = dataSources[ConnectionMode.foregroundStreaming];
    expect(createdDataSource, isNotNull);
    expect(createdDataSource!.controller.hasListener, isFalse);
    expect(createdDataSource.startCalled, isTrue);
    expect(createdDataSource.stopCalled, isTrue);
  });

  test('it can transition to background polling', () {
    final dataSources = <ConnectionMode, MockDataSource>{};
    final context = LDContextBuilder().kind('user', 'bob').build();
    final manager = makeManager(
        context, defaultFactories(dataSources, withBackground: true));

    manager.identify(context);

    manager.setMode(ConnectionMode.backgroundPolling);
    final streamingDataSource = dataSources[ConnectionMode.foregroundStreaming];
    expect(streamingDataSource, isNotNull);
    expect(streamingDataSource!.controller.hasListener, isFalse);
    expect(streamingDataSource.startCalled, isTrue);
    expect(streamingDataSource.stopCalled, isTrue);

    final backgroundPolling = dataSources[ConnectionMode.backgroundPolling];
    expect(backgroundPolling, isNotNull);
    expect(backgroundPolling!.controller.hasListener, isTrue);
    expect(backgroundPolling.startCalled, isTrue);
    expect(backgroundPolling.stopCalled, isFalse);
  });

  test('it restarts the data source on bad data', () async {
    final statusManager = DataSourceStatusManager(stamper: () => DateTime(1));
    final dataSources = <ConnectionMode, MockDataSource>{};
    final context = LDContextBuilder().kind('user', 'bob').build();
    final manager = makeManager(context, defaultFactories(dataSources),
        inStatusManager: statusManager);

    manager.identify(context);
    final createdDataSource = dataSources[ConnectionMode.foregroundStreaming];

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
                time: DateTime(1)))
    );

    expect(createdDataSource.controller.hasListener, isFalse);
    expect(createdDataSource.startCalled, isTrue);
    expect(createdDataSource.stopCalled, isTrue);

    final createdDataSource2 = dataSources[ConnectionMode.foregroundStreaming];

    expect(createdDataSource2, isNotNull);
    expect(createdDataSource2!.controller.hasListener, isTrue);
    expect(createdDataSource2.startCalled, isTrue);
    expect(createdDataSource2.stopCalled, isFalse);
  });
}
