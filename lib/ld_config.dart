// @dart=2.12
part of launchdarkly_flutter_client_sdk;

/// A configuration object used when initializing the [LDClient].
class LDConfig {
  /// The configured mobile SDK key.
  final String mobileKey;

  final String applicationId;
  final String applicationVersion;

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

  /// Whether the SDK is configured to never include user attribute values in analytics requests.
  final bool allAttributesPrivate;
  /// The configured set of attributes to never include values for in analytics requests.
  final List<String>? privateAttributeNames;

  LDConfig._builder(LDConfigBuilder builder) :
        mobileKey = builder._mobileKey,
        applicationId = builder._applicationId,
        applicationVersion = builder._applicationVersion,
        pollUri = builder._pollUri,
        eventsUri = builder._eventsUri,
        streamUri = builder._streamUri,
        eventsCapacity = builder._eventsCapacity,
        eventsFlushIntervalMillis = builder._eventsFlushIntervalMillis,
        connectionTimeoutMillis = builder._connectionTimeoutMillis,
        pollingIntervalMillis = builder._pollingIntervalMillis,
        backgroundPollingIntervalMillis = builder._backgroundPollingIntervalMillis,
        diagnosticRecordingIntervalMillis = builder._diagnosticRecordingIntervalMillis,
        maxCachedContexts = builder._maxCachedContexts,
        stream = builder._stream,
        offline = builder._offline,
        disableBackgroundUpdating = builder._disableBackgroundUpdating,
        useReport = builder._useReport,
        evaluationReasons = builder._evaluationReasons,
        diagnosticOptOut = builder._diagnosticOptOut,
        allAttributesPrivate = builder._allAttributesPrivate,
        privateAttributeNames = builder._privateAttributeNames.isEmpty ? null : List.unmodifiable(builder._privateAttributeNames);

  Map<String, dynamic> toCodecValue(String wrapperVersion) {
    final Map<String, dynamic> result = <String, dynamic>{};
    result['mobileKey'] = mobileKey;
    result['applicationId'] = applicationId;
    result['applicationVersion'] = applicationVersion;
    result['pollUri'] = pollUri;
    result['eventsUri'] = eventsUri;
    result['streamUri'] = streamUri;
    result['eventsCapacity'] = eventsCapacity;
    result['eventsFlushIntervalMillis'] = eventsFlushIntervalMillis;
    result['connectionTimeoutMillis'] = connectionTimeoutMillis;
    result['pollingIntervalMillis'] = pollingIntervalMillis;
    result['backgroundPollingIntervalMillis'] = backgroundPollingIntervalMillis;
    result['diagnosticRecordingIntervalMillis'] = diagnosticRecordingIntervalMillis;
    result['maxCachedContexts'] = maxCachedContexts;
    result['stream'] = stream;
    result['offline'] = offline;
    result['disableBackgroundUpdating'] = disableBackgroundUpdating;
    result['useReport'] = useReport;
    result['evaluationReasons'] = evaluationReasons;
    result['diagnosticOptOut'] = diagnosticOptOut;
    result['allAttributesPrivate'] = allAttributesPrivate;
    result['privateAttributeNames'] = privateAttributeNames;
    result['wrapperName'] = 'FlutterClientSdk';
    result['wrapperVersion'] = wrapperVersion;
    return result;
  }
}

/// A builder for [LDConfig].
class LDConfigBuilder {
  String _mobileKey;

  String _applicationId = "";
  String _applicationVersion = "";

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

  bool _allAttributesPrivate = false;
  Set<String> _privateAttributeNames = Set();

  /// Create a new `LDConfigBuilder` for the given mobile key.
  LDConfigBuilder(this._mobileKey);

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
  LDConfigBuilder backgroundPollingIntervalMillis(int backgroundPollingIntervalMillis) {
    this._backgroundPollingIntervalMillis = backgroundPollingIntervalMillis;
    return this;
  }

  /// Set the interval at which periodic diagnostic data is sent.
  ///
  /// The default is every 15 minutes (900,000 milliseconds) and the minimum value is 300,000 (5 minutes). See
  /// [LDConfigBuilder.diagnosticOptOut] for more information on the diagnostic data being sent.
  LDConfigBuilder diagnosticRecordingIntervalMillis(int diagnosticRecordingIntervalMillis) {
    this._diagnosticRecordingIntervalMillis = diagnosticRecordingIntervalMillis;
    return this;
  }

  /// Sets how many users to store the flag values for in on-device storage.
  ///
  /// A negative value indicates that the SDK should store the flags for every user it is configured for, never removing
  /// the stored values for the least recently used users when the count exceed `maxCachedUsers`.
  ///
  /// The currently configured user is not considered part of this limit.
  ///
  /// The default value of this configuration option is `5`.
  @Deprecated("In favor of maxCachedContexts")
  LDConfigBuilder maxCachedUsers(int maxCachedUsers) {
    return this.maxCachedContexts(maxCachedUsers);
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
  LDConfigBuilder privateAttributeNames(Set<String> privateAttributeNames) {
    this._privateAttributeNames = privateAttributeNames;
    return this;
  }

  /// Create an [LDConfig] from the current configuration of the builder.
  LDConfig build() {
    return LDConfig._builder(this);
  }
}
