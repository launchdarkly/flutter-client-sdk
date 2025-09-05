import 'dart:math';

import 'package:launchdarkly_dart_common/launchdarkly_dart_common.dart';

import 'hooks/hook.dart';
import 'config/defaults/default_config.dart';
import 'config/events_config.dart';
import 'connection_mode.dart';
import 'config/service_endpoints.dart' as client_endpoints;

/// Configuration which affects how the SDK uses persistence.
final class PersistenceConfig {
  /// The maximum number of contexts to store the flag values for in on-device
  /// storage.
  final int maxCachedContexts;

  /// [maxCachedContexts] sets how many contexts to store the flag values for
  /// in on-device storage.
  ///
  /// The currently configured context is included in this limit.
  ///
  /// The default value of this configuration option is `5`.
  PersistenceConfig({int? maxCachedContexts})
      : maxCachedContexts = max(
            0,
            maxCachedContexts ??
                DefaultConfig.persistenceConfig.defaultMaxCachedContexts);
}

final class PollingConfig {
  /// The current polling interval, if less than min, then the min will be used.
  final Duration pollingInterval;

  /// [pollingInterval] controls the interval between polling requests.
  PollingConfig({Duration? pollingInterval})
      : pollingInterval = pollingInterval ??
            DefaultConfig.pollingConfig.defaultPollingInterval;
}

final class DataSourceConfig {
  /// The data source will attempt to use the reporting method if possible.
  /// The default value is `false`.
  bool useReport;

  /// Include evaluation reasons.
  bool evaluationReasons;

  /// The mode to use for connections when the SDK is initialized.
  ConnectionMode initialConnectionMode;

  /// Settings for the SDK polling data source.
  final PollingConfig polling;

  /// [useReport] determines if the data source will attempt to use the
  /// REPORT http method if possible. For streaming requests on the web
  /// platform report is not supported. The default value is `false`.
  ///
  /// [evaluationReasons] determines if the evaluation reasons should be
  /// included for flag evaluations. Flags which require reasons, such as
  /// those which are part of an experiment, are not affected by this option.
  /// The default value is `false`.
  ///
  /// [initialConnectionMode] determines the mode to use for connections when
  /// the SDK is initialized.
  /// The default is [ConnectionMode.streaming]. If the mode is set to
  /// [ConnectionMode.offline] then the data source will not request data from
  /// LaunchDarkly, but the sending of events will be unaffected. In order
  /// to completely disable network activity use [LDConfig.offline].
  DataSourceConfig(
      {bool? useReport,
      bool? evaluationReasons,
      ConnectionMode? initialConnectionMode,
      PollingConfig? polling})
      : useReport =
            useReport ?? DefaultConfig.dataSourceConfig.defaultUseReport,
        evaluationReasons = evaluationReasons ??
            DefaultConfig.dataSourceConfig.defaultWithReasons,
        initialConnectionMode = initialConnectionMode ??
            DefaultConfig.dataSourceConfig.defaultInitialConnectionMode,
        polling = polling ?? PollingConfig();
}

/// Configuration common to dart based SDKs.
///
/// SDK implementations should extend this class with a final version that
/// adds any platform specific configuration.
abstract class LDCommonConfig {
  /// The credential the SDK should use.
  final String sdkCredential;

  /// Controls the collection of automatic environment attributes.
  final AutoEnvAttributes autoEnvAttributes;

  /// Information about the application the LaunchDarkly SDK is running in.
  /// This is optional.
  final ApplicationInfo? applicationInfo;

  /// Common http configuration which will apply to all http requests made
  /// by the SDK. As different platforms have different constraints, and the
  /// SDK adds its own configuration (additional headers for instance), not
  /// all settings are guaranteed to apply to all connections on all platforms.
  final HttpProperties httpProperties;

  /// Specifies the base service URIs used by SDK components.
  final ServiceEndpoints serviceEndpoints;

  /// Configuration for analytics and diagnostic events.
  final EventsConfig events;

  /// Configuration for managing SDK persistence. The SDK persists things such
  /// as anonymous context keys and flag configuration.
  final PersistenceConfig persistence;

  /// Disables all network calls from the LaunchDarkly client.
  final bool offline;

  /// The logger the SDK will use. By default the logger will log using `print`
  /// and will include `info` level log messages.
  final LDLogger logger;

  /// Settings for SDK data sources.
  final DataSourceConfig dataSourceConfig;

  /// Whether all context attributes (except the context key) should be marked
  /// as private, and not sent to LaunchDarkly in analytics events.
  final bool allAttributesPrivate;

  /// A list of attribute references that will be marked private.
  final List<String> globalPrivateAttributes;

  /// An initial list of hooks.
  final List<Hook>? hooks;

  LDCommonConfig(this.sdkCredential, this.autoEnvAttributes,
      {this.applicationInfo,
      HttpProperties? httpProperties,
      ServiceEndpoints? serviceEndpoints,
      EventsConfig? events,
      PersistenceConfig? persistence,
      bool? offline,
      LDLogger? logger,
      DataSourceConfig? dataSourceConfig,
      bool? allAttributesPrivate,
      List<String>? globalPrivateAttributes,
      this.hooks})
      : httpProperties = httpProperties ?? HttpProperties(),
        serviceEndpoints =
            serviceEndpoints ?? client_endpoints.ServiceEndpoints(),
        events = events ?? EventsConfig(),
        persistence = persistence ?? PersistenceConfig(),
        offline = offline ?? DefaultConfig.defaultOffline,
        logger = logger ?? LDLogger(),
        dataSourceConfig = dataSourceConfig ?? DataSourceConfig(),
        allAttributesPrivate =
            allAttributesPrivate ?? DefaultConfig.allAttributesPrivate,
        globalPrivateAttributes = globalPrivateAttributes ?? [];
}

/// Enable / disable options for Auto Environment Attributes functionality.  When enabled, the SDK will automatically
/// provide data about the mobile environment where the application is running. This data makes it simpler to target
/// your mobile customers based on application name or version, or on device characteristics including manufacturer,
/// model, operating system, locale, and so on. We recommend enabling this when you configure the SDK.  See
/// https://docs.launchdarkly.com/sdk/features/environment-attributes for more documentation.
///
/// For example, consider a “dark mode” feature being added to an app. Versions 10 through 14 contain early,
/// incomplete versions of the feature. These versions are available to all customers, but the “dark mode” feature is only
/// enabled for testers.  With version 15, the feature is considered complete. With Auto Environment Attributes enabled,
/// you can use targeting rules to enable "dark mode" for all customers who are using version 15 or greater, and ensure
/// that customers on previous versions don't use the earlier, unfinished version of the feature.
enum AutoEnvAttributes { enabled, disabled }
