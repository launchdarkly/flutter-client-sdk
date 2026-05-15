import 'package:launchdarkly_common_client/launchdarkly_common_client.dart';

import 'stub_config.dart'
    if (dart.library.io) 'io_config.dart'
    if (dart.library.js_interop) 'js_config.dart';

/// Configuration common to web and mobile is contained in this file.
///
/// Native IO and web-specific defaults live in `io_config.dart` and
/// `js_config.dart` and are exposed through this file.

final class FlutterDefaultConfig {
  static final ConnectionManagerConfig connectionManagerConfig =
      ConnectionManagerConfig();

  /// Default automatic-resolution background slot.
  static ConnectionMode get defaultBackgroundConnectionMode =>
      connectionManagerConfig.defaultBackgroundConnectionMode;

  static final ApplicationEventsConfig applicationEventsConfig =
      ApplicationEventsConfig();
}
