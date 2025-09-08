import 'package:launchdarkly_dart_common/launchdarkly_dart_common.dart'
    show ApplicationInfo;

import '../config/defaults/credential_type.dart';
import '../hooks/hook.dart' show Hook;

/// Metadata about a plugin implementation.
///
/// May be used in logs and analytics to identify the plugin.
final class PluginMetadata {
  /// The name of the plugin.
  final String name;

  const PluginMetadata({required this.name});

  @override
  String toString() {
    return 'PluginMetadata{name: $name}';
  }
}

/// Metadata about the SDK that is running the plugin.
final class PluginSdkMetadata {
  /// The name of the SDK.
  final String name;

  /// The version of the SDK.
  final String version;

  /// If this is a wrapper SDK, then this is the name of the wrapper.
  final String? wrapperName;

  /// If this is a wrapper SDK, then this is the version of the wrapper.
  final String? wrapperVersion;

  PluginSdkMetadata(
      {required this.name,
      required this.version,
      this.wrapperName,
      this.wrapperVersion});

  @override
  String toString() {
    return 'PluginSdkMetadata{name: $name, version: $version,'
        ' wrapperName: $wrapperName, wrapperVersion: $wrapperVersion}';
  }
}

/// Information about the credential used to initialize the SDK.
final class PluginCredentialInfo {
  /// The type of credential.
  final CredentialType type;

  /// The value of the credential.
  final String value;

  PluginCredentialInfo({required this.type, required this.value});

  @override
  String toString() {
    return 'PluginCredentialInfo{type: $type, value: $value}';
  }
}

/// Metadata about the environment where the plugin is running.
final class PluginEnvironmentMetadata {
  /// Metadata about the SDK that is running the plugin.
  final PluginSdkMetadata sdk;

  /// Metadata about the application where the LaunchDarkly SDK is running.
  ///
  /// Plugins only have access to application info collected during
  /// configuration. Application information collected by environment reporting
  /// is not available.
  ///
  /// If access to the environment reporting information is required, then it
  /// is available via the [LDContext] by using hooks.
  ///
  /// Only present if any application information is available.
  final ApplicationInfo? application;

  /// Information about the credential used to initialize the SDK.
  final PluginCredentialInfo credential;

  PluginEnvironmentMetadata(
      {required this.sdk, required this.credential, this.application});

  @override
  String toString() {
    return 'PluginEnvironmentMetadata{sdk: $sdk, credential: $credential,'
        ' application: $application}';
  }
}

/// Base class from which all plugins must derive.
///
/// Implementation note: SDK packages must export a specialized version of this
/// for their specific TClient type. This class cannot provide a type, because
/// it would limit the API to methods available in the base client.
abstract base class PluginBase<TClient> {
  /// Metadata associated with this plugin.
  ///
  /// Plugin implementations must implement this property.
  /// ```dart
  /// final _metadata = PluginMetadata(name: 'MyPluginName');
  ///
  /// @override
  /// PluginMetadata get metadata => _metadata;
  /// ```
  PluginMetadata get metadata;

  /// Registers the plugin with the SDK. Called once during SDK initialization.
  ///
  /// The SDK initialization will typically not have been completed at this
  /// point, so the plugin should take appropriate actions to ensure the SDK is
  /// ready before sending track events or evaluating flags.
  ///
  /// The [client] the plugin is registered with.
  void register(
      TClient client, PluginEnvironmentMetadata environmentMetadata) {}

  /// Hooks which are bundled with this plugin.
  ///
  /// Implementations should override this method to return their bundled
  /// hooks.
  /// ```dart
  /// @override
  /// List<Hook> get hooks => [MyBundledHook()];
  /// ```
  List<Hook> get hooks => [];

  PluginBase();
}
