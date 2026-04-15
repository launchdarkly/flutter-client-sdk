import 'fdv2_payload.dart';

/// The status of a data source that is not delivering data.
enum SourceState {
  /// A transient issue; automatic recovery expected.
  interrupted,

  /// The source has been permanently shut down.
  shutdown,

  /// A terminal error; this source cannot recover.
  terminalError,

  /// The server sent a goodbye event.
  goodbye,
}

/// Result from an initializer or synchronizer.
sealed class FDv2SourceResult {
  /// Whether the server indicated FDv1 fallback is needed.
  final bool fdv1Fallback;

  const FDv2SourceResult({this.fdv1Fallback = false});
}

/// A data payload was received.
final class ChangeSetResult extends FDv2SourceResult {
  /// The payload containing updates.
  final Payload payload;

  /// The environment ID from response headers, if present.
  final String? environmentId;

  /// When the data was received, for freshness tracking.
  final DateTime? freshness;

  /// Whether the data should be persisted to the cache.
  final bool persist;

  const ChangeSetResult({
    required this.payload,
    this.environmentId,
    this.freshness,
    this.persist = true,
    super.fdv1Fallback,
  });

  @override
  String toString() =>
      'ChangeSetResult(type: ${payload.type}, '
      'updates: ${payload.updates.length}, '
      'hasSelector: ${payload.state != null}, '
      'persist: $persist, fdv1Fallback: $fdv1Fallback)';
}

/// A non-data status was received.
final class StatusResult extends FDv2SourceResult {
  /// The kind of status.
  final SourceState state;

  /// An error kind string, if applicable.
  final String? errorKind;

  /// A human-readable error message, if applicable.
  final String? message;

  /// The HTTP status code, if applicable.
  final int? statusCode;

  const StatusResult({
    required this.state,
    this.errorKind,
    this.message,
    this.statusCode,
    super.fdv1Fallback,
  });

  @override
  String toString() =>
      'StatusResult(state: $state, errorKind: $errorKind, '
      'message: $message, fdv1Fallback: $fdv1Fallback)';
}

/// Factory functions for creating common result types.
abstract final class FDv2SourceResults {
  static ChangeSetResult changeSet({
    required Payload payload,
    String? environmentId,
    DateTime? freshness,
    bool persist = true,
    bool fdv1Fallback = false,
  }) =>
      ChangeSetResult(
        payload: payload,
        environmentId: environmentId,
        freshness: freshness,
        persist: persist,
        fdv1Fallback: fdv1Fallback,
      );

  static StatusResult interrupted({
    String? message,
    int? statusCode,
    bool fdv1Fallback = false,
  }) =>
      StatusResult(
        state: SourceState.interrupted,
        message: message,
        statusCode: statusCode,
        fdv1Fallback: fdv1Fallback,
      );

  static StatusResult shutdown({
    String? message,
    bool fdv1Fallback = false,
  }) =>
      StatusResult(
        state: SourceState.shutdown,
        message: message,
        fdv1Fallback: fdv1Fallback,
      );

  static StatusResult terminalError({
    String? message,
    int? statusCode,
    bool fdv1Fallback = false,
  }) =>
      StatusResult(
        state: SourceState.terminalError,
        message: message,
        statusCode: statusCode,
        fdv1Fallback: fdv1Fallback,
      );

  static StatusResult goodbyeResult({
    String? message,
    bool fdv1Fallback = false,
  }) =>
      StatusResult(
        state: SourceState.goodbye,
        message: message,
        fdv1Fallback: fdv1Fallback,
      );
}
