part of launchdarkly_flutter_client_sdk;

class LDConfig {
  final String mobileKey;

  final String baseUri;
  final String eventsUri;
  final String streamUri;

  final int eventsCapacity;
  final int eventsFlushIntervalMillis;
  final int connectionTimeoutMillis;
  final int pollingIntervalMillis;
  final int backgroundPollingIntervalMillis;
  final int diagnosticRecordingIntervalMillis;

  final bool stream;
  final bool offline;
  final bool disableBackgroundUpdating;
  final bool useReport;
  final bool inlineUsersInEvents;
  final bool evaluationReasons;
  final bool diagnosticOptOut;

  final bool allAttributesPrivate;
  final Set<String> privateAttributeNames;

  LDConfig._builder(LDConfigBuilder builder) :
        mobileKey = builder._mobileKey,
        baseUri = builder._baseUri,
        eventsUri = builder._eventsUri,
        streamUri = builder._streamUri,
        eventsCapacity = builder._eventsCapacity,
        eventsFlushIntervalMillis = builder._eventsFlushIntervalMillis,
        connectionTimeoutMillis = builder._connectionTimeoutMillis,
        pollingIntervalMillis = builder._pollingIntervalMillis,
        backgroundPollingIntervalMillis = builder._backgroundPollingIntervalMillis,
        diagnosticRecordingIntervalMillis = builder._diagnosticRecordingIntervalMillis,
        stream = builder._stream,
        offline = builder._offline,
        disableBackgroundUpdating = builder._disableBackgroundUpdating,
        useReport = builder._useReport,
        inlineUsersInEvents = builder._inlineUsersInEvents,
        evaluationReasons = builder._evaluationReasons,
        diagnosticOptOut = builder._diagnosticOptOut,
        allAttributesPrivate = builder._allAttributesPrivate,
        privateAttributeNames = builder._privateAttributeNames;

  Map<String, dynamic> _toMap() {
    final Map<String, dynamic> result = <String, dynamic>{};
    result['mobileKey'] = mobileKey;
    result['baseUri'] = baseUri;
    result['eventsUri'] = eventsUri;
    result['streamUri'] = streamUri;
    result['eventsCapacity'] = eventsCapacity;
    result['eventsFlushIntervalMillis'] = eventsFlushIntervalMillis;
    result['connectionTimeoutMillis'] = connectionTimeoutMillis;
    result['pollingIntervalMillis'] = pollingIntervalMillis;
    result['backgroundPollingIntervalMillis'] = backgroundPollingIntervalMillis;
    result['diagnosticRecordingIntervalMillis'] = diagnosticRecordingIntervalMillis;
    result['stream'] = stream;
    result['offline'] = offline;
    result['disableBackgroundUpdating'] = disableBackgroundUpdating;
    result['useReport'] = useReport;
    result['inlineUsersInEvents'] = inlineUsersInEvents;
    result['evaluationReasons'] = evaluationReasons;
    result['diagnosticOptOut'] = diagnosticOptOut;
    result['allAttributesPrivate'] = allAttributesPrivate;
    result['privateAttributeNames'] = privateAttributeNames == null ? null : privateAttributeNames.toList(growable: false);
    return result;
  }
}

class LDConfigBuilder {
  String _mobileKey;

  String _baseUri;
  String _eventsUri;
  String _streamUri;

  int _eventsCapacity;
  int _eventsFlushIntervalMillis;
  int _connectionTimeoutMillis;
  int _pollingIntervalMillis;
  int _backgroundPollingIntervalMillis;
  int _diagnosticRecordingIntervalMillis;

  bool _stream = true;
  bool _offline = false;
  bool _disableBackgroundUpdating = true;
  bool _useReport = false;
  bool _inlineUsersInEvents = false;
  bool _evaluationReasons = false;
  bool _diagnosticOptOut = false;

  bool _allAttributesPrivate;
  Set<String> _privateAttributeNames;

  LDConfigBuilder(String mobileKey) {
    this._mobileKey = mobileKey;
  }

  LDConfigBuilder setBaseUri(String baseUri) {
    this._baseUri = baseUri;
    return this;
  }

  LDConfigBuilder setEventsUri(String eventsUri) {
    this._eventsUri = eventsUri;
    return this;
  }

  LDConfigBuilder setStreamUri(String streamUri) {
    this._streamUri = streamUri;
    return this;
  }

  LDConfig build() {
    return LDConfig._builder(this);
  }
}