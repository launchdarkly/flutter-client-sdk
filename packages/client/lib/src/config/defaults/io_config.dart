import 'credential_type.dart';

class DefaultPollingPaths {
  String pollingGetPath(String credential, String context) {
    return '/msdk/evalx/contexts/$context';
  }

  String pollingReportPath(String credential, String context) {
    return '/msdk/evalx/contexts';
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

class NetworkConfig {
  Set<String> get restrictedHeaders => {};
}

final class DefaultEndpoints {
  final String polling = 'https://clientsdk.launchdarkly.com';
  final String streaming = 'https://clientstream.launchdarkly.com';
  final String events = 'https://mobile.launchdarkly.com';
}

final class CredentialConfig {
  CredentialType get credentialType => CredentialType.mobileKey;
}
