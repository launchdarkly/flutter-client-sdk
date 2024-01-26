import 'dart:async';

import 'data_source.dart';

final class NullDataSource implements DataSource {
  final StreamController<DataSourceEvent> _controller = StreamController();

  @override
  Stream<DataSourceEvent> get events => _controller.stream;

  @override
  void start() {
    _controller.sink.add(DataEvent('put', '{}'));
  }

  @override
  void stop() {
    _controller.close();
  }

  @override
  void restart() {
    // TODO: implement restart
  }
}
