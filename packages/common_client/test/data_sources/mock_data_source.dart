import 'dart:async';

import 'package:launchdarkly_common_client/src/data_sources/data_source.dart';

final class MockDataSource implements DataSource {
  final StreamController<DataSourceEvent> controller = StreamController();
  final List<DataSourceEvent> _startEvents;

  bool startCalled = false;
  bool stopCalled = false;
  bool restartCalled = false;

  MockDataSource({List<DataSourceEvent>? startEvents})
      : _startEvents = startEvents ?? [PutEvent({})];

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
        .then((_) => controller.sink.add(PutEvent({})));
  }
}
