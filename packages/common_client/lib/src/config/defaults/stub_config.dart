import '../../connection_mode.dart';
import 'credential_type.dart';

class DefaultPollingPaths {
  String pollingGetPath(String credential, String context) {
    throw Exception('Stub implementation');
  }

  String pollingReportPath(String credential, String context) {
    throw Exception('Stub implementation');
  }
}

class DefaultStreamingPaths {
  String streamingGetPath(String credential, String context) {
    throw Exception('Stub implementation');
  }

  String streamingReportPath(String credential, String context) {
    throw Exception('Stub implementation');
  }
}

class DefaultEventPaths {
  String getAnalyticEventsPath(String credential) {
    throw Exception('Stub implementation');
  }

  String getDiagnosticEventsPath(String credential) {
    throw Exception('Stub implementation');
  }
}

class NetworkConfig {
  Set<String> get restrictedHeaders => throw Exception('Stub implementation');
}

final class DefaultEndpoints {
  DefaultEndpoints() {
    throw Exception('Stub implementation');
  }

  final String polling = '';
  final String streaming = '';
  final String events = '';
}

final class CredentialConfig {
  CredentialType get credentialType => throw Exception('Stub implementation');
}

final class DefaultDataSourceConfig {
  bool get defaultWithReasons => throw Exception('Stub implementation');

  bool get defaultUseReport => throw Exception('Stub implementation');

  ConnectionMode get defaultInitialConnectionMode =>
      throw Exception('Stub implementation');

  bool get streamingReportSupported => throw Exception('Stub implementation');
}
