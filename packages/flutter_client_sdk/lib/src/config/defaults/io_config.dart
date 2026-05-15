import 'dart:io' show Platform;

import 'package:launchdarkly_common_client/launchdarkly_common_client.dart';

class ConnectionManagerConfig {
  bool get runInBackground =>
      Platform.isLinux || Platform.isWindows || Platform.isMacOS;

  ConnectionMode get defaultBackgroundConnectionMode =>
      Platform.isAndroid || Platform.isIOS || Platform.isFuchsia
          ? ConnectionMode.background
          : ConnectionMode.offline;
}

/// Platform defaults for [ApplicationEvents] on native IO targets.
///
/// Mobile uses application and network signals for automatic connection
/// handling; desktop IO targets do not by default.
final class ApplicationEventsConfig {
  bool get _isMobile =>
      Platform.isAndroid || Platform.isIOS || Platform.isFuchsia;

  bool get defaultBackgrounding => _isMobile;

  bool get defaultNetworkAvailability => _isMobile;
}
