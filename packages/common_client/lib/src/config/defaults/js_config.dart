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
  /// authorization header is intentionally absent: a browser only
  /// delivers it when the service's CORS pre-flight response lists it
  /// as an allowed header, so authentication uses the `auth` query
  /// parameter instead, which is not subject to that allow-list.
  Map<String, String> baseHeaders(String credential, String userAgent) =>
      {'x-launchdarkly-user-agent': userAgent};

  /// Authentication for every data acquisition request in the browser.
  /// The `auth` query parameter is used at all times rather than the
  /// authorization header: the header depends on each service's CORS
  /// pre-flight allowing it (a missed allow-list entry silently breaks
  /// authentication), and the browser's native EventSource cannot send
  /// custom headers at all.
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
