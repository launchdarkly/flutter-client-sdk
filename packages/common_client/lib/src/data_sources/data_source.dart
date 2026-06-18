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

  /// Whether this payload represents the freshest data the active source
  /// can produce for this initialization -- network basis data, an FDv1
  /// fallback transfer, or the terminal payload of a cache-only system.
  ///
  /// False only for preliminary cache data delivered while a fresher
  /// source is still expected (e.g. the cache initializer ahead of a
  /// streaming synchronizer). The manager uses this to decide whether to
  /// mark the source valid and whether to resolve an identify that is
  /// waiting for network results: cached flags are applied either way,
  /// but a non-basis payload neither drives the status to valid nor
  /// satisfies a wait-for-network identify.
  final bool basis;

  PayloadEvent(this.changeSet, {this.environmentId, this.basis = true});
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
