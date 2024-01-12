import '../../ld_logging.dart';
import 'stub_config.dart'
    if (dart.library.io) 'io_config.dart'
    if (dart.library.html) 'js_config.dart';

final class DefaultLoggingConfig {
  final defaultLogLevel = LDLogLevel.info;
  final defaultLogTag = 'LaunchDarkly';
}

final class CommonDefaultConfig {
  static final NetworkConfig networkConfig = NetworkConfig();
  static final DefaultLoggingConfig loggingConfig = DefaultLoggingConfig();
}
