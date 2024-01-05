import "package:launchdarkly_dart_client/ld_client.dart";

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
  // TODO: Remove when used.
  // ignore: unused_field

  // TODO: figure out constructor/static start
  // Empty hidden constructor to hide default constructor.
  // const LDClient._();

  LDDartClient? _client;

  /// Initialize the SDK with the given [LDConfig] and [LDContext].
  ///
  /// This should be called before any other SDK methods to initialize the native SDK instance. Note that the SDK
  /// requires the flutter bindings to be initialized to allow bridging communication. In order to start the SDK before
  /// `runApp` is called, you must ensure the binding is initialized with `WidgetsFlutterBinding.ensureInitialized`.
  Future<void> start(LDConfig config, LDContext context) async {
    // TODO: revise start procedure

    final c = LDDartConfig(
        sdkCredential: config.mobileKey,
        logger: LDLogger(level: LDLogLevel.debug),
        applicationInfo: config.applicationInfo,
        platformEnvReporter: PlatformEnvReporter(),
        autoEnvAttributes: config.autoEnvAttributes);
    _client = LDDartClient(c, context);
    return _client?.start();
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
    // TODO
  }

  /// Track custom events associated with the current context for data export or experimentation.
  ///
  /// The [eventName] is the key associated with the event or experiment. [data] is an optional parameter for additional
  /// data to include in the event for data export. [metricValue] can be used to record numeric metric for experimentation.
  track(String eventName, {LDValue? data, num? metricValue}) async {
    // TODO
  }

  /// Returns the value of flag [flagKey] for the current context as a bool.
  ///
  /// Will return the provided [defaultValue] if the flag is missing, not a bool, or if some error occurs.
  bool boolVariation(String flagKey, bool defaultValue) {
    return _client?.boolVariation(flagKey, defaultValue) ?? defaultValue;
  }

  /// Returns the value of flag [flagKey] for the current context as a bool, along with information about the resultant value.
  ///
  /// See [LDEvaluationDetail] for more information on the returned value. Note that [LDConfigBuilder.evaluationReasons]
  /// must have been set to `true` to request the additional evaluation information from the backend.
  LDEvaluationDetail<bool> boolVariationDetail(
      String flagKey, bool defaultValue) {
    // TODO
    return LDEvaluationDetail(defaultValue, -1, LDEvaluationReason.error());
  }

  /// Returns a map of all feature flags for the current context, without sending evaluation events to LaunchDarkly.
  ///
  /// The resultant map contains an entry for each known flag, the key being the flag's key and the value being its
  /// value as an [LDValue].
  Map<String, LDValue> allFlags() {
    // TODO
    Map<String, LDValue> allFlagsRes = {};
    return allFlagsRes;
  }

  /// Triggers immediate sending of pending events to LaunchDarkly.
  ///
  /// Note that the future completes after the native SDK is requested to perform a flush, not when the said flush completes.
  Future<void> flush() async {
    // TODO:
  }

  /// Shuts down or restores network activity made by the SDK.
  ///
  /// If the SDK is set offline, `LDClient.setOnline(false)`, it will close network connections and not make any
  /// further requests until `LDClient.setOnline(true)` is called.
  void setOnline(bool online) {
    // TODO
  }

  /// Returns whether the SDK is currently configured not to make network connections.
  bool isOffline() {
    // TODO
    return false;
  }

  /// Returns information about the current state of the SDK's connection to the LaunchDarkly.
  ///
  /// See [LDConnectionInformation] for the available information.
  LDConnectionInformation? getConnectionInformation() {
    // TODO
    var state = LDConnectionState.offline;
    var failure = LDFailure("womp", LDFailureType.unknownError);
    DateTime? lastSuccessful, lastFailed;
    lastSuccessful = DateTime.fromMillisecondsSinceEpoch(0, isUtc: true);
    lastFailed = DateTime.fromMillisecondsSinceEpoch(0, isUtc: true);
    return LDConnectionInformation(state, failure, lastSuccessful, lastFailed);
  }

  /// Permanently shuts down the client.
  ///
  /// It's not normally necessary to explicitly shut down the client.
  Future<void> close() async {
    // TODO
  }

  /// Registers a callback to be notified when the value of the flag [flagKey] is updated.
  registerFeatureFlagListener(
      String flagKey, LDFlagUpdatedCallback flagUpdateCallback) {
    // TODO
  }

  /// Unregisters an [LDFlagUpdatedCallback] from the [flagKey] flag.
  unregisterFeatureFlagListener(
      String flagKey, LDFlagUpdatedCallback flagUpdateCallback) {
    // TODO
  }

  /// Registers a callback to be notified when flag data is received by the SDK.
  registerFlagsReceivedListener(LDFlagsReceivedCallback flagsReceivedCallback) {
    // TODO
  }

  /// Unregisters an [LDFlagsReceivedCallback].
  unregisterFlagsReceivedListener(
      LDFlagsReceivedCallback flagsReceivedCallback) {
    // TODO
  }
}
