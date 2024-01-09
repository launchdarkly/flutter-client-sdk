import 'package:launchdarkly_dart_common/ld_common.dart';

/// A configuration object used when initializing the [LDClient].
final class LDConfig {
  /// The configured SDK credential. For mobile and desktop deployments this
  /// should be the mobile key. For web deployments this should be a client-side
  /// id.
  final String sdkCredential;

  /// The ApplicationInfo for the application the SDK is being used in.
  final ApplicationInfo? applicationInfo;

  /// The configured URI for polling requests.
  final String pollUri;

  /// The configured URI for eventing requests.
  final String eventsUri;

  /// The configured URI for stream requests.
  final String streamUri;

  /// The configured event capacity.
  final int eventsCapacity;

  /// The configured event flush interval in milliseconds.
  final int eventsFlushIntervalMillis;

  /// The configured connection timeout in milliseconds.
  final int connectionTimeoutMillis;

  /// The configured foreground polling interval in milliseconds.
  final int pollingIntervalMillis;

  /// The configured diagnostic recording interval in milliseconds.
  final int diagnosticRecordingIntervalMillis;

  /// The count of contexts to store the flag values for in on-device storage.
  ///
  /// A value of `-1` indicates that an unlimited number of contexts will be cached locally.
  final int maxCachedContexts;

  /// Whether the SDK is configured to use a streaming connection when in the foreground.
  final bool stream;

  /// Whether the SDK is configured not to connect to LaunchDarkly on [LDClient.start].
  final bool offline;

  /// Whether the SDK is configured to disable polling for feature flag values when the application is in the background.
  final bool disableBackgroundUpdating;

  /// Whether the SDK is configured to use the HTTP `REPORT` verb for flag requests.
  final bool useReport;

  /// Whether the SDK is configured to request evaluation reasons to be included in flag data from the service.
  final bool evaluationReasons;

  /// Whether the SDK is configured to not send diagnostic data to LaunchDarkly.
  final bool diagnosticOptOut;

  /// Whether the SDK will automatically provide data about the mobile environment
  /// where the application is running.
  final bool autoEnvAttributes;

  /// Whether the SDK is configured to never include context attribute values in analytics requests.
  final bool allAttributesPrivate;

  /// The configured set of attributes to never include values for in analytics requests.
  final List<String>? privateAttributes;

  LDConfig._builder(LDConfigBuilder builder)
      : sdkCredential = builder._credential,
        applicationInfo = builder._applicationInfo,
        pollUri = builder._pollUri,
        eventsUri = builder._eventsUri,
        streamUri = builder._streamUri,
        eventsCapacity = builder._eventsCapacity,
        eventsFlushIntervalMillis = builder._eventsFlushIntervalMillis,
        connectionTimeoutMillis = builder._connectionTimeoutMillis,
        pollingIntervalMillis = builder._pollingIntervalMillis,
        diagnosticRecordingIntervalMillis =
            builder._diagnosticRecordingIntervalMillis,
        maxCachedContexts = builder._maxCachedContexts,
        stream = builder._stream,
        offline = builder._offline,
        disableBackgroundUpdating = builder._disableBackgroundUpdating,
        useReport = builder._useReport,
        evaluationReasons = builder._evaluationReasons,
        diagnosticOptOut = builder._diagnosticOptOut,
        autoEnvAttributes = builder._autoEnvAttributes,
        allAttributesPrivate = builder._allAttributesPrivate,
        privateAttributes = builder._privateAttributes.isEmpty
            ? null
            : List.unmodifiable(builder._privateAttributes);
}

/// A builder for [LDConfig].
class LDConfigBuilder {
  final String _credential;

  ApplicationInfo? _applicationInfo;

  String _pollUri = 'https://clientsdk.launchdarkly.com';
  String _eventsUri = 'https://events.launchdarkly.com';
  String _streamUri = 'https://clientstream.launchdarkly.com';

  int _eventsCapacity = 100;
  int _eventsFlushIntervalMillis = 30 * 1000;
  int _connectionTimeoutMillis = 10 * 1000;
  int _pollingIntervalMillis = 5 * 60 * 1000;
  int _diagnosticRecordingIntervalMillis = 15 * 60 * 1000;
  int _maxCachedContexts = 5;

  bool _stream = true;
  bool _offline = false;
  bool _disableBackgroundUpdating = true;
  bool _useReport = false;
  bool _evaluationReasons = false;
  bool _diagnosticOptOut = false;
  bool _autoEnvAttributes = false;

  bool _allAttributesPrivate = false;
  Set<String> _privateAttributes = {};

  ///  Create a new `LDConfigBuilder`.  Configurable values are all set to their
  ///  default values. The client app can modify these values as desired.
  ///
  /// - Parameters:
  ///     - mobileKey: key for authentication with LaunchDarkly.
  ///     - autoEnvAttributes: Enable / disable Auto Environment Attributes functionality.
  ///     When enabled, the SDK will automatically provide data about the mobile environment
  ///     where the application is running. This data makes it simpler to target your mobile
  ///     customers based on application name or version, or on device characteristics including
  ///     manufacturer, model, operating system, locale, and so on. We recommend enabling
  ///     this when you configure the SDK.  See https://docs.launchdarkly.com/sdk/features/environment-attributes
  ///     for more documentation.
  LDConfigBuilder(this._credential, AutoEnvAttributes autoEnvAttributes) {
    _autoEnvAttributes = autoEnvAttributes ==
        AutoEnvAttributes.enabled; // mapping enum to boolean
  }

  /// Sets the ApplicationInfo representing the application this SDK is used in.
  LDConfigBuilder applicationInfo(ApplicationInfo applicationInfo) {
    _applicationInfo = applicationInfo;
    return this;
  }

  /// Sets the URI for polling requests.
  LDConfigBuilder pollUri(String pollUri) {
    _pollUri = pollUri;
    return this;
  }

  /// Sets the URI for eventing requests.
  LDConfigBuilder eventsUri(String eventsUri) {
    _eventsUri = eventsUri;
    return this;
  }

  /// Sets the URI for stream requests.
  LDConfigBuilder streamUri(String streamUri) {
    _streamUri = streamUri;
    return this;
  }

  /// Set the capacity of the event buffer.
  ///
  /// The client buffers up to this many events in memory before flushing. If the capacity is exceeded before the buffer
  /// is flushed, events will be discarded. Increasing the capacity means that events are less likely to be discarded,
  /// at the cost of potentially consuming more memory.
  ///
  /// See [LDConfigBuilder.eventsFlushIntervalMillis] for configuring the flush interval.
  LDConfigBuilder eventsCapacity(int eventsCapacity) {
    _eventsCapacity = eventsCapacity;
    return this;
  }

  /// Sets the maximum amount of time in between sending analytics events to LaunchDarkly.
  LDConfigBuilder eventsFlushIntervalMillis(int eventsFlushIntervalMillis) {
    _eventsFlushIntervalMillis = eventsFlushIntervalMillis;
    return this;
  }

  /// Sets the connection timeout for network requests.
  LDConfigBuilder connectionTimeoutMillis(int connectionTimeoutMillis) {
    _connectionTimeoutMillis = connectionTimeoutMillis;
    return this;
  }

  /// Sets the interval between foreground flag poll requests.
  ///
  /// Foreground polling is only used when streaming has been disabled with [LDConfigBuilder.stream].
  LDConfigBuilder pollingIntervalMillis(int pollingIntervalMillis) {
    _pollingIntervalMillis = pollingIntervalMillis;
    return this;
  }

  /// Set the interval at which periodic diagnostic data is sent.
  ///
  /// The default is every 15 minutes (900,000 milliseconds) and the minimum value is 300,000 (5 minutes). See
  /// [LDConfigBuilder.diagnosticOptOut] for more information on the diagnostic data being sent.
  LDConfigBuilder diagnosticRecordingIntervalMillis(
      int diagnosticRecordingIntervalMillis) {
    _diagnosticRecordingIntervalMillis = diagnosticRecordingIntervalMillis;
    return this;
  }

  /// Sets how many contexts to store the flag values for in on-device storage.
  ///
  /// A negative value indicates that the SDK should store the flags for every context it is configured for, never removing
  /// the stored values for the least recently used context
  ///
  /// The currently configured context is not considered part of this limit.
  ///
  /// The default value of this configuration option is `5`.
  LDConfigBuilder maxCachedContexts(int maxCachedContexts) {
    _maxCachedContexts = maxCachedContexts < 0 ? -1 : maxCachedContexts;
    return this;
  }

  /// Enables or disables real-time streaming flag updates.
  ///
  /// Defaults to `true` (streaming enabled), when `false` polling is used instead.
  LDConfigBuilder stream(bool stream) {
    _stream = stream;
    return this;
  }

  /// Disables or enables network calls from the LaunchDarkly client.
  ///
  /// Defaults to `false` (network calls enabled), set to `true` to disable network calls.
  ///
  /// Can also be configured at runtime using [LDClient.setOnline].
  LDConfigBuilder offline(bool offline) {
    _offline = offline;
    return this;
  }

  /// Disables or enables background polling requests for flag values.
  ///
  /// See [LDConfigBuilder.backgroundPollingIntervalMillis] for configuring the interval between background polling
  /// requests.
  LDConfigBuilder disableBackgroundUpdating(bool disableBackgroundUpdating) {
    _disableBackgroundUpdating = disableBackgroundUpdating;
    return this;
  }

  /// Configure whether the SDK should use the HTTP `REPORT` verb for flag requests.
  ///
  /// Normally the SDK uses a `GET` request, with the user attributes encoded in the URL. This option configures the
  /// SDK to instead include the user in the HTTP `body` of a `REPORT` request.
  LDConfigBuilder useReport(bool useReport) {
    _useReport = useReport;
    return this;
  }

  /// Configure whether the SDK will request evaluation reasons to be included in flag data from the service.
  ///
  /// This will allow the additional information included in [LDEvaluationDetail] to be populated when using the
  /// variation detail methods such as [LDClient.boolVariationDetail].
  LDConfigBuilder evaluationReasons(bool evaluationReasons) {
    _evaluationReasons = evaluationReasons;
    return this;
  }

  /// Set to true to opt out of sending diagnostics data.
  ///
  /// Unless [LDConfig.diagnosticOptOut] is `true`, the client will send some diagnostics data to the LaunchDarkly
  /// servers in order to assist in the development of future SDK improvements. These diagnostics consist of an initial
  /// payload containing some details of the SDK in use, the SDK's configuration, and the platform the SDK is being run
  /// on; as well as payloads sent periodically with information on irregular occurrences such as dropped events.
  ///
  /// See [LDConfigBuilder.diagnosticRecordingIntervalMillis] for configuration of periodic payload frequency.
  LDConfigBuilder diagnosticOptOut(bool diagnosticOptOut) {
    _diagnosticOptOut = diagnosticOptOut;
    return this;
  }

  /// Configures the SDK to never include optional attribute values in analytics events.
  LDConfigBuilder allAttributesPrivate(bool allAttributesPrivate) {
    _allAttributesPrivate = allAttributesPrivate;
    return this;
  }

  /// Sets a `Set` of private attributes to never include the values for in analytics events.
  LDConfigBuilder privateAttributes(Set<String> privateAttributes) {
    _privateAttributes = privateAttributes;
    return this;
  }

  /// Create an [LDConfig] from the current configuration of the builder.
  LDConfig build() {
    return LDConfig._builder(this);
  }
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
