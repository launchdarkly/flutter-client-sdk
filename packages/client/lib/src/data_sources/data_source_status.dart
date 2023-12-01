enum DataSourceState {
  /// The initial state of the data source when the SDK is being
  /// initialized.
  ///
  /// If it encounters an error that requires it to retry initialization,
  /// the state will remain at kInitializing until it either succeeds and
  /// becomes [valid], or permanently fails and becomes [shutdown].
  initializing,

  /// Indicates that the data source is currently operational and has not
  /// had any problems since the last time it received data.
  ///
  /// In streaming mode, this means that there is currently an open stream
  /// connection and that at least one initial message has been received on
  /// the stream. In polling mode, it means that the last poll request
  /// succeeded.
  valid,

  /// Indicates that the data source encountered an error that it will
  /// attempt to recover from.
  ///
  /// In streaming mode, this means that the stream connection failed, or
  /// had to be dropped due to some other error, and will be retried after
  /// a backoff delay. In polling mode, it means that the last poll request
  /// failed, and a new poll request will be made after the configured
  /// polling interval.
  interrupted,

  /// Indicates that the application has told the SDK to stay offline.
  setOffline,

  /// Indicates that the data source has been permanently shut down.
  ///
  /// This could be because it encountered an unrecoverable error (for
  /// instance, the LaunchDarkly service rejected the SDK key; an invalid
  /// SDK key will never become valid), or because the SDK client was
  /// explicitly shut down.
  shutdown,

  /// Indicates that the SDK is aware of a lack of network connectivity.
  ///
  /// On mobile devices, if wi-fi is turned off or there is no wi-fi connection
  /// and cellular data is unavailable, the device OS will tell the SDK that
  /// the network is unavailable. The SDK then enters this state, where it will
  /// not try to make any network connections since they would be guaranteed to
  /// fail, until the OS informs it that the network is available again.
  ///
  /// This functionality is not provided by the base Dart SDK, but instead
  /// is a feature enabled by the flutter SDK. The base Dart SDK cannot detect
  /// network status and therefore the [interrupted] state will be entered
  /// when network requests fail from a lack of network availability.
  networkUnavailable,

  /// Indicates that the SDK is in background mode and background updating has been disabled.
  ///
  /// On mobile devices, if the application containing the SDK is put into the
  /// background, by default the SDK will still check for feature flag updates
  /// occasionally. However, if this has been disabled, the SDK will instead
  /// stop the data source and wait until it is in the foreground again.
  /// During that time, the state is [backgroundDisabled].
  backgroundDisabled,
}

enum ErrorKind {
  /// An unexpected error, such as an uncaught exception, further
  /// described by the error message.
  unknown,

  /// An I/O error such as a dropped connection.
  networkError,

  /// The LaunchDarkly service returned an HTTP response with an error
  /// status, available in the status code.
  errorResponse,

  /// The SDK received malformed data from the LaunchDarkly service.
  invalidData,

  /// The data source itself is working, but when it tried to put an
  /// update into the data store, the data store failed (so the SDK may
  /// not have the latest data).
  storeError // TODO: I don't think we have this scenario, but we may want this value for API consistency.
}

/// A description of an error condition that the data source encountered.
final class DataSourceStatusErrorInfo {
  /// An enumerated value representing the general category of the error.
  final ErrorKind kind;

  /// The HTTP status code if the error was [ErrorKind.errorResponse].
  final num? statusCode;

  /// Any additional human-readable information relevant to the error.
  ///
  /// The format is subject to change and should not be relied on
  /// programmatically.
  final String message;

  /// The date/time that the error occurred.
  final DateTime time;

  DataSourceStatusErrorInfo(
      {required this.kind,
      required this.statusCode,
      required this.message,
      required this.time});

  @override
  String toString() {
    return 'DataSourceStatusErrorInfo{kind: $kind, statusCode: $statusCode, message: $message, time: $time}';
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is DataSourceStatusErrorInfo &&
          kind == other.kind &&
          statusCode == other.statusCode &&
          message == other.message &&
          time == other.time;

  @override
  int get hashCode =>
      kind.hashCode ^ statusCode.hashCode ^ message.hashCode ^ time.hashCode;
}

final class DataSourceStatus {
  /// An enumerated value representing the overall current state of the data
  /// source.
  final DataSourceState state;

  /// The date/time that the value of State most recently changed.
  ///
  /// The meaning of this depends on the current state:
  /// - For [DataSourceState.initializing], it is the time that the SDK started
  /// initializing.
  ///
  /// - For [DataSourceState.valid], it is the time that the data source most
  /// recently entered a valid state, after previously having been
  /// [DataSourceStatus.initializing] or an invalid state such as
  /// [DataSourceState.interrupted].
  ///
  /// - For [DataSourceState.interrupted], it is the time that the data source
  /// most recently entered an error state, after previously having been
  /// [DataSourceState.valid].
  ///
  /// - For [DataSourceState.shutdown], it is the time that the data source
  /// encountered an unrecoverable error or that the SDK was explicitly shut down.
  ///
  /// - For [DataSourceState.networkUnavailable] or
  /// [DataSourceState.backgroundDisabled], it is the time that the SDK switched
  /// off the data source after detecting one of those conditions.
  final DateTime stateSince;

  /// Information about the last error that the data source encountered, if
  /// any.
  ///
  /// This property should be updated whenever the data source encounters a
  /// problem, even if it does not cause the state to change. For instance, if
  /// a stream connection fails and the state changes to
  /// [DataSourceState.interrupted], and then subsequent attempts to restart
  /// the connection also fail, the state will remain
  /// [DataSourceState.interrupted] but the error information will be updated
  /// each time-- and the last error will still be reported in this property
  /// even if the state later becomes [DataSourceState.valid].
  final DataSourceStatusErrorInfo? lastError;

  DataSourceStatus(
      {required this.state, required this.stateSince, this.lastError});

  @override
  String toString() {
    return 'DataSourceStatus{state: $state, stateSince: $stateSince, lastError: $lastError}';
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is DataSourceStatus &&
          state == other.state &&
          stateSince == other.stateSince &&
          lastError == other.lastError;

  @override
  int get hashCode => state.hashCode ^ stateSince.hashCode ^ lastError.hashCode;
}
