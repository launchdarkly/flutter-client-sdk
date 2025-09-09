import 'package:launchdarkly_dart_common/launchdarkly_dart_common.dart'
    show LDLogger;

import 'plugin.dart';
import '../hooks/hook.dart';

const _unknownPlugin = 'unknown';

String safeGetPluginName<TClient>(PluginBase<TClient> plugin, LDLogger logger) {
  try {
    return plugin.metadata.name;
  } catch (err) {
    logger.warn('Exception thrown access the name of a registered plugin.');
    return _unknownPlugin;
  }
}

List<Hook>? safeGetHooks<TClient>(
    List<PluginBase<TClient>>? plugins, LDLogger logger) {
  if (plugins == null) return null;

  return plugins
      .map<List<Hook>>((plugin) {
        try {
          return plugin.hooks;
        } catch (err) {
          logger.warn(
              'Exception thrown getting hooks for plugin ${safeGetPluginName(plugin, logger)}. Unable to get hooks for plugin.');
        }
        return [];
      })
      .expand<Hook>((hooks) => hooks)
      .toList();
}

void safeRegisterPlugins<TClient>(
    TClient client,
    PluginEnvironmentMetadata metadata,
    List<PluginBase<TClient>>? plugins,
    LDLogger logger) {
  plugins?.forEach((plugin) {
    try {
      plugin.register(client, metadata);
    } catch (err) {
      logger.warn(
          'Exception thrown when registering plugin ${safeGetPluginName(plugin, logger)}');
    }
  });
}
