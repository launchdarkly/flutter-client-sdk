import 'package:launchdarkly_dart_common/launchdarkly_dart_common.dart'
    show LDLogger;

import 'plugin.dart';
import '../hooks/hook.dart';

List<Hook>? safeGetHooks<TClient>(
    List<PluginBase<TClient>>? plugins, LDLogger logger) {
  if (plugins == null) return null;

  return plugins
      .map<List<Hook>>((plugin) {
        try {
          return plugin.hooks;
        } catch (err) {
          logger.warn(
              'Exception thrown getting hooks for plugin ${plugin.metadata.name}. Unable to get hooks for plugin.');
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
          'Exception thrown when registering plugin ${plugin.metadata.name}');
    }
  });
}
