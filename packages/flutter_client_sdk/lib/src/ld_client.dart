import 'package:launchdarkly_common_client/launchdarkly_common_client.dart';

import 'config/defaults/flutter_default_config.dart';
import 'config/ld_config.dart';
import 'connection_manager.dart';
import 'flutter_state_detector.dart';
import 'persistence/shared_preferences_persistence.dart';
import 'platform_env_reporter.dart';

/// The main interface for the LaunchDarkly Flutter SDK.
///
/// To setup the SDK before use, construct an [LDConfig] and
/// an initial [LDContext] with [LDContextBuilder].
/// These should be passed to [LDClient(config, context)] and then [start]
/// should be called. A basic example:
/// ```dart
/// final config = LDConfig(CredentialSource.fromEnvironment(),
///   AutoEnvAttributes.enabled);
/// final context = LDContextBuilder()
///   .kind("user", <USER_KEY>)
///   .kind("company", <COMP_KEY>)
///   .build();
/// final client = LDClient(config, context);
/// await client.start().timeout(const Duration(seconds: 5), onTimeout: () => false);
/// ```
///
/// After initialization, the SDK can evaluate feature flags from the
/// LaunchDarkly dashboard against the current context, record custom events,
/// and provides various status configuration and monitoring utilities.
///
/// See the individual class and method documentation for more details.
///
/// This is an interface class so that it can be mocked for testing, but it
/// cannot be extended.
interface class LDClient {
  late final LDCommonClient _client;
  late final ConnectionManager _connectionManager;

  /// Stream which emits data source status changes.
  ///
  /// You can start listening to data source changes before calling the
  /// [start] method. Events will be emitted for states beyond the default
  /// initializing state.
  Stream<DataSourceStatus> get dataSourceStatusChanges {
    return _client.dataSourceStatusChanges;
  }

  /// Get the current data source status.
  DataSourceStatus get dataSourceStatus => _client.dataSourceStatus;

  /// Stream which emits flag changes.
  ///
  /// You can start listening for flag changes before calling [start]. If you
  /// do, then you will get change notifications for all flags, including
  /// those that are loaded from cache.
  Stream<FlagsChangedEvent> get flagChanges {
    return _client.flagChanges;
  }

  /// Construct the client instance.
  ///
  /// For detailed instructions please refer to the class [LDClient] documentation.
  LDClient(LDConfig config, LDContext context) {
    final platformImplementation = CommonPlatform(
        persistence: SharedPreferencesPersistence(),
        platformEnvReporter: PlatformEnvReporter(),
        autoEnvAttributes:
            config.autoEnvAttributes == AutoEnvAttributes.enabled);
    _client = LDCommonClient(
        config,
        platformImplementation,
        context,
        DiagnosticSdkData(
            name: 'FlutterClientSdk',
            version: '4.8.0')); // x-release-please-version
    _connectionManager = ConnectionManager(
        logger: _client.logger,
        config: ConnectionManagerConfig(
            initialConnectionMode: config.offline
                ? ConnectionMode.offline
                : config.dataSourceConfig.initialConnectionMode,
            disableAutomaticBackgroundHandling:
                config.offline || !config.applicationEvents.backgrounding,
            disableAutomaticNetworkHandling:
                config.offline || !config.applicationEvents.networkAvailability,
            runInBackground:
                FlutterDefaultConfig.connectionManagerConfig.runInBackground),
        destination: DartClientAdapter(_client),
        detector: FlutterStateDetector());
  }

  /// Initialize the SDK.
  ///
  /// This should be called before using the SDK to evaluate flags. Note that
  /// the SDK requires the flutter bindings to allow use of native plugins for
  /// handling device state and storage. In order to start the SDK before
  /// `runApp` is called, you must ensure the binding is initialized with
  /// `WidgetsFlutterBinding.ensureInitialized`.
  ///
  /// The [start] function can take an indeterminate amount of time to
  /// complete. For instance if the SDK is started while a device is in airplane
  /// mode, then it may not complete until some time in the future when the
  /// device leaves airplane mode. For this reason it is recommended to use
  /// a timeout when waiting for SDK initialization.
  ///
  /// For example:
  /// ```dart
  /// await client.start().timeout(const Duration(seconds: 30));
  /// ```
  /// The [waitForNetworkResults] parameters, when true, indicates that the SDK
  /// will attempt to wait for values from LaunchDarkly instead of depending
  /// on cached values. The cached values will still be loaded, but the future
  /// returned by this function will not resolve as a result of those cached
  /// values being loaded. Generally this option should NOT be used and instead
  /// flag changes should be listened to. It the client is set to offline mode,
  /// then this option is ignored.
  ///
  /// If [waitForNetworkResults] is true, and an error is encountered, then
  /// false may be returned even if cached values were loaded.
  Future<bool> start({bool waitForNetworkResults = false}) async {
    return _client.start(waitForNetworkResults: waitForNetworkResults);
  }

  /// Changes the active context.
  ///
  /// When the context is changed, the SDK will load flag values for the context
  /// from a local cache if available, while initiating a connection to retrieve
  /// the most current flag values. An event will be queued to be sent to the
  /// service containing the public [LDContext] fields for indexing on the
  /// dashboard.
  ///
  /// A context with the same kinds and same keys will use the same cached
  /// context.
  ///
  /// This returned future can be awaited to wait for the identify process to
  /// be complete. As with [start] this can take an extended period if there
  /// is not network availability, so a timeout is recommended.
  ///
  /// The [waitForNetworkResults] parameters, when true, indicates that the SDK
  /// will attempt to wait for values from LaunchDarkly instead of depending
  /// on cached values. The cached values will still be loaded, but the future
  /// returned by this function will not resolve as a result of those cached
  /// values being loaded. Generally this option should NOT be used and instead
  /// flag changes should be listened to. It the client is set to offline mode,
  /// then this option is ignored.
  ///
  /// If [waitForNetworkResults] is true, and an error is encountered, then
  /// [IdentifyError] may be returned even if cached values were loaded.
  ///
  /// The identify will complete with 1 of three possible values:
  /// [IdentifyComplete], [IdentifySuperseded], or [IdentifyError].
  ///
  /// [IdentifyComplete] means that the SDK has managed to identify the user
  /// and either is using cached values or has received new values from
  /// LaunchDarkly.
  ///
  /// [IdentifySuperseded] means that additional [identify] calls have been made
  /// and this specific call has been cancelled. If identify multiple contexts
  /// without waiting for the previous identify to complete, then you may get
  /// this result. For instance if you called identify 10 times rapidly, then
  /// it is likely that 2 total identifies would complete, the first one and the
  /// last one. The intermediates would be cancelled for performance.
  ///
  /// [IdentifyError] this means that the identify has permanently failed. For
  /// instance the SDK key is no longer valid.
  Future<IdentifyResult> identify(LDContext context,
      {bool waitForNetworkResults = false}) async {
    return _client.identify(context,
        waitForNetworkResults: waitForNetworkResults);
  }

  /// Track custom events associated with the current context for data export or
  /// experimentation.
  ///
  /// The [eventName] is the key associated with the event or experiment.
  /// [data] is an optional parameter for additional data to include in the
  /// event for data export. [metricValue] can be used to record numeric metric
  /// for experimentation.
  void track(String eventName, {LDValue? data, num? metricValue}) {
    _client.track(eventName, data: data, metricValue: metricValue);
  }

  /// Returns the value of flag [flagKey] for the current context as a bool.
  ///
  /// Will return the provided [defaultValue] if the flag is missing, not a
  /// bool, or if some error occurs.
  bool boolVariation(String flagKey, bool defaultValue) {
    return _client.boolVariation(flagKey, defaultValue);
  }

  /// Returns the value of flag [flagKey] for the current context as a bool,
  /// along with information about the resultant value.
  ///
  /// See [LDEvaluationDetail] for more information on the returned value.
  /// Note that [DataSourceConfig.evaluationReasons] must have been set to `true`
  /// to request the additional evaluation information from the backend.
  LDEvaluationDetail<bool> boolVariationDetail(
      String flagKey, bool defaultValue) {
    return _client.boolVariationDetail(flagKey, defaultValue);
  }

  /// Returns the value of flag [flagKey] for the current context as an int.
  ///
  /// Will return the provided [defaultValue] if the flag is missing, not a
  /// number, or if some error occurs.
  int intVariation(String flagKey, int defaultValue) {
    return _client.intVariation(flagKey, defaultValue);
  }

  /// Returns the value of flag [flagKey] for the current context as an int,
  /// along with information about the resultant value.
  ///
  /// See [LDEvaluationDetail] for more information on the returned value.
  /// Note that [DataSourceConfig.evaluationReasons] must have been set to `true`
  /// to request the additional evaluation information from the backend.
  LDEvaluationDetail<int> intVariationDetail(String flagKey, int defaultValue) {
    return _client.intVariationDetail(flagKey, defaultValue);
  }

  /// Returns the value of flag [flagKey] for the current context as a double.
  ///
  /// Will return the provided [defaultValue] if the flag is missing, not a
  /// number, or if some error occurs.
  double doubleVariation(String flagKey, double defaultValue) {
    return _client.doubleVariation(flagKey, defaultValue);
  }

  /// Returns the value of flag [flagKey] for the current context as a double,
  /// along with information about the resultant value.
  ///
  /// See [LDEvaluationDetail] for more information on the returned value. Note
  /// that [DataSourceConfig.evaluationReasons] must have been set to `true` to
  /// request the additional evaluation information from the backend.
  LDEvaluationDetail<double> doubleVariationDetail(
      String flagKey, double defaultValue) {
    return _client.doubleVariationDetail(flagKey, defaultValue);
  }

  /// Returns the value of flag [flagKey] for the current context as a string.
  ///
  /// Will return the provided [defaultValue] if the flag is missing, not a
  /// string, or if some error occurs.
  String stringVariation(String flagKey, String defaultValue) {
    return _client.stringVariation(flagKey, defaultValue);
  }

  /// Returns the value of flag [flagKey] for the current context as a string,
  /// along with information about the resultant value.
  ///
  /// See [LDEvaluationDetail] for more information on the returned value. Note
  /// that [DataSourceConfig.evaluationReasons] must have been set to `true` to
  /// request the additional evaluation information from the backend.
  LDEvaluationDetail<String> stringVariationDetail(
      String flagKey, String defaultValue) {
    return _client.stringVariationDetail(flagKey, defaultValue);
  }

  /// Returns the value of flag [flagKey] for the current context as an [LDValue].
  ///
  /// Will return the provided [defaultValue] if the flag is missing, or if some
  /// error occurs.
  LDValue jsonVariation(String flagKey, LDValue defaultValue) {
    return _client.jsonVariation(flagKey, defaultValue);
  }

  /// Returns the value of flag [flagKey] for the current context as an
  /// [LDValue], along with information about the resultant value.
  ///
  /// See [LDEvaluationDetail] for more information on the returned value.
  /// Note that [DataSourceConfig.evaluationReasons] must have been set to `true`
  /// to request the additional evaluation information from the backend.
  LDEvaluationDetail<LDValue> jsonVariationDetail(
      String flagKey, LDValue defaultValue) {
    return _client.jsonVariationDetail(flagKey, defaultValue);
  }

  /// Returns a map of all feature flags for the current context, without
  /// sending evaluation events to LaunchDarkly.
  ///
  /// The resultant map contains an entry for each known flag, the key being
  /// the flag's key and the value being its
  /// value as an [LDValue].
  Map<String, LDValue> allFlags() {
    return _client.allFlags();
  }

  /// Triggers immediate sending of pending events to LaunchDarkly.
  ///
  /// Note that the future completes after the native SDK is requested to
  /// perform a flush, not when the said flush completes.
  Future<void> flush() async {
    return _client.flush();
  }

  /// Returns whether the SDK is currently configured not to make network
  /// connections.
  ///
  /// This is specifically if the client has been set offline, or has been
  /// instructed to never go online.
  ///
  /// For more detailed status information use [dataSourceStatus].
  bool get offline => _client.offline;

  /// Set the SDK to be offline/offline. When the SDK is set offline it will
  /// stop receiving updates and sending analytic and diagnostic events.
  set offline(bool offline) {
    _connectionManager.offline = offline;
  }

  /// Check if the SDK has finished initialization.
  ///
  /// This does not indicate that initialization was successful, but that it is
  /// finished. It has either completed successfully, or encountered an
  /// unrecoverable error.
  ///
  /// Generally the future returned from [start] should be used instead or this
  /// property.
  bool get initialized => _client.initialized;

  /// Permanently shuts down the client.
  ///
  /// It's not normally necessary to explicitly shut down the client.
  Future<void> close() async {
    await _client.close();
    _connectionManager.dispose();
  }
}
