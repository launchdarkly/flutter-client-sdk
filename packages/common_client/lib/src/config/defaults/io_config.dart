import '../../connection_mode.dart';
import 'credential_type.dart';

class DefaultPollingPaths {
  String pollingGetPath(String credential, String context) {
    return '/msdk/evalx/contexts/$context';
  }

  String pollingReportPath(String credential, String context) {
    return '/msdk/evalx/context';
  }
}

class DefaultStreamingPaths {
  String streamingGetPath(String credential, String context) {
    return '/meval/$context';
  }

  String streamingReportPath(String credential, String context) {
    return '/meval';
  }
}

class DefaultEventPaths {
  String getAnalyticEventsPath(String credential) {
    return '/mobile';
  }

  String getDiagnosticEventsPath(String credential) {
    return '/mobile/events/diagnostic';
  }
}

final class DefaultEndpoints {
  final String polling = 'https://clientsdk.launchdarkly.com';
  final String streaming = 'https://clientstream.launchdarkly.com';
  final String events = 'https://mobile.launchdarkly.com';
}

final class CredentialConfig {
  CredentialType get credentialType => CredentialType.mobileKey;

  /// Headers applied to every request. Every service on this platform
  /// authenticates with the authorization header.
  Map<String, String> baseHeaders(String credential, String userAgent) =>
      {'user-agent': userAgent, 'authorization': credential};

  /// Every transport on this platform supports custom headers, so no
  /// query parameter authentication is needed.
  Map<String, String> authQueryParameters(String credential) => const {};

  /// A mobile key does not identify an environment; the environment ID
  /// comes only from response headers.
  String? environmentIdFallback(String credential) => null;
}

final class DefaultDataSourceConfig {
  bool get defaultWithReasons => false;

  bool get defaultUseReport => false;

  ConnectionMode get defaultInitialConnectionMode => ConnectionMode.streaming;

  bool get streamingReportSupported => true;
}
