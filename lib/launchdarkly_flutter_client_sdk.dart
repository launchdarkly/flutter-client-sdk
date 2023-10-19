// @dart=3.1
/// [launchdarkly_flutter_client_sdk] provides a Flutter wrapper around the LaunchDarkly mobile SDKs for
/// [Android](https://github.com/launchdarkly/android-client-sdk) and [iOS](https://github.com/launchdarkly/ios-client-sdk).
///
/// A complete [reference guide](https://docs.launchdarkly.com/sdk/client-side/flutter) is available on the LaunchDarkly
/// documentation site.
library launchdarkly_flutter_client_sdk;

import 'dart:async';
import 'src/ld_config.dart';
import 'src/ld_connection_information.dart';
import 'src/ld_context.dart';
import 'src/ld_evaluation_detail.dart';
import 'src/ld_value.dart';

export 'src/ld_value.dart';

export 'src/attribute_reference.dart';

export 'src/ld_config.dart' show LDConfig, LDConfigBuilder;
export 'src/ld_context.dart'
    show LDContext, LDContextBuilder, LDAttributesBuilder, LDContextAttributes;
export 'src/ld_evaluation_detail.dart' show LDEvaluationDetail;
export 'src/ld_connection_information.dart' show LDConnectionInformation;

/// Type of function callback used by `LDClient.registerFlagsReceivedListener`.
///
/// The callback will be called with a list of flag keys for which values were received.
typedef void LDFlagsReceivedCallback(List<String> changedFlagKeys);

/// Type of function callback used by `LDClient.registerFeatureFlagListener`.
///
/// The callback will be called with the flag key that triggered the listener.
typedef void LDFlagUpdatedCallback(String flagKey);

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
  static const String _sdkVersion = "5.0.0";

  // Empty hidden constructor to hide default constructor.
  const LDClient._();

  /// Initialize the SDK with the given [LDConfig] and [LDContext].
  ///
  /// This should be called before any other SDK methods to initialize the native SDK instance. Note that the SDK
  /// requires the flutter bindings to be initialized to allow bridging communication. In order to start the SDK before
  /// `runApp` is called, you must ensure the binding is initialized with `WidgetsFlutterBinding.ensureInitialized`.
  static Future<void> start(LDConfig config, LDContext context) async {
    // TODO
  }

  /// Checks whether the SDK has completed starting.
  ///
  /// This is equivilent to checking if the `Future` returned by [LDClient.startFuture] is already completed.
  static bool isInitialized() {
    return false;
  }

  /// Changes the active context.
  ///
  /// When the context is changed, the SDK will load flag values for the context from a local cache if available, while
  /// initiating a connection to retrieve the most current flag values. An event will be queued to be sent to the service
  /// containing the public [LDContext] fields for indexing on the dashboard.
  static Future<void> identify(LDContext context) async {
    // TODO
  }

  /// Track custom events associated with the current context for data export or experimentation.
  ///
  /// The [eventName] is the key associated with the event or experiment. [data] is an optional parameter for additional
  /// data to include in the event for data export. [metricValue] can be used to record numeric metric for experimentation.
  static Future<void> track(String eventName,
      {LDValue? data, num? metricValue}) async {
    // TODO
  }

  /// Returns the value of flag [flagKey] for the current context as a bool.
  ///
  /// Will return the provided [defaultValue] if the flag is missing, not a bool, or if some error occurs.
  static Future<bool> boolVariation(String flagKey, bool defaultValue) async {
    // TODO
    return Future.value(false);
  }

  /// Returns the value of flag [flagKey] for the current context as a bool, along with information about the resultant value.
  ///
  /// See [LDEvaluationDetail] for more information on the returned value. Note that [LDConfigBuilder.evaluationReasons]
  /// must have been set to `true` to request the additional evaluation information from the backend.
  static Future<LDEvaluationDetail<bool>> boolVariationDetail(
      String flagKey, bool defaultValue) async {
    // TODO
    return LDEvaluationDetail(defaultValue, -1, LDEvaluationReason.error());
  }

  /// Returns a map of all feature flags for the current context, without sending evaluation events to LaunchDarkly.
  ///
  /// The resultant map contains an entry for each known flag, the key being the flag's key and the value being its
  /// value as an [LDValue].
  static Future<Map<String, LDValue>> allFlags() async {
    // TODO
    Map<String, LDValue> allFlagsRes = Map();
    return allFlagsRes;
  }

  /// Triggers immediate sending of pending events to LaunchDarkly.
  ///
  /// Note that the future completes after the native SDK is requested to perform a flush, not when the said flush completes.
  static Future<void> flush() async {
    // TODO:
  }

  /// Shuts down or restores network activity made by the SDK.
  ///
  /// If the SDK is set offline, `LDClient.setOnline(false)`, it will close network connections and not make any
  /// further requests until `LDClient.setOnline(true)` is called.
  static Future<void> setOnline(bool online) async {
    // TODO
  }

  /// Returns whether the SDK is currently configured not to make network connections.
  static Future<bool> isOffline() async {
    // TODO
    return Future.value(false);
  }

  /// Returns information about the current state of the SDK's connection to the LaunchDarkly.
  ///
  /// See [LDConnectionInformation] for the available information.
  static Future<LDConnectionInformation?> getConnectionInformation() async {
    // TODO
    var state = LDConnectionState.OFFLINE;
    var failure = LDFailure("womp", LDFailureType.UNKNOWN_ERROR);
    DateTime? lastSuccessful, lastFailed;
    lastSuccessful = DateTime.fromMillisecondsSinceEpoch(0, isUtc: true);
    lastFailed = DateTime.fromMillisecondsSinceEpoch(0, isUtc: true);
    return LDConnectionInformation(state, failure, lastSuccessful, lastFailed);
  }

  /// Permanently shuts down the client.
  ///
  /// It's not normally necessary to explicitly shut down the client.
  static Future<void> close() async {
    // TODO
  }

  /// Registers a callback to be notified when the value of the flag [flagKey] is updated.
  static Future<void> registerFeatureFlagListener(
      String flagKey, LDFlagUpdatedCallback flagUpdateCallback) async {
    // TODO
  }

  /// Unregisters an [LDFlagUpdatedCallback] from the [flagKey] flag.
  static Future<void> unregisterFeatureFlagListener(
      String flagKey, LDFlagUpdatedCallback flagUpdateCallback) async {
    // TODO
  }

  /// Registers a callback to be notified when flag data is received by the SDK.
  static Future<void> registerFlagsReceivedListener(
      LDFlagsReceivedCallback flagsReceivedCallback) async {
    // TODO
  }

  /// Unregisters an [LDFlagsReceivedCallback].
  static Future<void> unregisterFlagsReceivedListener(
      LDFlagsReceivedCallback flagsReceivedCallback) async {
    // TODO
  }
}
