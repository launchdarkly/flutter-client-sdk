import '../../connection_mode.dart';
import 'credential_type.dart';

class DefaultPollingPaths {
  String pollingGetPath(String credential, String context) {
    return '/sdk/evalx/$credential/contexts/$context';
  }

  String pollingReportPath(String credential, String context) {
    return '/sdk/evalx/$credential/context';
  }
}

class DefaultStreamingPaths {
  String streamingGetPath(String credential, String context) {
    return '/eval/$credential/$context';
  }

  String streamingReportPath(String credential, String context) {
    return '/eval/$credential';
  }
}

class DefaultEventPaths {
  String getAnalyticEventsPath(String credential) {
    return '/events/bulk/$credential';
  }

  String getDiagnosticEventsPath(String credential) {
    return '/events/bulk/$credential';
  }
}

final class DefaultEndpoints {
  final String polling = 'https://clientsdk.launchdarkly.com';
  final String streaming = 'https://clientstream.launchdarkly.com';
  final String events = 'https://events.launchdarkly.com';
}

final class CredentialConfig {
  CredentialType get credentialType => CredentialType.clientSideId;

  /// Headers applied to every request. The user agent is sent under a
  /// vendor header because browsers forbid setting `user-agent`. The
  /// authorization header is intentionally absent: the events service
  /// CORS configuration does not permit it from browsers. Data
  /// acquisition requests whose service allows it add the header
  /// per-request instead.
  Map<String, String> baseHeaders(String credential, String userAgent) =>
      {'x-launchdarkly-user-agent': userAgent};

  /// Authentication for requests whose transport cannot carry custom
  /// headers. The browser's native EventSource cannot send headers, so
  /// streaming requests authenticate with the `auth` query parameter.
  Map<String, String> authQueryParameters(String credential) =>
      {'auth': credential};

  /// A client-side ID identifies the environment directly, so it serves
  /// as the environment ID when response headers are unavailable.
  String? environmentIdFallback(String credential) => credential;
}

final class DefaultDataSourceConfig {
  bool get defaultWithReasons => false;

  bool get defaultUseReport => false;

  ConnectionMode get defaultInitialConnectionMode => ConnectionMode.streaming;

  bool get streamingReportSupported => false;
}
