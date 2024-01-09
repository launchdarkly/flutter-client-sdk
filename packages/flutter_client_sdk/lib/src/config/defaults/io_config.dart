import 'dart:io' show Platform;

class ConnectionManagerConfig {
  bool get runInBackground => Platform.isLinux || Platform.isWindows || Platform.isMacOS;
}
