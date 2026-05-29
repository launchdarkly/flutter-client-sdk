import 'package:launchdarkly_common_client/launchdarkly_common_client.dart';

class ConnectionManagerConfig {
  bool get runInBackground => throw Exception('Stub implementation');

  FDv2ConnectionMode get defaultBackgroundConnectionMode => const FDv2Offline();
}

/// Stub defaults for tests and unsupported compilation targets.
final class ApplicationEventsConfig {
  bool get defaultBackgrounding => false;

  bool get defaultNetworkAvailability => false;
}
