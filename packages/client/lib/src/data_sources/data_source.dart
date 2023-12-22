import 'data_source_status.dart';

sealed class DataSourceEvent {}

final class DataEvent implements DataSourceEvent {
  final String type;
  final String data;

  DataEvent(this.type, this.data);
}

final class StatusEvent implements DataSourceEvent {
  ErrorKind kind;
  num? statusCode;
  String message;
  bool shutdown;

  StatusEvent(this.kind, this.statusCode, this.message, {this.shutdown = false});
}

abstract interface class DataSource {
  Stream<DataSourceEvent> get events;

  void start();
  void stop();
}
