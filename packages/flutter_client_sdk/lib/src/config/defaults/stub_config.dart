import 'package:launchdarkly_common_client/launchdarkly_common_client.dart';

class ConnectionManagerConfig {
  bool get runInBackground => throw Exception('Stub implementation');

  ConnectionMode get defaultBackgroundConnectionMode => ConnectionMode.offline;
}
