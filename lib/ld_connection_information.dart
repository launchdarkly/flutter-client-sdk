// @dart=2.12
part of launchdarkly_flutter_client_sdk;

/// Enumerated type defining the possible connection states for the SDK.
enum LDConnectionState {
  /// Indicates that the SDK is currently in a foreground streaming mode.
  STREAMING,
  /// Indicates that the SDK is currently in a foreground polling mode.
  POLLING,
  /// Indicates that the SDK is currently in a background polling mode.
  BACKGROUND_POLLING,
  /// Indicates that the SDK is currently in the background, but background polling is disabled.
  BACKGROUND_DISABLED,
  /// Indicates that the SDK has detected that network connectivity is unavailable, and will not make network requests
  /// until the network is available again.
  OFFLINE,
  /// Indicates that the SDK has been set offline by [LDConfigBuilder.setOffline] or [LDClient.setOnline].
  SET_OFFLINE,
  /// Indicates that the SDK has been explicitly shut down by calling [LDClient.close].
  SHUTDOWN
}

/// Enumerated type defining the defined failures the SDK can report encountering while fetching flag values.
enum LDFailureType {
  /// The SDK received a response that could not be decoded into a valid flag update.
  INVALID_RESPONSE_BODY,
  /// A network failure has interrupted a flag update stream or polling request.
  NETWORK_FAILURE,
  /// The SDK has received an unknown event type in the event stream used for real-time flag updates.
  UNEXPECTED_STREAM_ELEMENT_TYPE,
  /// A network request to the service returned a unsuccessful response code.
  UNEXPECTED_RESPONSE_CODE,
  /// An unknown error occurred while fetching flag values.
  UNKNOWN_ERROR
}

/// Describes an error encountered during an attempt to retrieve flag values from the LaunchDarkly service.
class LDFailure {
  /// A message describing the failure.
  final String? message;
  /// The type of the failure.
  ///
  /// See [LDFailureType] for the possible values.
  final LDFailureType failureType;

  /// Constructor for an [LDFailure].
  const LDFailure(this.message, this.failureType);

  static const _failureTypeNames =
      { "INVALID_RESPONSE_BODY": LDFailureType.INVALID_RESPONSE_BODY, "NETWORK_FAILURE": LDFailureType.NETWORK_FAILURE
      , "UNEXPECTED_STREAM_ELEMENT_TYPE": LDFailureType.UNEXPECTED_STREAM_ELEMENT_TYPE
      , "UNEXPECTED_RESPONSE_CODE": LDFailureType.UNEXPECTED_RESPONSE_CODE, "UNKNOWN_ERROR": LDFailureType.UNKNOWN_ERROR };

  static LDFailure? _fromCodecValue(dynamic value) {
    if (!(value is Map)) return null;
    Map<String, dynamic> map = Map.from(value as Map);
    var failureType = _failureTypeNames[map["failureType"]];
    if (failureType == null) return null;
    return LDFailure(map["message"], failureType);
  }
}

/// Describes the connectivity state of the SDK, and information on occurrence of request failures and successes.
class LDConnectionInformation {
  /// The connectivity state of the SDK.
  ///
  /// See [LDConnectionState] for details on the possible values.
  final LDConnectionState connectionState;
  /// The most recent failure the SDK has encountered.
  ///
  /// May be null if no failures have been encountered.
  final LDFailure? lastFailure;
  /// The most recent time that new flag values were received, if ever.
  final DateTime? lastSuccessfulConnection;
  /// The time at which [lastFailure] occurred, if ever.
  final DateTime? lastFailedConnection;

  /// Constructor for [LDConnectionInformation]
  const LDConnectionInformation(this.connectionState, this.lastFailure, this.lastSuccessfulConnection, this.lastFailedConnection);

  static const _connectionStateNames =
      { "STREAMING": LDConnectionState.STREAMING, "POLLING": LDConnectionState.POLLING
      , "BACKGROUND_POLLING": LDConnectionState.BACKGROUND_POLLING, "BACKGROUND_DISABLED": LDConnectionState.BACKGROUND_DISABLED
      , "OFFLINE": LDConnectionState.OFFLINE, "SET_OFFLINE": LDConnectionState.SET_OFFLINE, "SHUTDOWN": LDConnectionState.SHUTDOWN };

  static LDConnectionInformation? _fromCodecValue(dynamic value) {
    if (!(value is Map)) return null;
    Map<String, dynamic> map = Map.from(value as Map);
    var state = _connectionStateNames[map["connectionState"]];
    if (state == null) return null;
    var failure = LDFailure._fromCodecValue(map["lastFailure"]);
    DateTime? lastSuccessful, lastFailed;
    if (map["lastSuccessfulConnection"] is int) {
      lastSuccessful = DateTime.fromMillisecondsSinceEpoch(map["lastSuccessfulConnection"], isUtc: true);
    }
    if (map["lastFailedConnection"] is int) {
      lastFailed = DateTime.fromMillisecondsSinceEpoch(map["lastFailedConnection"], isUtc: true);
    }
    return LDConnectionInformation(state, failure, lastSuccessful, lastFailed);
  }
}
