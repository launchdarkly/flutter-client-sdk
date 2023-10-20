// @dart=3.1

/// A configuration object used when initializing the [LDClient].
final class LDConfig {
  /// The configured mobile SDK key.
  final String mobileKey;

  final String? applicationId;
  final String? applicationName;
  final String? applicationVersion;
  final String? applicationVersionName;

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

  /// The configured background polling interval in milliseconds.
  final int backgroundPollingIntervalMillis;

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
      : mobileKey = builder._mobileKey,
        applicationId = builder._applicationId,
        applicationName = builder._applicationName,
        applicationVersion = builder._applicationVersion,
        applicationVersionName = builder._applicationVersionName,
        pollUri = builder._pollUri,
        eventsUri = builder._eventsUri,
        streamUri = builder._streamUri,
        eventsCapacity = builder._eventsCapacity,
        eventsFlushIntervalMillis = builder._eventsFlushIntervalMillis,
        connectionTimeoutMillis = builder._connectionTimeoutMillis,
        pollingIntervalMillis = builder._pollingIntervalMillis,
        backgroundPollingIntervalMillis =
            builder._backgroundPollingIntervalMillis,
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

  Map<String, dynamic> toCodecValue(String wrapperVersion) {
    final Map<String, dynamic> result = <String, dynamic>{};
    result['mobileKey'] = mobileKey;
    result['applicationId'] = applicationId;
    result['applicationName'] = applicationName;
    result['applicationVersion'] = applicationVersion;
    result['applicationVersionName'] = applicationVersionName;
    result['pollUri'] = pollUri;
    result['eventsUri'] = eventsUri;
    result['streamUri'] = streamUri;
    result['eventsCapacity'] = eventsCapacity;
    result['eventsFlushIntervalMillis'] = eventsFlushIntervalMillis;
    result['connectionTimeoutMillis'] = connectionTimeoutMillis;
    result['pollingIntervalMillis'] = pollingIntervalMillis;
    result['backgroundPollingIntervalMillis'] = backgroundPollingIntervalMillis;
    result['diagnosticRecordingIntervalMillis'] =
        diagnosticRecordingIntervalMillis;
    result['maxCachedContexts'] = maxCachedContexts;
    result['stream'] = stream;
    result['offline'] = offline;
    result['disableBackgroundUpdating'] = disableBackgroundUpdating;
    result['useReport'] = useReport;
    result['evaluationReasons'] = evaluationReasons;
    result['diagnosticOptOut'] = diagnosticOptOut;
    result['autoEnvAttributes'] = autoEnvAttributes;
    result['allAttributesPrivate'] = allAttributesPrivate;
    result['privateAttributes'] = privateAttributes;
    result['wrapperName'] = 'FlutterClientSdk';
    result['wrapperVersion'] = wrapperVersion;
    return result;
  }
}

/// A builder for [LDConfig].
class LDConfigBuilder {
  String _mobileKey;

  String? _applicationId;
  String? _applicationName;
  String? _applicationVersion;
  String? _applicationVersionName;

  String _pollUri = "https://clientsdk.launchdarkly.com";
  String _eventsUri = "https://events.launchdarkly.com";
  String _streamUri = "https://clientstream.launchdarkly.com";

  int _eventsCapacity = 100;
  int _eventsFlushIntervalMillis = 30 * 1000;
  int _connectionTimeoutMillis = 10 * 1000;
  int _pollingIntervalMillis = 5 * 60 * 1000;
  int _backgroundPollingIntervalMillis = 60 * 60 * 1000;
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
  Set<String> _privateAttributes = Set();

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
  LDConfigBuilder(this._mobileKey, AutoEnvAttributes autoEnvAttributes) {
    _autoEnvAttributes = autoEnvAttributes ==
        AutoEnvAttributes.Enabled; // mapping enum to boolean
  }

  /// A unique identifier representing the application where the LaunchDarkly SDK is running.
  ///
  /// This can be specified as any string value as long as it only uses the following characters:
  /// ASCII letters, ASCII digits, period, hyphen, underscore. A string containing any other
  /// characters will be ignored.
  ///
  /// Example: 'authentication-service'
  LDConfigBuilder applicationId(String applicationId) {
    this._applicationId = applicationId;
    return this;
  }

  /// A friendly name for the application where the LaunchDarkly SDK is running.
  ///
  /// This can be specified as any string value as long as it only uses the following characters:
  /// ASCII letters, ASCII digits, spaces, period, hyphen, underscore. A string containing any other
  /// characters will be ignored.
  ///
  /// Example: 'My Cool Application'
  LDConfigBuilder applicationName(String applicationName) {
    this._applicationName = applicationName;
    return this;
  }

  /// A unique identifier representing the version of the application where the LaunchDarkly SDK is
  /// running.
  ///
  /// This can be specified as any string value as long as it only uses the following characters:
  /// ASCII letters, ASCII digits, period, hyphen, underscore. A string containing any other
  /// characters will be ignored.
  ///
  /// Example: `1.0.0` (standard version string) or `abcdef` (sha prefix)
  ///
  LDConfigBuilder applicationVersion(String applicationVersion) {
    this._applicationVersion = applicationVersion;
    return this;
  }

  /// A friendly name for the application version where the LaunchDarkly SDK is running.
  ///
  /// This can be specified as any string value as long as it only uses the following characters:
  /// ASCII letters, ASCII digits, spaces, period, hyphen, underscore. A string containing any other
  /// characters will be ignored.
  ///
  /// Example: '1.0'
  LDConfigBuilder applicationVersionName(String applicationVersionName) {
    this._applicationVersionName = applicationVersionName;
    return this;
  }

  /// Sets the URI for polling requests.
  LDConfigBuilder pollUri(String pollUri) {
    this._pollUri = pollUri;
    return this;
  }

  /// Sets the URI for eventing requests.
  LDConfigBuilder eventsUri(String eventsUri) {
    this._eventsUri = eventsUri;
    return this;
  }

  /// Sets the URI for stream requests.
  LDConfigBuilder streamUri(String streamUri) {
    this._streamUri = streamUri;
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
    this._eventsCapacity = eventsCapacity;
    return this;
  }

  /// Sets the maximum amount of time in between sending analytics events to LaunchDarkly.
  LDConfigBuilder eventsFlushIntervalMillis(int eventsFlushIntervalMillis) {
    this._eventsFlushIntervalMillis = eventsFlushIntervalMillis;
    return this;
  }

  /// Sets the connection timeout for network requests.
  LDConfigBuilder connectionTimeoutMillis(int connectionTimeoutMillis) {
    this._connectionTimeoutMillis = connectionTimeoutMillis;
    return this;
  }

  /// Sets the interval between foreground flag poll requests.
  ///
  /// Foreground polling is only used when streaming has been disabled with [LDConfigBuilder.stream].
  LDConfigBuilder pollingIntervalMillis(int pollingIntervalMillis) {
    this._pollingIntervalMillis = pollingIntervalMillis;
    return this;
  }

  /// Sets the interval between background flag poll requests.
  ///
  /// See [LDConfigBuilder.disableBackgroundUpdating] to disable background polls entirely.
  LDConfigBuilder backgroundPollingIntervalMillis(
      int backgroundPollingIntervalMillis) {
    this._backgroundPollingIntervalMillis = backgroundPollingIntervalMillis;
    return this;
  }

  /// Set the interval at which periodic diagnostic data is sent.
  ///
  /// The default is every 15 minutes (900,000 milliseconds) and the minimum value is 300,000 (5 minutes). See
  /// [LDConfigBuilder.diagnosticOptOut] for more information on the diagnostic data being sent.
  LDConfigBuilder diagnosticRecordingIntervalMillis(
      int diagnosticRecordingIntervalMillis) {
    this._diagnosticRecordingIntervalMillis = diagnosticRecordingIntervalMillis;
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
    this._maxCachedContexts = maxCachedContexts < 0 ? -1 : maxCachedContexts;
    return this;
  }

  /// Enables or disables real-time streaming flag updates.
  ///
  /// Defaults to `true` (streaming enabled), when `false` polling is used instead.
  LDConfigBuilder stream(bool stream) {
    this._stream = stream;
    return this;
  }

  /// Disables or enables network calls from the LaunchDarkly client.
  ///
  /// Defaults to `false` (network calls enabled), set to `true` to disable network calls.
  ///
  /// Can also be configured at runtime using [LDClient.setOnline].
  LDConfigBuilder offline(bool offline) {
    this._offline = offline;
    return this;
  }

  /// Disables or enables background polling requests for flag values.
  ///
  /// See [LDConfigBuilder.backgroundPollingIntervalMillis] for configuring the interval between background polling
  /// requests.
  LDConfigBuilder disableBackgroundUpdating(bool disableBackgroundUpdating) {
    this._disableBackgroundUpdating = disableBackgroundUpdating;
    return this;
  }

  /// Configure whether the SDK should use the HTTP `REPORT` verb for flag requests.
  ///
  /// Normally the SDK uses a `GET` request, with the user attributes encoded in the URL. This option configures the
  /// SDK to instead include the user in the HTTP `body` of a `REPORT` request.
  LDConfigBuilder useReport(bool useReport) {
    this._useReport = useReport;
    return this;
  }

  /// Configure whether the SDK will request evaluation reasons to be included in flag data from the service.
  ///
  /// This will allow the additional information included in [LDEvaluationDetail] to be populated when using the
  /// variation detail methods such as [LDClient.boolVariationDetail].
  LDConfigBuilder evaluationReasons(bool evaluationReasons) {
    this._evaluationReasons = evaluationReasons;
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
    this._diagnosticOptOut = diagnosticOptOut;
    return this;
  }

  /// Configures the SDK to never include optional attribute values in analytics events.
  LDConfigBuilder allAttributesPrivate(bool allAttributesPrivate) {
    this._allAttributesPrivate = allAttributesPrivate;
    return this;
  }

  /// Sets a `Set` of private attributes to never include the values for in analytics events.
  LDConfigBuilder privateAttributes(Set<String> privateAttributes) {
    this._privateAttributes = privateAttributes;
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
enum AutoEnvAttributes { Enabled, Disabled }
