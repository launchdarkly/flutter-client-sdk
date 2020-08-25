
import 'dart:async';

import 'package:flutter/services.dart';

class LaunchdarklyFlutterClientSdk {
  static const MethodChannel _channel =
      const MethodChannel('launchdarkly_flutter_client_sdk');

  static Future<String> get platformVersion async {
    final String version = await _channel.invokeMethod('getPlatformVersion');
    return version;
  }
}
