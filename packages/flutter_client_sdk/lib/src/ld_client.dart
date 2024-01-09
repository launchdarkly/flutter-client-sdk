import 'package:launchdarkly_dart_client/ld_client.dart';

import 'config/defaults/flutter_default_config.dart';
import 'connection_manager.dart';
import 'flutter_state_detector.dart';
import 'persistence/shared_preferences_persistence.dart';
import 'platform_env_reporter.dart';

/// Type of function callback used by `LDClient.registerFlagsReceivedListener`.
///
/// The callback will be called with a list of flag keys for which values were received.
typedef LDFlagsReceivedCallback = void Function(List<String> changedFlagKeys);

/// Type of function callback used by `LDClient.registerFeatureFlagListener`.
///
/// The callback will be called with the flag key that triggered the listener.
typedef LDFlagUpdatedCallback = void Function(String flagKey);

/// The main interface for the LaunchDarkly Flutter SDK.
///
/// To setup the SDK before use, build an [LDConfig] with [LDConfigBuilder] and an initial [LDContext] with [LDContextBuilder].
/// These should be passed to [LDClient.start(config, context)] to initialize the SDK instance. A basic example:
/// ```
/// builder = LDContextBuilder();
/// builder.kind("user", <USER_KEY>);
/// builder.kind("company", <COMP_KEY>);
/// context = builder.build();
/// LDClient.start(config, context)
/// ```
///
/// After initialization, the SDK can evaluate feature flags from the LaunchDarkly dashboard against the current context,
/// record custom events, and provides various status configuration and monitoring utilities. See the individual class
/// and method documentation for more details.
class LDClient {
  late final LDDartClient _client;
  late final ConnectionManager _connectionManager;

  /// Stream which emits data source status changes.
  Stream<DataSourceStatus> get dataSourceStatusChanges {
    return _client.dataSourceStatusChanges;
  }

  /// Get the current data source status.
  DataSourceStatus get dataSourceStatus => _client.dataSourceStatus;

  /// Stream which emits flag changes.
  Stream<FlagsChangedEvent> get flagChanges {
    return _client.flagChanges;
  }

  /// TODO: Comments
  LDClient(LDConfig config, LDContext context) {
    final dartConfig = LDDartConfig(
        sdkCredential: config.sdkCredential,
        persistence: SharedPreferencesPersistence(),
        logger: LDLogger(level: LDLogLevel.debug),
        applicationInfo: config.applicationInfo,
        platformEnvReporter: PlatformEnvReporter(),
        autoEnvAttributes: config.autoEnvAttributes);
    _client = LDDartClient(dartConfig, context);
    _connectionManager = ConnectionManager(
        logger: _client.logger,
        // TODO: Configuration needs implemented.
        config: ConnectionManagerConfig(
            runInBackground:
                FlutterDefaultConfig.connectionManagerConfig.runInBackground),
        destination: DartClientAdapter(_client),
        detector: FlutterStateDetector());
  }

  /// Initialize the SDK.
  ///
  /// This should be called before any other SDK methods to initialize the native SDK instance. Note that the SDK
  /// requires the flutter bindings to be initialized to allow bridging communication. In order to start the SDK before
  /// `runApp` is called, you must ensure the binding is initialized with `WidgetsFlutterBinding.ensureInitialized`.
  Future<void> start() async {
    return _client.start();
  }

  /// Checks whether the SDK has completed starting.
  ///
  /// This is equivalent to checking if the `Future` returned by [LDClient.startFuture] is already completed.
  bool isInitialized() {
    return false;
  }

  /// Changes the active context.
  ///
  /// When the context is changed, the SDK will load flag values for the context from a local cache if available, while
  /// initiating a connection to retrieve the most current flag values. An event will be queued to be sent to the service
  /// containing the public [LDContext] fields for indexing on the dashboard.
  Future<void> identify(LDContext context) async {
    return _client.identify(context);
  }

  /// Track custom events associated with the current context for data export or experimentation.
  ///
  /// The [eventName] is the key associated with the event or experiment. [data] is an optional parameter for additional
  /// data to include in the event for data export. [metricValue] can be used to record numeric metric for experimentation.
  void track(String eventName, {LDValue? data, num? metricValue}) {
    _client.track(eventName, data: data, metricValue: metricValue);
  }

  /// Returns the value of flag [flagKey] for the current context as a bool.
  ///
  /// Will return the provided [defaultValue] if the flag is missing, not a bool, or if some error occurs.
  bool boolVariation(String flagKey, bool defaultValue) {
    return _client.boolVariation(flagKey, defaultValue);
  }

  /// Returns the value of flag [flagKey] for the current context as a bool, along with information about the resultant value.
  ///
  /// See [LDEvaluationDetail] for more information on the returned value. Note that [LDConfigBuilder.evaluationReasons]
  /// must have been set to `true` to request the additional evaluation information from the backend.
  LDEvaluationDetail<bool> boolVariationDetail(
      String flagKey, bool defaultValue) {
    return _client.boolVariationDetail(flagKey, defaultValue);
  }

  /// Returns the value of flag [flagKey] for the current context as an int.
  ///
  /// Will return the provided [defaultValue] if the flag is missing, not a number, or if some error occurs.
  int intVariation(String flagKey, int defaultValue) {
    return _client.intVariation(flagKey, defaultValue);
  }

  /// Returns the value of flag [flagKey] for the current context as an int, along with information about the resultant value.
  ///
  /// See [LDEvaluationDetail] for more information on the returned value. Note that [LDConfigBuilder.evaluationReasons]
  /// must have been set to `true` to request the additional evaluation information from the backend.
  LDEvaluationDetail<int> intVariationDetail(String flagKey, int defaultValue) {
    return _client.intVariationDetail(flagKey, defaultValue);
  }

  /// Returns the value of flag [flagKey] for the current context as a double.
  ///
  /// Will return the provided [defaultValue] if the flag is missing, not a number, or if some error occurs.
  double doubleVariation(String flagKey, double defaultValue) {
    return _client.doubleVariation(flagKey, defaultValue);
  }

  /// Returns the value of flag [flagKey] for the current context as a double, along with information about the resultant value.
  ///
  /// See [LDEvaluationDetail] for more information on the returned value. Note that [LDConfigBuilder.evaluationReasons]
  /// must have been set to `true` to request the additional evaluation information from the backend.
  LDEvaluationDetail<double> doubleVariationDetail(
      String flagKey, double defaultValue) {
    return _client.doubleVariationDetail(flagKey, defaultValue);
  }

  /// Returns the value of flag [flagKey] for the current context as a string.
  ///
  /// Will return the provided [defaultValue] if the flag is missing, not a string, or if some error occurs.
  String stringVariation(String flagKey, String defaultValue) {
    return _client.stringVariation(flagKey, defaultValue);
  }

  //
  /// Returns the value of flag [flagKey] for the current context as a string, along with information about the resultant value.
  ///
  /// See [LDEvaluationDetail] for more information on the returned value. Note that [LDConfigBuilder.evaluationReasons]
  /// must have been set to `true` to request the additional evaluation information from the backend.
  LDEvaluationDetail<String> stringVariationDetail(
      String flagKey, String defaultValue) {
    return _client.stringVariationDetail(flagKey, defaultValue);
  }

  /// Returns the value of flag [flagKey] for the current context as an [LDValue].
  ///
  /// Will return the provided [defaultValue] if the flag is missing, or if some error occurs.
  LDValue jsonVariation(String flagKey, LDValue defaultValue) {
    return _client.jsonVariation(flagKey, defaultValue);
  }

  /// Returns the value of flag [flagKey] for the current context as an [LDValue], along with information about the resultant value.
  ///
  /// See [LDEvaluationDetail] for more information on the returned value. Note that [LDConfigBuilder.evaluationReasons]
  /// must have been set to `true` to request the additional evaluation information from the backend.
  LDEvaluationDetail<LDValue> jsonVariationDetail(
      String flagKey, LDValue defaultValue) {
    return _client.jsonVariationDetail(flagKey, defaultValue);
  }

  /// Returns a map of all feature flags for the current context, without sending evaluation events to LaunchDarkly.
  ///
  /// The resultant map contains an entry for each known flag, the key being the flag's key and the value being its
  /// value as an [LDValue].
  Map<String, LDValue> allFlags() {
    return _client.allFlags();
  }

  /// Triggers immediate sending of pending events to LaunchDarkly.
  ///
  /// Note that the future completes after the native SDK is requested to perform a flush, not when the said flush completes.
  Future<void> flush() async {
    return _client.flush();
  }

  /// Set the connection mode the SDK should use.
  /// TODO: More comments.
  void setMode(ConnectionMode mode) {
    _client.setMode(mode);
  }

  /// Returns whether the SDK is currently configured not to make network connections.
  ///
  /// This is specifically if the client has been set offline, or has been
  /// instructed to never go online.
  ///
  /// For more detailed status information use [dataSourceStatus].
  bool get offline => _client.offline;

  /// Permanently shuts down the client.
  ///
  /// It's not normally necessary to explicitly shut down the client.
  Future<void> close() async {
    _client.close();
    _connectionManager.dispose();
  }
}
