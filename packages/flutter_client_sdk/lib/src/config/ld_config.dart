import 'package:launchdarkly_dart_client/ld_client.dart';

import 'defaults/flutter_default_config.dart';

/// Configuration which affects how the SDK responds to events affecting
/// the application.
final class ApplicationEvents {
  /// Automatically detect and react to application entering
  /// background/foreground.
  bool backgrounding;

  /// Automatically detect network connectivity and react to changes.
  bool networkAvailability;

  /// Setting [backgrounding] to true allows the SDK to detect and react to
  /// the application entering the background or foreground. The default
  /// value is `true`.
  ///
  /// Setting [networkAvailability] to true allows the SDK to detect and react
  /// to network connectivity changes. For instance the SDK may not try to send
  /// events if it detects the network is not available. The default value is
  /// `true`.
  ApplicationEvents({bool? backgrounding, bool? networkAvailability})
      : backgrounding = backgrounding ??
            FlutterDefaultConfig.applicationEventsConfig.defaultBackgrounding,
        networkAvailability = networkAvailability ??
            FlutterDefaultConfig
                .applicationEventsConfig.defaultNetworkAvailability;
}

final class LDConfig extends LDCommonConfig {
  /// Configuration which affects how the SDK responds to events affecting
  /// the application.
  ApplicationEvents applicationEvents;

  /// [sdkCredential] set the credential for the SDK. This can be either a
  /// mobile key or a client-side ID depending on the build configuration.
  /// Refer to [CredentialSource.fromEnvironment] for information about
  /// selecting the correct key during build time.
  ///
  /// [autoEnvAttributes] controls the collection of automatic environment
  /// attributes. It is required to be provided.
  ///
  /// [applicationInfo] sets information about the application where the
  /// LaunchDarkly SDK is running.
  ///
  /// [httpProperties] contains common http configuration which will apply to
  /// all http requests made by the SDK. As different platforms have different
  /// constraints, and the SDK adds its own configuration (additional headers
  /// for instance), not all settings are guaranteed to apply to all connections
  /// on all platforms. Generally this option will not need to be specified.
  ///
  /// [serviceEndpoints] specifies the base service URIs used by SDK components.
  /// Generally the endpoints will not need to be set unless you are using
  /// the federal instance, relay proxy, or have specific network constraints.
  ///
  /// [events] defines configuration for analytics and diagnostic events.
  ///
  /// [offline] is used to disable all network calls from the LaunchDarkly
  /// client. Setting offline here will make the SDK permanently offline.
  /// You can temporarily make the SDK offline using the offline property
  /// of the client.
  ///
  /// [logger] can be used to customize the logging done by the SDK.
  ///
  /// [dataSourceConfig] contains settings for the SDK's data sources.
  ///
  /// [applicationEvents] controls how the SDK responds to events which
  /// affect the application like network connectivity and foreground state.
  LDConfig(super.sdkCredential, super.autoEnvAttributes,
      {super.applicationInfo,
      super.httpProperties,
      super.serviceEndpoints,
      super.events,
      super.persistence,
      super.offline,
      super.logger,
      super.dataSourceConfig,
      ApplicationEvents? applicationEvents})
      : applicationEvents = applicationEvents ?? ApplicationEvents();
}
