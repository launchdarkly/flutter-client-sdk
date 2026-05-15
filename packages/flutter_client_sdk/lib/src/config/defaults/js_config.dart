import 'package:launchdarkly_common_client/launchdarkly_common_client.dart';

class ConnectionManagerConfig {
  bool get runInBackground => true;

  ConnectionMode get defaultBackgroundConnectionMode => ConnectionMode.offline;
}

/// Platform defaults for [ApplicationEvents] on web.
///
/// Web does not use application or network detector signals for automatic
/// connection handling by default.
final class ApplicationEventsConfig {
  bool get defaultBackgrounding => false;

  bool get defaultNetworkAvailability => false;
}
