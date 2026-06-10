import 'data_source_status.dart';
import 'fdv2/payload.dart';

sealed class DataSourceEvent {}

final class DataEvent implements DataSourceEvent {
  final String type;
  final String data;
  final String? environmentId;

  DataEvent(this.type, this.data, {this.environmentId});
}

/// An FDv2 payload produced by the data source orchestrator. Carries the
/// already-parsed updates instead of the FDv1 JSON string forms.
final class PayloadEvent implements DataSourceEvent {
  final Payload payload;
  final String? environmentId;

  PayloadEvent(this.payload, {this.environmentId});
}

final class StatusEvent implements DataSourceEvent {
  ErrorKind kind;
  num? statusCode;
  String message;
  bool shutdown;

  StatusEvent(this.kind, this.statusCode, this.message,
      {this.shutdown = false});
}

abstract interface class DataSource {
  Stream<DataSourceEvent> get events;

  /// Start the data source. Once a data source has been stopped it cannot
  /// be started again.
  void start();

  /// Stop the data source. Any active connection is dropped.
  void stop();

  /// If the data source maintains a persistent connection, then drop that
  /// connection and re-establish it with any appropriate delays/backoff.
  void restart();
}
