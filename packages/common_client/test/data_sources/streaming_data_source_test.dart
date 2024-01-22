import 'dart:async';

import 'package:launchdarkly_common_client/launchdarkly_common_client.dart';
import 'package:launchdarkly_common_client/src/config/data_source_config.dart';
import 'package:launchdarkly_common_client/src/data_sources/data_source.dart';
import 'package:launchdarkly_common_client/src/data_sources/data_source_event_handler.dart';
import 'package:launchdarkly_common_client/src/data_sources/data_source_status_manager.dart';
import 'package:launchdarkly_common_client/src/data_sources/streaming_data_source.dart';
import 'package:launchdarkly_common_client/src/flag_manager/flag_manager.dart';
import 'package:launchdarkly_event_source_client/launchdarkly_event_source_client.dart';
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
  final eventHandler = DataSourceEventHandler(
      logger: logger, flagManager: flagManager, statusManager: statusManager);
  final streaming = StreamingDataSource(
      credential: sdkKey,
      context: context,
      endpoints: ServiceEndpoints(),
      logger: logger,
      dataSourceConfig: StreamingDataSourceConfig(
          withReasons: withReasons, useReport: useReport),
      httpProperties: httpProperties,
      subFactory: (Uri uri, HttpProperties properties, MessageHandler handler,
          ErrorHandler errorHandler) {
        factoryCallback?.call(uri, properties, handler, errorHandler);
        mockStream.handleError(errorHandler);
        return mockStream.listen(handler);
      });

  streaming.events.asyncMap((event) async {
    switch (event) {
      case DataEvent():
        return eventHandler.handleMessage(context, event.type, event.data);
      case StatusEvent():
        if (event.statusCode != null) {
          statusManager.setErrorResponse(event.statusCode!, event.message,
              shutdown: event.shutdown);
        } else {
          statusManager.setErrorByKind(event.kind, event.message,
              shutdown: event.shutdown);
        }
    }
  }).listen((_) {});

  return (streaming, flagManager, statusManager);
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
  });

  test('it cancels the subscription on stop', () {
    bool cancelled = false;
    final controller =
        StreamController<MessageEvent>(onCancel: () => cancelled = true);
    final (dataSource, _, _) = makeDataSourceForTest(controller.stream,
        withReasons: true,
        factoryCallback: (uri, properties, handler, errorHandler) {});

    dataSource.start();
    dataSource.stop();
    expect(cancelled, true);
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
