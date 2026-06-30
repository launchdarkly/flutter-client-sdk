import 'payload.dart';

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

  /// How long to remain on the fallback before retrying FDv2, when
  /// [fdv1Fallback] is set. `null` means the server gave no time-to-live
  /// (the caller applies its default); [Duration.zero] means remain
  /// indefinitely with no automatic retry.
  final Duration? fdv1FallbackTtl;

  const FDv2SourceResult({this.fdv1Fallback = false, this.fdv1FallbackTtl});
}

/// A data payload was received and translated into typed descriptors.
final class ChangeSetResult extends FDv2SourceResult {
  /// The translated change set ready to apply to the flag store.
  final ChangeSet changeSet;

  /// The environment ID from response headers, if present.
  final String? environmentId;

  /// When the data was received, for freshness tracking.
  final DateTime? freshness;

  /// Whether the data should be persisted to the cache.
  final bool persist;

  const ChangeSetResult({
    required this.changeSet,
    required this.persist,
    this.environmentId,
    this.freshness,
    super.fdv1Fallback,
    super.fdv1FallbackTtl,
  });

  @override
  String toString() => 'ChangeSetResult(type: ${changeSet.type}, '
      'updates: ${changeSet.updates.length}, '
      'hasSelector: ${changeSet.selector.isNotEmpty}, '
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
    super.fdv1FallbackTtl,
  });

  @override
  String toString() => 'StatusResult(state: $state, errorKind: $errorKind, '
      'message: $message, fdv1Fallback: $fdv1Fallback)';
}

/// Factory functions for creating common result types.
abstract final class FDv2SourceResults {
  static ChangeSetResult changeSet({
    required ChangeSet changeSet,
    required bool persist,
    String? environmentId,
    DateTime? freshness,
    bool fdv1Fallback = false,
    Duration? fdv1FallbackTtl,
  }) =>
      ChangeSetResult(
        changeSet: changeSet,
        persist: persist,
        environmentId: environmentId,
        freshness: freshness,
        fdv1Fallback: fdv1Fallback,
        fdv1FallbackTtl: fdv1FallbackTtl,
      );

  static StatusResult interrupted({
    String? message,
    int? statusCode,
    bool fdv1Fallback = false,
    Duration? fdv1FallbackTtl,
  }) =>
      StatusResult(
        state: SourceState.interrupted,
        message: message,
        statusCode: statusCode,
        fdv1Fallback: fdv1Fallback,
        fdv1FallbackTtl: fdv1FallbackTtl,
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
    Duration? fdv1FallbackTtl,
  }) =>
      StatusResult(
        state: SourceState.terminalError,
        message: message,
        statusCode: statusCode,
        fdv1Fallback: fdv1Fallback,
        fdv1FallbackTtl: fdv1FallbackTtl,
      );

  static StatusResult goodbyeResult({
    String? message,
    bool fdv1Fallback = false,
    Duration? fdv1FallbackTtl,
  }) =>
      StatusResult(
        state: SourceState.goodbye,
        message: message,
        fdv1Fallback: fdv1Fallback,
        fdv1FallbackTtl: fdv1FallbackTtl,
      );
}
