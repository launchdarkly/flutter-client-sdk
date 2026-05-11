import 'package:launchdarkly_common_client/launchdarkly_common_client.dart';

class ConnectionManagerConfig {
  bool get runInBackground => true;

  ConnectionMode get defaultBackgroundConnectionMode => ConnectionMode.offline;
}
