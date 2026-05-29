import 'dart:io' show Platform;

import 'package:launchdarkly_common_client/launchdarkly_common_client.dart';

class ConnectionManagerConfig {
  bool get runInBackground =>
      Platform.isLinux || Platform.isWindows || Platform.isMacOS;

  FDv2ConnectionMode get defaultBackgroundConnectionMode =>
      Platform.isAndroid || Platform.isIOS || Platform.isFuchsia
          ? const FDv2Background()
          : const FDv2Offline();
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
