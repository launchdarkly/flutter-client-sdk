library launchdarkly_flutter_client_sdk;

import 'dart:async';
import 'package:flutter/services.dart';
import 'ld_value.dart';

export 'ld_value.dart';

part 'ld_config.dart';
part 'ld_user.dart';

class LaunchdarklyFlutterClientSdk {
  static const MethodChannel _channel = const MethodChannel('launchdarkly_flutter_client_sdk');

  static Future<void> start(LDConfig config, LDUser user) async {
    return _channel.invokeMethod('start', {'config': config._toMap(), 'user': user._toMap()});
  }

  static Future<void> identify(LDUser user) async {
    return _channel.invokeMethod('identify', {'user': user._toMap()});
  }

  static Future<void> track(String eventName, {LDValue data, num metricValue}) async {
    var args = {'eventName': eventName, 'data': LDValue.normalize(data).codecValue(), 'metricValue': metricValue?.toDouble()};
    return _channel.invokeMethod('track', args);
  }

  static Future<bool> boolVariation(String flagKey, bool defaultValue) async {
    return _channel.invokeMethod('boolVariation', {'flagKey': flagKey, 'defaultValue': defaultValue });
  }

  static Future<int> intVariation(String flagKey, int defaultValue) async {
    return _channel.invokeMethod('intVariation', {'flagKey': flagKey, 'defaultValue': defaultValue });
  }

  static Future<double> doubleVariation(String flagKey, double defaultValue) async {
    return _channel.invokeMethod('doubleVariation', {'flagKey': flagKey, 'defaultValue': defaultValue });
  }

  static Future<String> stringVariation(String flagKey, String defaultValue) async {
    return _channel.invokeMethod('stringVariation', {'flagKey': flagKey, 'defaultValue': defaultValue });
  }

  static Future<LDValue> jsonVariation(String flagKey, LDValue defaultValue) async {
    dynamic result = await _channel.invokeMethod('jsonVariation', {'flagKey': flagKey, 'defaultValue': defaultValue.codecValue()});
    return LDValue.fromCodecValue(result);
  }

  static Future<Map<String, LDValue>> allFlags() async {
    Map<dynamic, dynamic> allFlagsDyn = await _channel.invokeMethod('allFlags');
    Map<String, LDValue> allFlagsRes = Map();
    allFlagsDyn.forEach((key, value) {
        allFlagsRes[key] = LDValue.fromCodecValue(value);
    });
    return allFlagsRes;
  }

  static Future<void> flush() async {
    return _channel.invokeMethod('flush');
  }

  static Future<void> setOnline(bool online) async {
    return _channel.invokeMethod('setOnline', {'online': online });
  }
}
