import Flutter
import UIKit

import LaunchDarkly

public class SwiftLaunchdarklyFlutterClientSdkPlugin: NSObject, FlutterPlugin {
  public static func register(with registrar: FlutterPluginRegistrar) {
    let channel = FlutterMethodChannel(name: "launchdarkly_flutter_client_sdk", binaryMessenger: registrar.messenger())
    let instance = SwiftLaunchdarklyFlutterClientSdkPlugin()
    registrar.addMethodCallDelegate(instance, channel: channel)
  }

  func configFrom(dict: Dictionary<String, Any?>) -> LDConfig {
    var config = LDConfig(mobileKey: dict["mobileKey"] as! String)
    if let baseUrl = dict["baseUri"] as? String {
        config.baseUrl = URL(string: baseUrl)!
    }
    if let eventsUrl = dict["eventsUri"] as? String {
        config.eventsUrl = URL(string: eventsUrl)!
    }
    if let streamUrl = dict["streamUri"] as? String {
        config.streamUrl = URL(string: streamUrl)!
    }
    if let eventsCapacity = dict["eventsCapacity"] as? Int {
        config.eventCapacity = eventsCapacity
    }
    if let eventsFlushIntervalMillis = dict["eventsFlushIntervalMillis"] as? Int {
        config.eventFlushInterval = Double(eventsFlushIntervalMillis) / 1000.0
    }
    if let connectionTimeoutMillis = dict["connectionTimeoutMillis"] as? Int {
        config.connectionTimeout = Double(connectionTimeoutMillis) / 1000.0
    }
    if let pollingIntervalMillis = dict["pollingIntervalMillis"] as? Int {
        config.flagPollingInterval = Double(pollingIntervalMillis) / 1000.0
    }
    if let backgroundPollingIntervalMillis = dict["backgroundPollingIntervalMillis"] as? Int {
        config.backgroundFlagPollingInterval = Double(backgroundPollingIntervalMillis) / 1000.0
    }
    if let diagnosticRecordingIntervalMillis = dict["diagnosticRecordingIntervalMillis"] as? Int {
        config.diagnosticRecordingInterval = Double(diagnosticRecordingIntervalMillis) / 1000.0
    }
    if let stream = dict["stream"] as? Bool {
        config.streamingMode = stream ? LDStreamingMode.streaming : LDStreamingMode.polling
    }
    if let offline = dict["offline"] as? Bool {
        config.startOnline = !offline
    }
    if let disableBackgroundUpdating = dict["disableBackgroundUpdating"] as? Bool {
        config.enableBackgroundUpdates = !disableBackgroundUpdating
    }
    if let useReport = dict["useReport"] as? Bool {
        config.useReport = useReport
    }
    if let inlineUsersInEvents = dict["inlineUsersInEvents"] as? Bool {
        config.inlineUserInEvents = inlineUsersInEvents
    }
    if let evaluationReasons = dict["evaluationReasons"] as? Bool {
        config.evaluationReasons = evaluationReasons
    }
    if let diagnosticOptOut = dict["diagnosticOptOut"] as? Bool {
        config.diagnosticOptOut = diagnosticOptOut
    }
    if let allAttributesPrivate = dict["allAttributesPrivate"] as? Bool {
        config.allUserAttributesPrivate = allAttributesPrivate
    }
    if let privateAttributeNames = dict["privateAttributeNames"] as? [Any] {
        config.privateUserAttributes = privateAttributeNames.compactMap { $0 as? String }
    }
    config.wrapperName = "FlutterClientSdk"
    // TODO wrapperVersion
    return config
  }

  func userFrom(dict: Dictionary<String, Any?>) -> LDUser {
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
      result(LDClient.get()!.variation(forKey: args?["flagKey"] as! String, defaultValue: args?["defaultValue"] as? Bool))
    case "intVariation":
      result(LDClient.get()!.variation(forKey: args?["flagKey"] as! String, defaultValue: args?["defaultValue"] as? Int))
    case "doubleVariation":
      result(LDClient.get()!.variation(forKey: args?["flagKey"] as! String, defaultValue: args?["defaultValue"] as? Double))
    case "stringVariation":
      result(LDClient.get()!.variation(forKey: args?["flagKey"] as! String, defaultValue: args?["defaultValue"] as? String))
    case "jsonVariation":
      let flagKey = args?["flagKey"] as! String
      if let defaultValue = args?["defaultValue"] as? Bool {
        result(LDClient.get()!.variation(forKey: flagKey, defaultValue: defaultValue))
      } else if let defaultValue = args?["defaultValue"] as? Int {
        result(LDClient.get()!.variation(forKey: flagKey, defaultValue: defaultValue))
      } else if let defaultValue = args?["defaultValue"] as? Double {
        result(LDClient.get()!.variation(forKey: flagKey, defaultValue: defaultValue))
      } else if let defaultValue = args?["defaultValue"] as? String {
        result(LDClient.get()!.variation(forKey: flagKey, defaultValue: defaultValue))
      } else if let defaultValue = args?["defaultValue"] as? [Any] {
        result(LDClient.get()!.variation(forKey: flagKey, defaultValue: defaultValue))
      } else if let defaultValue = args?["defaultValue"] as? [String: Any] {
        result(LDClient.get()!.variation(forKey: flagKey, defaultValue: defaultValue))
      } else {
        result(nil)
      }
    case "allFlags":
        result(LDClient.get()!.allFlags)
    case "setOnline":
      let online: Bool? = args?["online"] as? Bool
      if let online = online {
        LDClient.get()!.setOnline(online)
      }
      result(nil)
    case "flush":
      LDClient.get()!.flush()
      result(nil)
    default:
      result(FlutterMethodNotImplemented)
    }
  }
}
