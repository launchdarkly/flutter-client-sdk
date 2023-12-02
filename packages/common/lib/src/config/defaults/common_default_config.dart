import 'stub_config.dart'
    if (dart.library.io) 'io_config.dart'
    if (dart.library.html) 'js_config.dart';

final class CommonDefaultConfig {
  static final NetworkConfig networkConfig = NetworkConfig();
}
