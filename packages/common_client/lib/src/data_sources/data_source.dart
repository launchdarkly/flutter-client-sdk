import 'data_source_status.dart';
import 'fdv2/payload.dart';

sealed class DataSourceEvent {}

final class DataEvent implements DataSourceEvent {
  final String type;
  final String data;
  final String? environmentId;

  DataEvent(this.type, this.data, {this.environmentId});
}

/// An FDv2 change set produced by the data source orchestrator. Carries
/// typed flag descriptors translated at acquisition time, not the FDv1
/// JSON string forms.
final class PayloadEvent implements DataSourceEvent {
  final ChangeSet changeSet;
  final String? environmentId;

  PayloadEvent(this.changeSet, {this.environmentId});
}

final class StatusEvent implements DataSourceEvent {
  ErrorKind kind;
  num? statusCode;
  String message;
  bool shutdown;

  StatusEvent(this.kind, this.statusCode, this.message,
      {this.shutdown = false});
}

/// Emitted once by the FDv2 orchestrator when initialization is complete:
/// a selector-bearing payload arrived, the initializer chain was exhausted
/// (with cached data or in a cache-only system), or the first synchronizer
/// delivered a change set. The manager resolves a wait-for-network identify
/// on this; a cached identify resolves earlier, on the first applied payload.
final class InitializedEvent implements DataSourceEvent {}

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
