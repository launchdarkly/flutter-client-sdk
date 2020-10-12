import Flutter
import UIKit

import LaunchDarkly

public class SwiftLaunchdarklyFlutterClientSdkPlugin: NSObject, FlutterPlugin {
  public static func register(with registrar: FlutterPluginRegistrar) {
    let channel = FlutterMethodChannel(name: "launchdarkly_flutter_client_sdk", binaryMessenger: registrar.messenger())
    let instance = SwiftLaunchdarklyFlutterClientSdkPlugin()
    registrar.addMethodCallDelegate(instance, channel: channel)
  }

  func configFrom(dict: Dictionary<String, Any>) -> LDConfig {
    var config = LDConfig(mobileKey: dict["mobileKey"] as! String)
    config.baseUrl = URL(string: dict["baseUri"] as! String)!
    config.eventsUrl = URL(string: dict["eventsUri"] as! String)!
    config.streamUrl = URL(string: dict["streamUri"] as! String)!
    config.wrapperName = "FlutterClientSdk"
    // TODO wrapperVersion
    return config
  }

  func userFrom(dict: Dictionary<String, Any>) -> LDUser {
    var user = LDUser(key: dict["key"] as? String)
    if let anonymous = dict["anonymous"] as? Bool { user.isAnonymous = anonymous }
    user.secondary = dict["secondary"] as? String
    user.ipAddress = dict["ip"] as? String
    user.email = dict["email"] as? String
    user.name = dict["name"] as? String
    user.firstName = dict["firstName"] as? String
    user.lastName = dict["lastName"] as? String
    user.avatar = dict["avatar"] as? String
    user.country = dict["country"] as? String
    user.privateAttributes = dict["privateAttributeNames"] as? [String]
    return user
  }

  public func handle(_ call: FlutterMethodCall, result: @escaping FlutterResult) {
    let args = call.arguments as? Dictionary<String, Any>
    switch call.method {
    case "start":
      LDClient.start(config: configFrom(dict: args?["config"] as! Dictionary<String, Any>),
                     user: userFrom(dict: args?["user"] as! Dictionary<String, Any>)) {
        result(nil)
      }
    case "identify":
      LDClient.get()!.identify(user: userFrom(dict: args?["user"] as! Dictionary<String, Any>)) {
        result(nil)
      }
    case "track":
      try! LDClient.get()!.track(key: args?["eventName"] as! String)
    case "boolVariation":
      let evalResult: Bool? = LDClient.get()!.variation(forKey: args?["flagKey"] as! String,
                                                        defaultValue: args?["fallback"] as? Bool)
      result(evalResult)
    case "intVariation":
      let evalResult: Int? = LDClient.get()!.variation(forKey: args?["flagKey"] as! String,
                                                       defaultValue: args?["fallback"] as? Int)
      result(evalResult)
    case "doubleVariation":
      let evalResult: Double? = LDClient.get()!.variation(forKey: args?["flagKey"] as! String,
                                                          defaultValue: args?["fallback"] as? Double)
      result(evalResult)
    case "stringVariation":
      let evalResult: String? = LDClient.get()!.variation(forKey: args?["flagKey"] as! String,
                                                          defaultValue: args?["fallback"] as? String)
      result(evalResult)
    case "setOnline":
      let online: Bool? = args?["online"] as? Bool
      if let online = online {
        LDClient.get()!.setOnline(online)
      }
      result(nil)
    case "flush":
      LDClient.get()!.flush()
      result(nil)
    default: return
    }
  }
}
