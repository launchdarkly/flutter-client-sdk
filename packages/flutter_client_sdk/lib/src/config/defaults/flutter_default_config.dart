import 'stub_config.dart'
    if (dart.library.io) 'io_config.dart'
    if (dart.library.html) 'js_config.dart';

/// Configuration common to web and mobile is contained in this file.
///
/// Configuration specific to either io targets or js targets are in io_config
/// and js_config and then exposed through this file.

final class FlutterDefaultConfig {
  static final ConnectionManagerConfig connectionManagerConfig =
      ConnectionManagerConfig();
}
