part of launchdarkly_flutter_client_sdk;

enum LDConnectionState { STREAMING, POLLING, BACKGROUND_POLLING, BACKGROUND_DISABLED, OFFLINE, SET_OFFLINE, SHUTDOWN }
enum LDFailureType { INVALID_RESPONSE_BODY, NETWORK_FAILURE, UNEXPECTED_STREAM_ELEMENT_TYPE, UNEXPECTED_RESPONSE_CODE, UNKNOWN_ERROR }

class LDFailure {
  final String message;
  final LDFailureType failureType;

  const LDFailure(this.message, this.failureType);

  static const _failureTypeNames =
      { "INVALID_RESPONSE_BODY": LDFailureType.INVALID_RESPONSE_BODY, "NETWORK_FAILURE": LDFailureType.NETWORK_FAILURE
      , "UNEXPECTED_STREAM_ELEMENT_TYPE": LDFailureType.UNEXPECTED_STREAM_ELEMENT_TYPE
      , "UNEXPECTED_RESPONSE_CODE": LDFailureType.UNEXPECTED_RESPONSE_CODE, "UNKNOWN_ERROR": LDFailureType.UNKNOWN_ERROR };

  static LDFailure _fromCodecValue(dynamic value) {
    if (!(value is Map)) return null;
    Map<String, dynamic> map = Map.from(value as Map);
    return LDFailure(map["message"], _failureTypeNames[map["failureType"]]);
  }
}

class LDConnectionInformation {
  final LDConnectionState connectionState;
  final LDFailure lastFailure;
  final DateTime lastSuccessfulConnection;
  final DateTime lastFailedConnection;

  const LDConnectionInformation(this.connectionState, this.lastFailure, this.lastSuccessfulConnection, this.lastFailedConnection);

  static const _connectionStateNames =
      { "STREAMING": LDConnectionState.STREAMING, "POLLING": LDConnectionState.POLLING
      , "BACKGROUND_POLLING": LDConnectionState.BACKGROUND_POLLING, "BACKGROUND_DISABLED": LDConnectionState.BACKGROUND_DISABLED
      , "OFFLINE": LDConnectionState.OFFLINE, "SET_OFFLINE": LDConnectionState.SET_OFFLINE, "SHUTDOWN": LDConnectionState.SHUTDOWN };

  static LDConnectionInformation _fromCodecValue(dynamic value) {
    if (!(value is Map)) return null;
    Map<String, dynamic> map = Map.from(value as Map);
    var state = _connectionStateNames[map["connectionState"]];
    var failure = LDFailure._fromCodecValue(map["lastFailure"]);
    DateTime lastSuccessful, lastFailed;
    if (map["lastSuccessfulConnection"] is int) {
      lastSuccessful = DateTime.fromMillisecondsSinceEpoch(map["lastSuccessfulConnection"], isUtc: true);
    }
    if (map["lastFailedConnection"] is int) {
      lastFailed = DateTime.fromMillisecondsSinceEpoch(map["lastFailedConnection"], isUtc: true);
    }
    return LDConnectionInformation(state, failure, lastSuccessful, lastFailed);
  }
}