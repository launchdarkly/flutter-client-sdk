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

/// Returns the hooks for a single [plugin], or `null` if reading
/// [PluginBase.hooks] throws.
List<Hook>? safeGetPluginHooks<TClient>(
    PluginBase<TClient> plugin, LDLogger logger) {
  try {
    return plugin.hooks;
  } catch (err) {
    logger.warn(
        'Exception thrown getting hooks for plugin ${safeGetPluginName(plugin, logger)}. Unable to get hooks for plugin.');
    return null;
  }
}

List<Hook>? safeGetHooks<TClient>(
    List<PluginBase<TClient>>? plugins, LDLogger logger) {
  if (plugins == null) return null;

  return plugins
      .map<List<Hook>>((plugin) => safeGetPluginHooks(plugin, logger) ?? [])
      .expand<Hook>((hooks) => hooks)
      .toList();
}

/// Registers a single [plugin] with [client] and then activates the hooks it
/// contributes.
///
/// This is the single plugin case of [safeRegisterPlugins], and behaves the same
/// way.
void safeRegisterPlugin<TClient>(
    TClient client,
    PluginEnvironmentMetadata metadata,
    PluginBase<TClient> plugin,
    void Function(Hook hook) addHook,
    LDLogger logger) {
  safeRegisterPlugins(client, metadata, [plugin], addHook, logger);
}

/// Registers each of [plugins] with [client], then activates the hooks
/// contributed by those that registered successfully.
///
/// The hooks are activated as the last step, once every plugin has registered,
/// so that no plugin's hooks observe any plugin's [PluginBase.register] call,
/// and a plugin that failed either step contributes none. Exceptions are logged
/// rather than rethrown, so one failing plugin does not stop the others being
/// registered.
void safeRegisterPlugins<TClient>(
    TClient client,
    PluginEnvironmentMetadata metadata,
    List<PluginBase<TClient>>? plugins,
    void Function(Hook hook) addHook,
    LDLogger logger) {
  if (plugins == null) {
    return;
  }

  final hooksToActivate = <Hook>[];

  for (final plugin in plugins) {
    final hooks = safeGetPluginHooks(plugin, logger);
    if (hooks == null) {
      continue;
    }

    try {
      plugin.register(client, metadata);
    } catch (err) {
      logger.warn(
          'Exception thrown when registering plugin ${safeGetPluginName(plugin, logger)}');
      continue;
    }

    hooksToActivate.addAll(hooks);
  }

  for (final hook in hooksToActivate) {
    addHook(hook);
  }
}
