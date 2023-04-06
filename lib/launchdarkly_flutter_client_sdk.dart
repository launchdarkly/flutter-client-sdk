// @dart=2.12
/// [launchdarkly_flutter_client_sdk] provides a Flutter wrapper around the LaunchDarkly mobile SDKs for
/// [Android](https://github.com/launchdarkly/android-client-sdk) and [iOS](https://github.com/launchdarkly/ios-client-sdk).
///
/// A complete [reference guide](https://docs.launchdarkly.com/sdk/client-side/flutter) is available on the LaunchDarkly
/// documentation site.
library launchdarkly_flutter_client_sdk;

import 'dart:async';
import 'package:flutter/services.dart';
import 'package:quiver/collection.dart';
import 'ld_value.dart';

export 'ld_value.dart';

part 'ld_config.dart';
part 'ld_user.dart';
part 'ld_evaluation_detail.dart';
part 'ld_connection_information.dart';

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
/// To setup the SDK before use, build an [LDConfig] with [LDConfigBuilder] and an initial [LDUser] with [LDUserBuilder].
/// These should be passed to [LDClient.start] to initialize the SDK instance. A basic example:
/// ```
/// LDConfig config = LDConfigBuilder('<YOUR_MOBILE_KEY>').build();
/// LDUser user = LDUserBuilder('<USER_KEY>').build();
/// await LDClient.start(config, user);
/// ```
///
/// After initialization, the SDK can evaluate feature flags from the LaunchDarkly dashboard against the current user,
/// record custom events, and provides various status configuration and monitoring utilities. See the individual class
/// and method documentation for more details.
class LDClient {
  static const String _sdkVersion = "1.3.0";
  static const MethodChannel _channel = const MethodChannel('launchdarkly_flutter_client_sdk');

  static Completer<void> _startCompleter = Completer();
  static List<LDFlagsReceivedCallback> _flagsReceivedCallbacks = [];
  static SetMultimap<String, LDFlagUpdatedCallback> _flagUpdateCallbacks = SetMultimap();

  // Empty hidden constructor to hide default constructor.
  const LDClient._();

  static Future<void> _handleCallbacks(MethodCall call) async {
    switch (call.method) {
      case 'completeStart':
        if (_startCompleter.isCompleted) return;
        _startCompleter.complete();
        break;
      case 'handleFlagsReceived':
        var changedFlags = List.castFrom<dynamic, String>(call.arguments ?? []);
        _flagsReceivedCallbacks.forEach((callback) {
          callback(changedFlags);
        });
        break;
      case 'handleFlagUpdate':
        if (call.arguments is! String) return;
        var flagKey = call.arguments as String;
        _flagUpdateCallbacks[flagKey].forEach((callback) {
          callback(flagKey);
        });
        break;
      // Hack for resetting static completion for tests
      case '_resetStartCompletion':
        _startCompleter = Completer();
        break;
    }
  }

  /// Initialize the SDK with the given [LDConfig] and [LDUser].
  ///
  /// This should be called before any other SDK methods to initialize the native SDK instance. Note that the SDK
  /// requires the flutter bindings to be initialized to allow bridging communication. In order to start the SDK before
  /// `runApp` is called, you must ensure the binding is initialized with `WidgetsFlutterBinding.ensureInitialized`.
  static Future<void> start(LDConfig config, LDUser user) async {
    _channel.setMethodCallHandler(_handleCallbacks);
    await _channel.invokeMethod('start', {'config': config._toCodecValue(_sdkVersion), 'user': user._toCodecValue()});
  }

  /// Returns a future that completes when the SDK has completed starting.
  ///
  /// While it is safe to use the SDK as soon as the completion returned by the call to [LDClient.start] completes, it
  /// does not indicate the SDK has received the most recent flag values for the configured user. The `Future` returned
  /// by this method completes when the SDK has received flag values for the initial user, or if the SDK determines that
  /// it cannot currently retrieve flag values at all (such as when the device is offline).
  ///
  /// The optional [timeLimit] parameter can be used to set a limit to the time the returned `Future` may be incomplete
  /// regardless of whether the SDK has not yet retrieved flags for the configured user.
  static Future<void> startFuture({Duration? timeLimit}) =>
    (timeLimit != null) ? _startCompleter.future.timeout(timeLimit, onTimeout: () => null) : _startCompleter.future;

  /// Checks whether the SDK has completed starting.
  ///
  /// This is equivilent to checking if the `Future` returned by [LDClient.startFuture] is already completed.
  static bool isInitialized() => _startCompleter.isCompleted;

  /// Changes the active user context.
  ///
  /// When the user context is changed, the SDK will load flag values for the user from a local cache if available, while
  /// initiating a connection to retrieve the most current flag values. An event will be queued to be sent to the service
  /// containing the public [LDUser] fields for indexing on the dashboard.
  static Future<void> identify(LDUser user) async {
    await _channel.invokeMethod('identify', {'user': user._toCodecValue()});
  }

  /// Track custom events associated with the current user for data export or experimentation.
  ///
  /// The [eventName] is the key associated with the event or experiment. [data] is an optional parameter for additional
  /// data to include in the event for data export. [metricValue] can be used to record numeric metric for experimentation.
  static Future<void> track(String eventName, {LDValue? data, num? metricValue}) async {
    var args = {'eventName': eventName, 'data': data?.codecValue(), 'metricValue': metricValue?.toDouble()};
    await _channel.invokeMethod('track', args);
  }

  /// Returns the value of flag [flagKey] for the current user as a bool.
  ///
  /// Will return the provided [defaultValue] if the flag is missing, not a bool, or if some error occurs.
  static Future<bool> boolVariation(String flagKey, bool defaultValue) async {
    bool? result = await _channel.invokeMethod('boolVariation', {'flagKey': flagKey, 'defaultValue': defaultValue });
    return result ?? defaultValue;
  }

  /// Returns the value of flag [flagKey] for the current user as a bool, along with information about the resultant value.
  ///
  /// See [LDEvaluationDetail] for more information on the returned value. Note that [LDConfigBuilder.evaluationReasons]
  /// must have been set to `true` to request the additional evaluation information from the backend.
  static Future<LDEvaluationDetail<bool>> boolVariationDetail(String flagKey, bool defaultValue) async {
    Map<String, dynamic>? result = await _channel.invokeMapMethod('boolVariationDetail', {'flagKey': flagKey, 'defaultValue': defaultValue });
    if (result == null) {
      return LDEvaluationDetail(defaultValue, -1, LDEvaluationReason.error());
    }
    bool? resultValue = result['value'];
    if (resultValue == null) {
      return LDEvaluationDetail(defaultValue, -1, LDEvaluationReason.error());
    }
    return LDEvaluationDetail(resultValue, result['variationIndex'] ?? -1, LDEvaluationReason._fromCodecValue(result['reason']));
  }

  /// Returns the value of flag [flagKey] for the current user as an int.
  ///
  /// Will return the provided [defaultValue] if the flag is missing, not a number, or if some error occurs.
  static Future<int> intVariation(String flagKey, int defaultValue) async {
    int? result = await _channel.invokeMethod('intVariation', {'flagKey': flagKey, 'defaultValue': defaultValue });
    return result ?? defaultValue;
  }

  /// Returns the value of flag [flagKey] for the current user as an int, along with information about the resultant value.
  ///
  /// See [LDEvaluationDetail] for more information on the returned value. Note that [LDConfigBuilder.evaluationReasons]
  /// must have been set to `true` to request the additional evaluation information from the backend.
  static Future<LDEvaluationDetail<int>> intVariationDetail(String flagKey, int defaultValue) async {
    Map<String, dynamic>? result = await _channel.invokeMapMethod('intVariationDetail', {'flagKey': flagKey, 'defaultValue': defaultValue });
    if (result == null) {
      return LDEvaluationDetail(defaultValue, -1, LDEvaluationReason.error());
    }
    int? resultValue = result['value'];
    if (resultValue == null) {
      return LDEvaluationDetail(defaultValue, -1, LDEvaluationReason.error());
    }
    return LDEvaluationDetail(resultValue, result['variationIndex'] ?? -1, LDEvaluationReason._fromCodecValue(result['reason']));
  }

  /// Returns the value of flag [flagKey] for the current user as a double.
  ///
  /// Will return the provided [defaultValue] if the flag is missing, not a number, or if some error occurs.
  static Future<double> doubleVariation(String flagKey, double defaultValue) async {
    double? result = await _channel.invokeMethod('doubleVariation', {'flagKey': flagKey, 'defaultValue': defaultValue });
    return result ?? defaultValue;
  }

  /// Returns the value of flag [flagKey] for the current user as a double, along with information about the resultant value.
  ///
  /// See [LDEvaluationDetail] for more information on the returned value. Note that [LDConfigBuilder.evaluationReasons]
  /// must have been set to `true` to request the additional evaluation information from the backend.
  static Future<LDEvaluationDetail<double>> doubleVariationDetail(String flagKey, double defaultValue) async {
    Map<String, dynamic>? result = await _channel.invokeMapMethod('doubleVariationDetail', {'flagKey': flagKey, 'defaultValue': defaultValue });
    if (result == null) {
      return LDEvaluationDetail(defaultValue, -1, LDEvaluationReason.error());
    }
    double? resultValue = result['value'];
    if (resultValue == null) {
      return LDEvaluationDetail(defaultValue, -1, LDEvaluationReason.error());
    }
    return LDEvaluationDetail(resultValue, result['variationIndex'] ?? -1, LDEvaluationReason._fromCodecValue(result['reason']));
  }

  /// Returns the value of flag [flagKey] for the current user as a string.
  ///
  /// Will return the provided [defaultValue] if the flag is missing, not a string, or if some error occurs.
  static Future<String> stringVariation(String flagKey, String defaultValue) async {
    String? result = await _channel.invokeMethod('stringVariation', {'flagKey': flagKey, 'defaultValue': defaultValue });
    return result ?? defaultValue;
  }

  /// Returns the value of flag [flagKey] for the current user as a string, along with information about the resultant value.
  ///
  /// See [LDEvaluationDetail] for more information on the returned value. Note that [LDConfigBuilder.evaluationReasons]
  /// must have been set to `true` to request the additional evaluation information from the backend.
  static Future<LDEvaluationDetail<String>> stringVariationDetail(String flagKey, String defaultValue) async {
    Map<String, dynamic>? result = await _channel.invokeMapMethod('stringVariationDetail', {'flagKey': flagKey, 'defaultValue': defaultValue });
    if (result == null) {
      return LDEvaluationDetail(defaultValue, -1, LDEvaluationReason.error());
    }
    String? resultValue = result['value'];
    if (resultValue == null) {
      return LDEvaluationDetail(defaultValue, -1, LDEvaluationReason.error());
    }
    return LDEvaluationDetail(resultValue, result['variationIndex'] ?? -1, LDEvaluationReason._fromCodecValue(result['reason']));
  }

  /// Returns the value of flag [flagKey] for the current user as an [LDValue].
  ///
  /// Will return the provided [defaultValue] if the flag is missing, or if some error occurs.
  static Future<LDValue> jsonVariation(String flagKey, LDValue defaultValue) async {
    dynamic result = await _channel.invokeMethod('jsonVariation', {'flagKey': flagKey, 'defaultValue': defaultValue.codecValue()});
    return LDValue.fromCodecValue(result);
  }

  /// Returns the value of flag [flagKey] for the current user as an [LDValue], along with information about the resultant value.
  ///
  /// See [LDEvaluationDetail] for more information on the returned value. Note that [LDConfigBuilder.evaluationReasons]
  /// must have been set to `true` to request the additional evaluation information from the backend.
  static Future<LDEvaluationDetail<LDValue>> jsonVariationDetail(String flagKey, LDValue defaultValue) async {
    Map<String, dynamic>? result = await _channel.invokeMapMethod('jsonVariationDetail', {'flagKey': flagKey, 'defaultValue': defaultValue.codecValue()});
    if (result == null) {
      return LDEvaluationDetail(defaultValue, -1, LDEvaluationReason.error());
    }
    return LDEvaluationDetail(LDValue.fromCodecValue(result['value']), result['variationIndex'] ?? -1, LDEvaluationReason._fromCodecValue(result['reason']));
  }

  /// Returns a map of all feature flags for the current user, without sending evaluation events to LaunchDarkly.
  ///
  /// The resultant map contains an entry for each known flag, the key being the flag's key and the value being its
  /// value as an [LDValue].
  static Future<Map<String, LDValue>> allFlags() async {
    Map<String, dynamic>? allFlagsDyn = await _channel.invokeMapMethod('allFlags');
    Map<String, LDValue> allFlagsRes = Map();
    allFlagsDyn?.forEach((key, value) {
        allFlagsRes[key] = LDValue.fromCodecValue(value);
    });
    return allFlagsRes;
  }

  /// Triggers immediate sending of pending events to LaunchDarkly.
  ///
  /// Note that the future completes after the native SDK is requested to perform a flush, not when the said flush completes.
  static Future<void> flush() async {
    await _channel.invokeMethod('flush');
  }

  /// Shuts down or restores network activity made by the SDK.
  ///
  /// If the SDK is set offline, `LDClient.setOnline(false)`, it will close network connections and not make any
  /// further requests until `LDClient.setOnline(true)` is called.
  static Future<void> setOnline(bool online) async {
    await _channel.invokeMethod('setOnline', {'online': online });
  }

  /// Returns whether the SDK is currently configured not to make network connections.
  static Future<bool> isOffline() async {
    bool? result = await _channel.invokeMethod('isOffline');
    return result ?? true;
  }

  /// Returns information about the current state of the SDK's connection to the LaunchDarkly.
  ///
  /// See [LDConnectionInformation] for the available information.
  static Future<LDConnectionInformation?> getConnectionInformation() async {
    Map<String, dynamic>? result = await _channel.invokeMapMethod('getConnectionInformation');
    return LDConnectionInformation._fromCodecValue(result);
  }

  /// Permanently shuts down the client.
  ///
  /// It's not normally necessary to explicitly shut down the client.
  static Future<void> close() async {
    await _channel.invokeMethod('close');
  }

  /// Registers a callback to be notified when the value of the flag [flagKey] is updated.
  static Future<void> registerFeatureFlagListener(String flagKey, LDFlagUpdatedCallback flagUpdateCallback) async {
    var isOnlyListenerForFlag = _flagUpdateCallbacks[flagKey].isEmpty;
    _flagUpdateCallbacks.add(flagKey, flagUpdateCallback);
    if (isOnlyListenerForFlag) {
      await _channel.invokeMethod('startFlagListening', flagKey);
    }
  }

  /// Unregisters an [LDFlagUpdatedCallback] from the [flagKey] flag.
  static Future<void> unregisterFeatureFlagListener(String flagKey, LDFlagUpdatedCallback flagUpdateCallback) async {
    _flagUpdateCallbacks.remove(flagKey, flagUpdateCallback);
    if (_flagUpdateCallbacks[flagKey].isEmpty) {
      await _channel.invokeMethod('stopFlagListening', flagKey);
    }
  }

  /// Registers a callback to be notified when flag data is received by the SDK.
  static Future<void> registerFlagsReceivedListener(LDFlagsReceivedCallback flagsReceivedCallback) async {
    _flagsReceivedCallbacks.add(flagsReceivedCallback);
  }

  /// Unregisters an [LDFlagsReceivedCallback].
  static Future<void> unregisterFlagsReceivedListener(LDFlagsReceivedCallback flagsReceivedCallback) async {
    _flagsReceivedCallbacks.remove(flagsReceivedCallback);
  }
}
