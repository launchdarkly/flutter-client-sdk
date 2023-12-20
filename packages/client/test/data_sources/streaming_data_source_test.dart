import 'dart:async';

import 'package:launchdarkly_dart_client/ld_client.dart';
import 'package:launchdarkly_dart_client/src/data_sources/data_source_event_handler.dart';
import 'package:launchdarkly_dart_client/src/data_sources/data_source_status.dart';
import 'package:launchdarkly_dart_client/src/data_sources/data_source_status_manager.dart';
import 'package:launchdarkly_dart_client/src/data_sources/streaming_data_source.dart';
import 'package:launchdarkly_dart_client/src/flag_manager/flag_manager.dart';
import 'package:launchdarkly_event_source_client/sse_client.dart';
import 'package:test/test.dart';

(StreamingDataSource, FlagManager, DataSourceStatusManager)
    makeDataSourceForTest(Stream<MessageEvent> mockStream,
        {LDContext? inContext,
        HttpProperties? inProperties,
        bool useReport = false,
        bool withReasons = false,
        Duration? testingInterval,
        Function(Uri, HttpProperties, MessageHandler, ErrorHandler)?
            factoryCallback}) {
  final context = inContext ?? LDContextBuilder().kind('user', 'test').build();
  // We are not testing the data source status manager here, so we just want a
  // fixed time to make events easy to get.
  final statusManager = DataSourceStatusManager(stamper: () => DateTime(1));
  final logger = LDLogger();
  final httpProperties = inProperties ?? HttpProperties();
  const sdkKey = 'dummy-key';
  final flagManager =
      FlagManager(sdkKey: sdkKey, logger: logger, maxCachedContexts: 5);
  final polling = StreamingDataSource(
      credential: sdkKey,
      context: context,
      endpoints: ServiceEndpoints(),
      logger: logger,
      statusManager: statusManager,
      dataSourceEventHandler: DataSourceEventHandler(
          logger: logger,
          context: context,
          flagManager: flagManager,
          statusManager: statusManager),
      dataSourceConfig: StreamingDataSourceConfig(
          withReasons: withReasons, useReport: useReport),
      httpProperties: httpProperties,
      subFactory: (Uri uri, HttpProperties properties, MessageHandler handler,
          ErrorHandler errorHandler) {
        factoryCallback?.call(uri, properties, handler, errorHandler);
        mockStream.handleError(errorHandler);
        return mockStream.listen(handler);
      });

  return (polling, flagManager, statusManager);
}

void main() {
  group('parameters are correctly calculated for the stream subscription', () {
    test('it uses the correct URL without reasons', () {
      final controller = StreamController<MessageEvent>();
      final (dataSource, _, statusManager) =
          makeDataSourceForTest(controller.stream,
              factoryCallback: (uri, properties, handler, errorHandler) {
        expect(uri.toString(),
            'https://clientstream.launchdarkly.com/meval/eyJrZXkiOiJ0ZXN0Iiwia2luZCI6InVzZXIifQ==');
      });

      expectLater(
          statusManager.changes,
          emits(DataSourceStatus(
              state: DataSourceState.valid, stateSince: DateTime(1))));

      dataSource.start();
      controller.sink.add(MessageEvent('put', '{}', null));
    });

    test('it uses the correct URL with reasons', () {
      final controller = StreamController<MessageEvent>();
      final (dataSource, _, statusManager) =
          makeDataSourceForTest(controller.stream, withReasons: true,
              factoryCallback: (uri, properties, handler, errorHandler) {
        expect(uri.toString(),
            'https://clientstream.launchdarkly.com/meval/eyJrZXkiOiJ0ZXN0Iiwia2luZCI6InVzZXIifQ==?withReasons=true');
      });

      expectLater(
          statusManager.changes,
          emits(DataSourceStatus(
              state: DataSourceState.valid, stateSince: DateTime(1))));

      dataSource.start();
      controller.sink.add(MessageEvent('put', '{}', null));
    });

    test('it includes the authorization header', () {
      final controller = StreamController<MessageEvent>();
      final (dataSource, _, statusManager) =
          makeDataSourceForTest(controller.stream, withReasons: true,
              factoryCallback: (uri, properties, handler, errorHandler) {
        expect(properties.baseHeaders['authorization'], 'dummy-key');
      });

      expectLater(
          statusManager.changes,
          emits(DataSourceStatus(
              state: DataSourceState.valid, stateSince: DateTime(1))));

      dataSource.start();
      controller.sink.add(MessageEvent('put', '{}', null));
    });
  });

  test('it cancels the subscription on stop', () {
    bool cancelled = false;
    final controller =
        StreamController<MessageEvent>(onCancel: () => cancelled = true);
    final (dataSource, _, _) =
        makeDataSourceForTest(controller.stream, withReasons: true,
            factoryCallback: (uri, properties, handler, errorHandler) {
      expect(properties.baseHeaders['authorization'], 'dummy-key');
    });

    dataSource.start();
    dataSource.stop();
    expect(cancelled, true);
  });

  test('it restarts the subscription on bad data', () async {
    var cancelCount = 0;
    var listenCount = 0;
    final controller = StreamController<MessageEvent>();
    final (dataSource, _, statusManager) = makeDataSourceForTest(
        controller.stream.asBroadcastStream(
            onCancel: (_) {
              cancelCount++;
            },
            onListen: (_) => listenCount++),
        withReasons: true);

    dataSource.start();
    controller.sink.add(MessageEvent('put', '{}', null));

    await statusManager.changes.first;

    expect(cancelCount, isZero);
    expect(listenCount, 1);

    controller.sink.add(MessageEvent('put', '#*#&', null));

    expect(
        await statusManager.changes.first,
        DataSourceStatus(
            state: DataSourceState.interrupted,
            stateSince: DateTime(1),
            lastError: DataSourceStatusErrorInfo(
                kind: ErrorKind.invalidData,
                statusCode: null,
                message: 'Could not parse PUT message',
                time: DateTime(1))));

    controller.sink.add(MessageEvent('put', '{}', null));

    expect(
        await statusManager.changes.first,
        DataSourceStatus(
            state: DataSourceState.valid,
            stateSince: DateTime(1),
            lastError: DataSourceStatusErrorInfo(
                kind: ErrorKind.invalidData,
                statusCode: null,
                message: 'Could not parse PUT message',
                time: DateTime(1))));

    expect(cancelCount, 1);
    expect(listenCount, 2);
  });

  test('it forwards messages to the data source event handler', () async {
    final controller = StreamController<MessageEvent>();
    final (dataSource, flagManager, _) =
        makeDataSourceForTest(controller.stream);

    dataSource.start();
    controller.sink.add(MessageEvent(
        'put',
        '{"my-boolean-flag":{"version":11,"flagVersion":5,"value":false,"variation":1,'
            '"trackEvents":false},'
            '"killswitch":{"version":10,"flagVersion":4,"value":true,'
            '"variation":0,"trackEvents":false}'
            '}',
        null));

    final firstChange = await flagManager.changes.first;
    expect(firstChange.keys, ['my-boolean-flag', 'killswitch']);
    expect(
        flagManager.get('my-boolean-flag')!.flag!.detail.value.booleanValue(),
        false);
    expect(
        flagManager.get('killswitch')!.flag!.detail.value.booleanValue(), true);

    controller.sink.add(MessageEvent(
        'patch',
        '{"key": "my-boolean-flag", "version": 681, "flagVersion": 53,'
            ' "value": true, "variation": 1, "trackEvents": false}',
        null));

    final secondChange = await flagManager.changes.first;

    expect(secondChange.keys, ['my-boolean-flag']);
    expect(
        flagManager.get('my-boolean-flag')!.flag!.detail.value.booleanValue(),
        true);

    controller.sink.add(MessageEvent(
        'delete', '{"key":"my-boolean-flag","version":682}', null));

    final thirdChange = await flagManager.changes.first;

    expect(thirdChange.keys, ['my-boolean-flag']);
    expect(flagManager.get('my-boolean-flag')!.flag, isNull);
  });
}
