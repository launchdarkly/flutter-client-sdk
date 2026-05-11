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
