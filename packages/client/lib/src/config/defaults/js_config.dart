import 'credential_type.dart';

class DefaultPollingPaths {
  String pollingGetPath(String credential, String context) {
    return '/sdk/evalx/$credential/contexts/$context';
  }

  String pollingReportPath(String credential, String context) {
    return '/sdk/evalx/$credential/context';
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

class NetworkConfig {
  Set<String> get restrictedHeaders => {'user-agent', 'authorization'};
}

final class DefaultEndpoints {
  final String polling = 'https://clientsdk.launchdarkly.com';
  final String streaming = 'https://clientstream.launchdarkly.com';
  final String events = 'https://events.launchdarkly.com';
}

final class CredentialConfig {
  CredentialType get credentialType => CredentialType.clientSideId;
}
