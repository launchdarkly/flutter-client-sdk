import 'dart:async';

import 'package:launchdarkly_dart_common/launchdarkly_dart_common.dart';

import '../src/config/common_platform.dart';
import '../src/flag_manager/flag_updater.dart';
import 'config/data_source_config.dart';
import 'config/defaults/credential_type.dart';
import 'config/defaults/default_config.dart';
import 'connection_mode.dart';
import 'context_modifiers/anonymous_context_modifier.dart';
import 'context_modifiers/context_modifier.dart';
import 'context_modifiers/env_context_modifier.dart';
import 'data_sources/data_source_event_handler.dart';
import 'data_sources/data_source_manager.dart';
import 'data_sources/data_source_status.dart';
import 'data_sources/data_source_status_manager.dart';
import 'data_sources/null_data_source.dart';
import 'data_sources/polling_data_source.dart';
import 'data_sources/streaming_data_source.dart';
import 'flag_manager/flag_manager.dart';
import 'ld_common_config.dart';
import 'persistence/persistence.dart';
import 'persistence/validating_persistence.dart';

/// Base class used for all identify results. Using a sealed class allows for
/// exhaustive matching the the return from identify operations.
sealed class IdentifyResult {}

/// The identify has been completed. Either the identify completed with
/// cached data, or new data was fetched from LaunchDarkly.
final class IdentifyComplete implements IdentifyResult {
  IdentifyComplete();
}

/// The identify has been superseded. Multiple identify calls were outstanding
/// and this one has been cancelled.
final class IdentifySuperseded implements IdentifyResult {}

/// The identify operation encountered an error and will not complete.
final class IdentifyError implements IdentifyResult {
  /// The error which prevented the identify from completing.
  final Object error;

  IdentifyError(this.error);
}

typedef DataSourceFactoriesFn = Map<ConnectionMode, DataSourceFactory> Function(
    LDCommonConfig config, LDLogger logger, HttpProperties httpProperties);

Map<ConnectionMode, DataSourceFactory> _defaultFactories(
    LDCommonConfig config, LDLogger logger, HttpProperties httpProperties) {
  return {
    ConnectionMode.streaming: (LDContext context) {
      return StreamingDataSource(
          credential: config.sdkCredential,
          context: context,
          endpoints: config.serviceEndpoints,
          logger: logger,
          dataSourceConfig: StreamingDataSourceConfig(
              useReport: config.dataSourceConfig.useReport,
              withReasons: config.dataSourceConfig.evaluationReasons),
          httpProperties: httpProperties);
    },
    ConnectionMode.polling: (LDContext context) {
      return PollingDataSource(
          credential: config.sdkCredential,
          context: context,
          endpoints: config.serviceEndpoints,
          logger: logger,
          dataSourceConfig: PollingDataSourceConfig(
              useReport: config.dataSourceConfig.useReport,
              withReasons: config.dataSourceConfig.evaluationReasons,
              pollingInterval: config.dataSourceConfig.polling.pollingInterval),
          httpProperties: httpProperties);
    },
  };
}

typedef EventProcessorFactory = EventProcessor Function(
    {required LDLogger logger,
    required bool indexEvents,
    required int eventCapacity,
    required Duration flushInterval,
    required HttpClient client,
    required String analyticsEventsPath,
    required String diagnosticEventsPath,
    required ServiceEndpoints endpoints,
    required Duration diagnosticRecordingInterval,
    required bool allAttributesPrivate,
    required Set<AttributeReference> globalPrivateAttributes,
    DiagnosticsManager? diagnosticsManager});

EventProcessor _defaultEventProcessorFactory(
    {required LDLogger logger,
    required bool indexEvents,
    required int eventCapacity,
    required Duration flushInterval,
    required HttpClient client,
    required String analyticsEventsPath,
    required String diagnosticEventsPath,
    required ServiceEndpoints endpoints,
    required Duration diagnosticRecordingInterval,
    required bool allAttributesPrivate,
    required Set<AttributeReference> globalPrivateAttributes,
    DiagnosticsManager? diagnosticsManager}) {
  return DefaultEventProcessor(
      logger: logger,
      indexEvents: indexEvents,
      eventCapacity: eventCapacity,
      flushInterval: flushInterval,
      client: client,
      analyticsEventsPath: analyticsEventsPath,
      diagnosticEventsPath: diagnosticEventsPath,
      diagnosticsManager: diagnosticsManager,
      endpoints: endpoints,
      allAttributesPrivate: allAttributesPrivate,
      globalPrivateAttributes: globalPrivateAttributes,
      diagnosticRecordingInterval: diagnosticRecordingInterval);
}

final class LDCommonClient {
  final LDCommonConfig _config;
  final Persistence _persistence;
  final LDLogger _logger;
  final FlagManager _flagManager;
  final DataSourceStatusManager _dataSourceStatusManager;
  final LDContext _initialUndecoratedContext;
  final DiagnosticSdkData _sdkData;
  final CommonPlatform _platform;

  late final DataSourceManager _dataSourceManager;
  late final EnvironmentReport _envReport;
  late final AsyncSingleQueue<IdentifyResult> _identifyQueue =
      AsyncSingleQueue();
  late final DataSourceFactoriesFn _dataSourceFactories;

  // Modifications will happen in the order they are specified in this list.
  // If there are cross-dependent modifiers, then this must be considered.
  late final List<ContextModifier> _modifiers;

  final EventProcessorFactory _eventProcessorFactory;

  /// The event processor is not constructed during LDCommonClient construction
  /// because it requires the HTTP properties which must be determined
  /// asynchronously.
  ///
  /// We could consider changing the http client setup to a factory that
  /// can be set later. This would remove the conditional invocations
  /// required by making this optional.
  EventProcessor? _eventProcessor;

  // During startup the _context will be invalid until the identify process
  // is complete.
  LDContext _context = LDContextBuilder().build();

  bool _eventSendingEnabled = true;
  bool _networkAvailable = true;

  Completer<IdentifyResult>? _startCompleter;
  Future<IdentifyResult>? _startFuture;

  Stream<DataSourceStatus> get dataSourceStatusChanges {
    return _dataSourceStatusManager.changes;
  }

  DataSourceStatus get dataSourceStatus => _dataSourceStatusManager.status;

  Stream<FlagsChangedEvent> get flagChanges {
    return _flagManager.changes;
  }

  LDCommonClient(LDCommonConfig commonConfig, CommonPlatform platform,
      LDContext context, DiagnosticSdkData sdkData,
      {DataSourceFactoriesFn? dataSourceFactories,
      EventProcessorFactory? eventProcessorFactory})
      : _config = commonConfig,
        _platform = platform,
        _persistence = ValidatingPersistence(
            persistence: platform.persistence ?? InMemoryPersistence(),
            logger: commonConfig.logger),
        _logger = commonConfig.logger,
        _flagManager = FlagManager(
            sdkKey: commonConfig.sdkCredential,
            maxCachedContexts: commonConfig.persistence.maxCachedContexts,
            logger: commonConfig.logger,
            persistence: platform.persistence),
        _dataSourceStatusManager = DataSourceStatusManager(),
        _initialUndecoratedContext = context,
        // Data source factories is primarily a mechanism for testing.
        _dataSourceFactories = dataSourceFactories ?? _defaultFactories,
        _eventProcessorFactory =
            eventProcessorFactory ?? _defaultEventProcessorFactory,
        _sdkData = sdkData {
    final dataSourceEventHandler = DataSourceEventHandler(
        flagManager: _flagManager,
        statusManager: _dataSourceStatusManager,
        logger: _logger);

    _dataSourceManager = DataSourceManager(
        startingMode: _config.offline
            ? ConnectionMode.offline
            : _config.dataSourceConfig.initialConnectionMode,
        statusManager: _dataSourceStatusManager,
        dataSourceEventHandler: dataSourceEventHandler,
        logger: _logger);

    if (_config.offline) {
      _dataSourceStatusManager.setOffline();
    }
  }

  Future<EnvironmentReport> _makeEnvironmentReport() async {
    final reporterBuilder = PrioritizedEnvReportBuilder();
    reporterBuilder.setConfigLayer(ConcreteEnvReporter(
        applicationInfo: Future.value(_config.applicationInfo),
        osInfo: Future.value(null),
        deviceInfo: Future.value(null),
        locale: Future.value(null)));
    if (_config.autoEnvAttributes == AutoEnvAttributes.enabled) {
      reporterBuilder.setPlatformLayer(_platform.platformEnvReporter);
    }
    return await reporterBuilder.build();
  }

  Future<HttpProperties> _makeHttpProperties() async {
    final appInfo = _envReport.applicationInfo;
    final additionalHeaders = <String, String>{};

    if (appInfo != null) {
      if (appInfo.applicationId == null) {
        // indicates ID was dropped at some point
        _logger.info('A valid applicationId was not provided.');
      }
      additionalHeaders.addAll(appInfo.asHeaderMap());
    }

    final userAgentString = '${_sdkData.name}/${_sdkData.version}';

    switch (DefaultConfig.credentialConfig.credentialType) {
      case CredentialType.mobileKey:
        additionalHeaders['user-agent'] = userAgentString;
        // When using a mobile key the credential appears in the headers. For
        // a client-side ID the credential is in the URL.
        additionalHeaders['authorization'] = _config.sdkCredential;
      case CredentialType.clientSideId:
        additionalHeaders['x-launchdarkly-user-agent'] = userAgentString;
    }

    return _config.httpProperties.withHeaders(additionalHeaders);
  }

  Future<void> _setAndDecorateContext(LDContext context) async {
    _context = await _modifiers.asyncReduce(
        (reducer, accumulator) async => await reducer.decorate(accumulator),
        context);
  }

  /// This instructs the SDK to start connecting to LaunchDarkly. Ideally
  /// this is called before any other methods. Variation calls before the SDK
  /// has been started, or after starting but before initialization is complete,
  /// will return default values.
  ///
  /// If the return value is true, then the SDK has initialized, if false
  /// then the SDK has encountered an unrecoverable error.
  Future<bool> start({bool waitForNetworkResults = false}) {
    if (_startFuture != null) {
      return _startFuture!.then(_mapIdentifyStart);
    }
    _startCompleter = Completer<IdentifyResult>();
    _startFuture = _startCompleter!.future;

    // The setup of modifiers and other items must be done in the identify
    // queue to ensure that identifies cannot be done without those items
    // having been set resulting in a crash.
    _identifyQueue.execute(() async {
      await _startInternal();
      return _identifyInternal(_initialUndecoratedContext,
          waitForNetworkResults: waitForNetworkResults);
    }).then((res) {
      _startCompleter!.complete(_mapIdentifyResult(res));
    });

    return _startFuture!.then(_mapIdentifyStart);
  }

  bool _mapIdentifyStart(IdentifyResult result) {
    switch (result) {
      case IdentifyComplete():
        return true;
      case IdentifySuperseded():
        // This case does not happen because of the queue configuration. First
        // item in the queue will always be the start identify and it will
        // always be executed.
        _logger.error(
            'Identify was superseded, this represents a logic error in the SDK '
            'implementation. Please file a bug report.');
        continue error; // Simulate fallthrough.
      error:
      case IdentifyError():
        return false;
    }
  }

  Future<void> _startInternal() async {
    // TODO: Do we start the process when we create the client, and provide
    // a way to know when it completes? Or do we not even start it as we
    // are doing here.
    _envReport = await _makeEnvironmentReport();

    // set up context modifiers, adding the auto env modifier if turned on
    _modifiers = [AnonymousContextModifier(_persistence, _logger)];
    if (_config.autoEnvAttributes == AutoEnvAttributes.enabled) {
      _modifiers.add(
          AutoEnvContextModifier(_envReport, _persistence, _config.logger));
    }

    final httpProperties = await _makeHttpProperties();

    if (!_config.events.disabled && !_config.offline) {
      final osInfo = _envReport.osInfo;
      DiagnosticsManager? diagnosticsManager = _makeDiagnosticsManager(osInfo);

      _eventProcessor = _eventProcessorFactory(
          logger: _logger,
          indexEvents: false,
          eventCapacity: _config.events.eventCapacity,
          flushInterval: _config.events.flushInterval,
          client: HttpClient(httpProperties: httpProperties),
          analyticsEventsPath: DefaultConfig.eventPaths
              .getAnalyticEventsPath(_config.sdkCredential),
          diagnosticEventsPath: DefaultConfig.eventPaths
              .getDiagnosticEventsPath(_config.sdkCredential),
          diagnosticsManager: diagnosticsManager,
          endpoints: _config.serviceEndpoints,
          allAttributesPrivate: _config.allAttributesPrivate,
          globalPrivateAttributes: _config.globalPrivateAttributes
              .map((item) => AttributeReference(item))
              .where((ref) => ref.valid)
              .toSet(),
          diagnosticRecordingInterval:
              _config.events.diagnosticRecordingInterval);
    }

    _updateEventSendingState();

    if (!_config.offline) {
      _dataSourceManager
          .setFactories(_dataSourceFactories(_config, _logger, httpProperties));
    } else {
      _dataSourceManager.setFactories({
        ConnectionMode.streaming: (LDContext context) {
          return NullDataSource();
        },
        ConnectionMode.polling: (LDContext context) {
          return NullDataSource();
        },
      });
    }
  }

  DiagnosticsManager? _makeDiagnosticsManager(OsInfo? osInfo) {
    final diagnosticsManager = _config.events.diagnosticOptOut
        ? null
        : DiagnosticsManager(
            credential: _config.sdkCredential,
            sdkData: _sdkData,
            platformData: DiagnosticPlatformData(
              name: 'Dart',
              osName: osInfo?.name,
              osVersion: osInfo?.version,
            ),
            configData: DiagnosticConfigData(
                customBaseUri: _config.serviceEndpoints.polling !=
                    _config.serviceEndpoints.defaultPolling,
                customStreamUri: _config.serviceEndpoints.streaming !=
                    _config.serviceEndpoints.streaming,
                eventsCapacity: _config.events.eventCapacity,
                connectTimeoutMillis:
                    _config.httpProperties.connectTimeout.inMilliseconds,
                eventsFlushIntervalMillis:
                    _config.events.flushInterval.inMilliseconds,
                pollingIntervalMillis: _config
                    .dataSourceConfig.polling.pollingInterval.inMilliseconds,
                // TODO: If made dynamic, then needs implemented.
                reconnectTimeoutMillis: 1000,
                // For now disabled means polling is enabled. When dynamic
                // switching is added, then this can potentially just return
                // `false`.
                streamingDisabled:
                    _config.dataSourceConfig.initialConnectionMode ==
                        ConnectionMode.polling,
                offline: _config.offline,
                allAttributesPrivate: _config.allAttributesPrivate,
                diagnosticRecordingIntervalMillis:
                    _config.events.diagnosticRecordingInterval.inMilliseconds,
                useReport: _config.dataSourceConfig.useReport,
                evaluationReasonsRequested:
                    _config.dataSourceConfig.evaluationReasons));
    return diagnosticsManager;
  }

  /// Triggers immediate sending of pending events to LaunchDarkly.
  ///
  /// Note that the future completes after the native SDK is requested to perform a flush, not when the said flush completes.
  Future<void> flush() async {
    await _eventProcessor?.flush();
  }

  /// Changes the active context.
  ///
  /// When the context is changed, the SDK will load flag values for the context from a local cache if available, while
  /// initiating a connection to retrieve the most current flag values. An event will be queued to be sent to the service
  /// containing the public [LDContext] fields for indexing on the dashboard.
  Future<IdentifyResult> identify(LDContext context,
      {bool waitForNetworkResults = false}) async {
    if (_startFuture == null) {
      const message =
          'Identify called before SDK has been started. Start the SDK before '
          'attempting to identify additional contexts.';
      _logger.warn(message);
      return IdentifyError(Exception(message));
    }
    final res = await _identifyQueue.execute(() async {
      return _identifyInternal(context,
          waitForNetworkResults: waitForNetworkResults);
    });
    return _mapIdentifyResult(res);
  }

  Future<IdentifyResult> _mapIdentifyResult(
      TaskResult<IdentifyResult> res) async {
    switch (res) {
      case TaskComplete<IdentifyResult>(result: var result):
        return result ?? IdentifyComplete();
      case TaskShed<IdentifyResult>():
        return IdentifySuperseded();
      case TaskError<IdentifyResult>(error: var error):
        return IdentifyError(error);
    }
  }

  Future<IdentifyResult> _identifyInternal(LDContext context,
      {bool waitForNetworkResults = false}) async {
    if (!context.valid) {
      const message =
          'LDClient was provided an invalid context. The context will be ignored. Existing flags will be used for evaluations until identify is called with a valid context.';
      _logger.warn(message);
      return IdentifyError(Exception(message));
    }

    try {
      await _setAndDecorateContext(context);
      final completer = Completer<void>();
      _eventProcessor?.processIdentifyEvent(IdentifyEvent(context: _context));
      final loadedFromCache = await _flagManager.loadCached(_context);

      if (_config.offline) {
        return IdentifyComplete();
      }
      _dataSourceManager.identify(_context, completer);

      if (loadedFromCache && !waitForNetworkResults) {
        return IdentifyComplete();
      }
      await completer.future;
      return IdentifyComplete();
    } catch (error) {
      return IdentifyError(error);
    }
  }

  /// Returns the value of flag [flagKey] for the current context as a bool.
  ///
  /// Will return the provided [defaultValue] if the flag is missing, not a bool, or if some error occurs.
  bool boolVariation(String flagKey, bool defaultValue) {
    return _variationInternal(flagKey, LDValue.ofBool(defaultValue),
            isDetailed: false, type: LDValueType.boolean)
        .value
        .booleanValue();
  }

  /// Returns the value of flag [flagKey] for the current context as a bool, along with information about the resultant value.
  ///
  /// See [LDEvaluationDetail] for more information on the returned value. Note that [DataSourceConfig.evaluationReasons]
  /// must have been set to `true` to request the additional evaluation information from the backend.
  LDEvaluationDetail<bool> boolVariationDetail(
      String flagKey, bool defaultValue) {
    final ldValueVariation = _variationInternal(
        flagKey, LDValue.ofBool(defaultValue),
        isDetailed: true, type: LDValueType.boolean);

    return LDEvaluationDetail(ldValueVariation.value.booleanValue(),
        ldValueVariation.variationIndex, ldValueVariation.reason);
  }

  /// Returns the value of flag [flagKey] for the current context as an int.
  ///
  /// Will return the provided [defaultValue] if the flag is missing, not a number, or if some error occurs.
  int intVariation(String flagKey, int defaultValue) {
    return _variationInternal(flagKey, LDValue.ofNum(defaultValue),
            isDetailed: false, type: LDValueType.number)
        .value
        .intValue();
  }

  /// Returns the value of flag [flagKey] for the current context as an int, along with information about the resultant value.
  ///
  /// See [LDEvaluationDetail] for more information on the returned value. Note that [DataSourceConfig.evaluationReasons]
  /// must have been set to `true` to request the additional evaluation information from the backend.
  LDEvaluationDetail<int> intVariationDetail(String flagKey, int defaultValue) {
    final ldValueVariation = _variationInternal(
        flagKey, LDValue.ofNum(defaultValue),
        isDetailed: true, type: LDValueType.number);

    return LDEvaluationDetail(ldValueVariation.value.intValue(),
        ldValueVariation.variationIndex, ldValueVariation.reason);
  }

  /// Returns the value of flag [flagKey] for the current context as a double.
  ///
  /// Will return the provided [defaultValue] if the flag is missing, not a number, or if some error occurs.
  double doubleVariation(String flagKey, double defaultValue) {
    return _variationInternal(flagKey, LDValue.ofNum(defaultValue),
            isDetailed: false, type: LDValueType.number)
        .value
        .doubleValue();
  }

  /// Returns the value of flag [flagKey] for the current context as a double, along with information about the resultant value.
  ///
  /// See [LDEvaluationDetail] for more information on the returned value. Note that [DataSourceConfig.evaluationReasons]
  /// must have been set to `true` to request the additional evaluation information from the backend.
  LDEvaluationDetail<double> doubleVariationDetail(
      String flagKey, double defaultValue) {
    final ldValueVariation = _variationInternal(
        flagKey, LDValue.ofNum(defaultValue),
        isDetailed: true, type: LDValueType.number);

    return LDEvaluationDetail(ldValueVariation.value.doubleValue(),
        ldValueVariation.variationIndex, ldValueVariation.reason);
  }

  /// Returns the value of flag [flagKey] for the current context as a string.
  ///
  /// Will return the provided [defaultValue] if the flag is missing, not a string, or if some error occurs.
  String stringVariation(String flagKey, String defaultValue) {
    return _variationInternal(flagKey, LDValue.ofString(defaultValue),
            isDetailed: false, type: LDValueType.string)
        .value
        .stringValue();
  }

  //
  /// Returns the value of flag [flagKey] for the current context as a string, along with information about the resultant value.
  ///
  /// See [LDEvaluationDetail] for more information on the returned value. Note that [DataSourceConfig.evaluationReasons]
  /// must have been set to `true` to request the additional evaluation information from the backend.
  LDEvaluationDetail<String> stringVariationDetail(
      String flagKey, String defaultValue) {
    final ldValueVariation = _variationInternal(
        flagKey, LDValue.ofString(defaultValue),
        isDetailed: true, type: LDValueType.string);

    return LDEvaluationDetail(ldValueVariation.value.stringValue(),
        ldValueVariation.variationIndex, ldValueVariation.reason);
  }

  /// Returns the value of flag [flagKey] for the current context as an [LDValue].
  ///
  /// Will return the provided [defaultValue] if the flag is missing, or if some error occurs.
  LDValue jsonVariation(String flagKey, LDValue defaultValue) {
    return _variationInternal(flagKey, defaultValue, isDetailed: false).value;
  }

  /// Returns the value of flag [flagKey] for the current context as an [LDValue], along with information about the resultant value.
  ///
  /// See [LDEvaluationDetail] for more information on the returned value. Note that [DataSourceConfig.evaluationReasons]
  /// must have been set to `true` to request the additional evaluation information from the backend.
  LDEvaluationDetail<LDValue> jsonVariationDetail(
      String flagKey, LDValue defaultValue) {
    return _variationInternal(flagKey, defaultValue, isDetailed: true);
  }

  LDEvaluationDetail<LDValue> _variationInternal(
      String flagKey, LDValue defaultValue,
      {required bool isDetailed, LDValueType? type}) {
    final evalResult = _flagManager.get(flagKey);

    LDEvaluationDetail<LDValue> detail;

    if (evalResult != null && evalResult.flag != null) {
      evalResult.flag?.prerequisites?.forEach((prereq) {
        _variationInternal(prereq, LDValue.ofNull(), isDetailed: isDetailed);
      });

      if (type == null || type == evalResult.flag!.detail.value.type) {
        detail = evalResult.flag!.detail;
      } else {
        detail = LDEvaluationDetail(defaultValue, null,
            LDEvaluationReason.error(errorKind: LDErrorKind.wrongType));
      }
    } else {
      detail = LDEvaluationDetail(
          defaultValue, null, LDEvaluationReason.flagNotFound());
    }

    _eventProcessor?.processEvalEvent(EvalEvent(
        flagKey: flagKey,
        defaultValue: defaultValue,
        evaluationDetail: detail,
        context: _context,
        // Include the reason when available if this is a detailed evaluation.
        withReason: isDetailed || (evalResult?.flag?.trackReason ?? false),
        trackEvent: evalResult?.flag?.trackEvents ?? false,
        debugEventsUntilDate: evalResult?.flag?.debugEventsUntilDate != null
            ? DateTime.fromMillisecondsSinceEpoch(
                evalResult!.flag!.debugEventsUntilDate!)
            : null,
        version: evalResult?.flag?.flagVersion ?? evalResult?.version));

    return detail;
  }

  /// Returns a map of all feature flags for the current context, without sending evaluation events to LaunchDarkly.
  ///
  /// The resultant map contains an entry for each known flag, the key being the flag's key and the value being its
  /// value as an [LDValue].
  Map<String, LDValue> allFlags() {
    final res = <String, LDValue>{};

    final allEvalResults = _flagManager.getAll();

    for (var MapEntry(key: flagKey, value: evalResult)
        in allEvalResults.entries) {
      if (evalResult.flag != null) {
        res[flagKey] = evalResult.flag!.detail.value;
      }
    }

    return res;
  }

  /// Set the connection mode the SDK should use.
  void setMode(ConnectionMode mode) {
    _dataSourceManager.setMode(mode);
  }

  void setNetworkAvailability(bool available) {
    if (_networkAvailable == available) {
      _logger.debug(
          'Network availability already in desired state. No changes made.');
      return;
    }
    _networkAvailable = available;
    _dataSourceManager.setNetworkAvailable(available);
    _updateEventSendingState();
  }

  /// Enable or disable event sending. When disabling event sending it may
  /// be desirable to flush pending events. For instance in a mobile app
  /// on transition to the background. This flush attempt will only be made
  /// if the network is available.
  void setEventSendingEnabled(bool enabled, {bool flush = true}) {
    // The mode is not changing, so no action is required.
    if (_eventSendingEnabled == enabled) {
      _logger.debug('Event sending already in desired state. No changes made.');
      return;
    }

    if (!enabled && flush && _networkAvailable) {
      // The event processor will asynchronously start this and it will
      // not be interrupted by stopping the processor. Stopping it will just
      // stop all the timers, not any outstanding requests.
      _logger.debug('Flushing events on event disable transition.');
      _eventProcessor?.flush();
    }
    _eventSendingEnabled = enabled;
    _updateEventSendingState();
  }

  void _updateEventSendingState() {
    if (_eventProcessor == null) {
      // The event processor has not been created for the state to be set.
      return;
    }
    if (_eventSendingEnabled && _networkAvailable) {
      _logger.debug('Enabling event sending.');
      _eventProcessor?.start();
    } else {
      _logger.debug('Disabling event sending.');
      _eventProcessor?.stop();
    }
  }

  bool get offline =>
      _dataSourceStatusManager.status.state == DataSourceState.setOffline;

  /// Get the logger for the client. This is primarily intended for SDK wrappers
  /// and LaunchDarkly provided modules. It is not recommended that this
  /// instance is used for general purpose logging.
  LDLogger get logger => _logger;

  /// Track custom events associated with the current context for data export or experimentation.
  ///
  /// The [eventName] is the key associated with the event or experiment. [data] is an optional parameter for additional
  /// data to include in the event for data export. [metricValue] can be used to record numeric metric for experimentation.
  void track(String eventName, {LDValue? data, num? metricValue}) async {
    _eventProcessor?.processCustomEvent(CustomEvent(
        key: eventName,
        context: _context,
        metricValue: metricValue,
        data: data));
  }

  /// Permanently shuts down the client.
  ///
  /// It's not normally necessary to explicitly shut down the client.
  Future<void> close() async {
    await _eventProcessor?.flush();
    _eventProcessor?.stop();
    _dataSourceManager.stop();
    _dataSourceStatusManager.stop();
  }

  /// Check if the initialization process is complete.
  bool get initialized => _startCompleter?.isCompleted ?? false;
}
