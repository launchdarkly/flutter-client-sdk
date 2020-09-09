library launchdarkly_flutter_client_sdk;

import 'dart:async';

import 'package:flutter/services.dart';

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

  static Future<void> track(String eventName) async {
    return _channel.invokeMethod('track', {'eventName': eventName });
  }

  static Future<bool> boolVariation(String flagKey, bool fallback) async {
    return _channel.invokeMethod('boolVariation', {'flagKey': flagKey, 'fallback': fallback });
  }

  static Future<int> intVariation(String flagKey, int fallback) async {
    return _channel.invokeMethod('intVariation', {'flagKey': flagKey, 'fallback': fallback });
  }

  static Future<double> doubleVariation(String flagKey, double fallback) async {
    return _channel.invokeMethod('doubleVariation', {'flagKey': flagKey, 'fallback': fallback });
  }

  static Future<String> stringVariation(String flagKey, String fallback) async {
    return _channel.invokeMethod('stringVariation', {'flagKey': flagKey, 'fallback': fallback });
  }

  static Future<void> flush() async {
    return _channel.invokeMethod('flush');
  }

  static Future<void> setOnline(bool online) async {
    return _channel.invokeMethod('setOnline', {'online': online });
  }
}
