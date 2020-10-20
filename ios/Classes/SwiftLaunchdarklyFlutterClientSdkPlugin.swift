import Flutter
import UIKit

import LaunchDarkly

public class SwiftLaunchdarklyFlutterClientSdkPlugin: NSObject, FlutterPlugin {
  private let channel: FlutterMethodChannel
  private let flagChangeListener: LDFlagChangeHandler
  private var owners: [String: LDObserverOwner] = [:]

  private init(channel: FlutterMethodChannel) {
    self.channel = channel
    self.flagChangeListener = { (changedFlag: LDChangedFlag) in
      channel.invokeMethod("handleFlagUpdate", arguments: changedFlag.key)
    }
  }

  public static func register(with registrar: FlutterPluginRegistrar) {
    let channel = FlutterMethodChannel(name: "launchdarkly_flutter_client_sdk", binaryMessenger: registrar.messenger())
    let instance = SwiftLaunchdarklyFlutterClientSdkPlugin(channel: channel)
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
    if let wrapperName = dict["wrapperName"] as? String {
        config.wrapperName = wrapperName
    }
    if let wrapperVersion = dict["wrapperVersion"] as? String {
        config.wrapperVersion = wrapperVersion
    }
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
    user.custom = dict["custom"] as? [String: Any]
    return user
  }

  func toBridge(failureReason: ConnectionInformation.LastConnectionFailureReason?) -> Dictionary<String, Any?>? {
    switch failureReason {
    case .httpError, .unauthorized:
      return ["message": failureReason?.description, "failureType": "UNEXPECTED_RESPONSE_CODE"]
    case .unknownError(let message):
      return ["message": message, "failureType": "UNKNOWN_ERROR"]
    default:
      return nil
    }
  }

  let connectionModeMap = [ConnectionInformation.ConnectionMode.streaming: "STREAMING",
                           ConnectionInformation.ConnectionMode.establishingStreamingConnection: "STREAMING",
                           ConnectionInformation.ConnectionMode.polling: "POLLING",
                           ConnectionInformation.ConnectionMode.offline: "OFFLINE"]
  func toBridge(connectionInformation: ConnectionInformation?) -> Dictionary<String, Any?>? {
    guard let connectionInformation = connectionInformation
    else { return nil }
    var res: [String: Any?] = ["connectionState": connectionModeMap[connectionInformation.currentConnectionMode],
                               "lastFailure": toBridge(failureReason: connectionInformation.lastConnectionFailureReason)]
    if let lastSuccessfulConnection = connectionInformation.lastKnownFlagValidity {
      res["lastSuccessfulConnection"] = Int64(floor(lastSuccessfulConnection.timeIntervalSince1970 * 1_000))
    }
    if let lastFailedConnection = connectionInformation.lastFailedConnection {
      res["lastFailedConnection"] = Int64(floor(lastFailedConnection.timeIntervalSince1970 * 1_000))
    }
    return res
  }

  public func handle(_ call: FlutterMethodCall, result: @escaping FlutterResult) {
    let args = call.arguments as? Dictionary<String, Any>
    switch call.method {
    case "start":
      LDClient.start(config: configFrom(dict: args?["config"] as! Dictionary<String, Any>),
                     user: userFrom(dict: args?["user"] as! Dictionary<String, Any>)) {
        result(nil)
      }
      LDClient.get()!.observeFlagsUnchanged(owner: self) { self.channel.invokeMethod("handleFlagsReceived", arguments: [String]()) }
      LDClient.get()!.observeAll(owner: self) { self.channel.invokeMethod("handleFlagsReceived", arguments: Array($0.keys)) }
    case "identify":
      LDClient.get()!.identify(user: userFrom(dict: args?["user"] as! Dictionary<String, Any>)) {
        result(nil)
      }
    case "track":
      try? LDClient.get()!.track(key: args?["eventName"] as! String, data: args?["data"], metricValue: args?["metricValue"] as? Double)
      result(nil)
    case "boolVariation":
      result(LDClient.get()!.variation(forKey: args?["flagKey"] as! String, defaultValue: args?["defaultValue"] as? Bool))
    case "boolVariationDetail":
      let detail = LDClient.get()!.variationDetail(forKey: args?["flagKey"] as! String, defaultValue: args?["defaultValue"] as? Bool)
      result(["value": detail.value, "variationIndex": detail.variationIndex, "reason": detail.reason] as [String: Any?])
    case "intVariation":
      result(LDClient.get()!.variation(forKey: args?["flagKey"] as! String, defaultValue: args?["defaultValue"] as? Int))
    case "intVariationDetail":
      let detail = LDClient.get()!.variationDetail(forKey: args?["flagKey"] as! String, defaultValue: args?["defaultValue"] as? Int)
      result(["value": detail.value, "variationIndex": detail.variationIndex, "reason": detail.reason] as [String: Any?])
    case "doubleVariation":
      result(LDClient.get()!.variation(forKey: args?["flagKey"] as! String, defaultValue: args?["defaultValue"] as? Double))
    case "doubleVariationDetail":
      let detail = LDClient.get()!.variationDetail(forKey: args?["flagKey"] as! String, defaultValue: args?["defaultValue"] as? Double)
      result(["value": detail.value, "variationIndex": detail.variationIndex, "reason": detail.reason] as [String: Any?])
    case "stringVariation":
      result(LDClient.get()!.variation(forKey: args?["flagKey"] as! String, defaultValue: args?["defaultValue"] as? String))
    case "stringVariationDetail":
      let detail = LDClient.get()!.variationDetail(forKey: args?["flagKey"] as! String, defaultValue: args?["defaultValue"] as? String)
      result(["value": detail.value, "variationIndex": detail.variationIndex, "reason": detail.reason] as [String: Any?])
    case "jsonVariation":
      let flagKey = args?["flagKey"] as! String
      if let defaultValue = args?["defaultValue"] as? Bool {
        result(LDClient.get()!.variation(forKey: flagKey, defaultValue: defaultValue) as Bool)
      } else if let defaultValue = args?["defaultValue"] as? Int {
        result(LDClient.get()!.variation(forKey: flagKey, defaultValue: defaultValue) as Int)
      } else if let defaultValue = args?["defaultValue"] as? Double {
        result(LDClient.get()!.variation(forKey: flagKey, defaultValue: defaultValue) as Double)
      } else if let defaultValue = args?["defaultValue"] as? String {
        result(LDClient.get()!.variation(forKey: flagKey, defaultValue: defaultValue) as String)
      } else if let defaultValue = args?["defaultValue"] as? [Any] {
        result(LDClient.get()!.variation(forKey: flagKey, defaultValue: defaultValue) as [Any])
      } else if let defaultValue = args?["defaultValue"] as? [String: Any] {
        result(LDClient.get()!.variation(forKey: flagKey, defaultValue: defaultValue) as [String: Any])
      } else {
        result(nil)
      }
    case "jsonVariationDetail":
      let flagKey = args?["flagKey"] as! String
      if let defaultValue = args?["defaultValue"] as? Bool {
        let detail = LDClient.get()!.variationDetail(forKey: flagKey, defaultValue: defaultValue)
        result(["value": detail.value, "variationIndex": detail.variationIndex, "reason": detail.reason] as [String: Any?])
      } else if let defaultValue = args?["defaultValue"] as? Int {
        let detail = LDClient.get()!.variationDetail(forKey: flagKey, defaultValue: defaultValue)
        result(["value": detail.value, "variationIndex": detail.variationIndex, "reason": detail.reason] as [String: Any?])
      } else if let defaultValue = args?["defaultValue"] as? Double {
        let detail = LDClient.get()!.variationDetail(forKey: flagKey, defaultValue: defaultValue)
        result(["value": detail.value, "variationIndex": detail.variationIndex, "reason": detail.reason] as [String: Any?])
      } else if let defaultValue = args?["defaultValue"] as? String {
        let detail = LDClient.get()!.variationDetail(forKey: flagKey, defaultValue: defaultValue)
        result(["value": detail.value, "variationIndex": detail.variationIndex, "reason": detail.reason] as [String: Any?])
      } else if let defaultValue = args?["defaultValue"] as? [Any] {
        let detail = LDClient.get()!.variationDetail(forKey: flagKey, defaultValue: defaultValue)
        result(["value": detail.value, "variationIndex": detail.variationIndex, "reason": detail.reason] as [String: Any?])
      } else if let defaultValue = args?["defaultValue"] as? [String: Any] {
        let detail = LDClient.get()!.variationDetail(forKey: flagKey, defaultValue: defaultValue)
        result(["value": detail.value, "variationIndex": detail.variationIndex, "reason": detail.reason] as [String: Any?])
      } else {
        result(nil)
      }
    case "allFlags":
        result(LDClient.get()!.allFlags)
    case "flush":
      LDClient.get()!.flush()
      result(nil)
    case "setOnline":
      let online: Bool? = args?["online"] as? Bool
      if let online = online {
        LDClient.get()!.setOnline(online)
      }
      result(nil)
    case "isOnline":
      result(LDClient.get()?.isOnline)
    case "getConnectionInformation":
      result(toBridge(connectionInformation: LDClient.get()!.getConnectionInformation()))
    case "startFlagListening":
      let flagKey = call.arguments as! String
      let observerOwner = Owner();
      owners[flagKey] = observerOwner;
      LDClient.get()!.observe(key: flagKey, owner: observerOwner, handler: flagChangeListener)
      result(nil)
    case "stopFlagListening":
      let flagKey = call.arguments as! String
      if let owner = owners[flagKey] {
        LDClient.get()!.stopObserving(owner: owner)
        owners[flagKey] = nil
      }
      result(nil)
    case "close":
      LDClient.get()!.close()
      result(nil)
    default:
      result(FlutterMethodNotImplemented)
    }
  }
}

private class Owner { }
