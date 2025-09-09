import 'package:launchdarkly_common_client/launchdarkly_common_client.dart';

import 'ld_client.dart';

/// Base class from which all plugins must derive.
abstract base class Plugin extends PluginBase<LDClient> {}
