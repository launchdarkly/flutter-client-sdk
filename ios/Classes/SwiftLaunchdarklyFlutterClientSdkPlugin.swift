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

  private func whenIs<T>(_: T.Type, _ value: Any??, _ call: (T) -> ()) {
    if let value = value as? T {
      call(value)
    }
  }

  func configFrom(dict: [String: Any?]) -> LDConfig {
    var config = LDConfig(mobileKey: dict["mobileKey"] as! String)
    whenIs(String.self, dict["pollUri"]) { config.baseUrl = URL(string: $0)! }
    whenIs(String.self, dict["eventsUri"]) { config.eventsUrl = URL(string: $0)! }
    whenIs(String.self, dict["streamUri"]) { config.streamUrl = URL(string: $0)! }
    whenIs(Int.self, dict["eventsCapacity"]) { config.eventCapacity = $0 }
    whenIs(Int.self, dict["eventsFlushIntervalMillis"]) { config.eventFlushInterval = Double($0) / 1000.0 }
    whenIs(Int.self, dict["connectionTimeoutMillis"]) { config.connectionTimeout = Double($0) / 1000.0 }
    whenIs(Int.self, dict["pollingIntervalMillis"]) { config.flagPollingInterval = Double($0) / 1000.0 }
    whenIs(Int.self, dict["backgroundPollingIntervalMillis"]) { config.backgroundFlagPollingInterval = Double($0) / 1000.0 }
    whenIs(Int.self, dict["diagnosticRecordingIntervalMillis"]) { config.diagnosticRecordingInterval = Double($0) / 1000.0 }
    whenIs(Int.self, dict["maxCachedUsers"]) { config.maxCachedUsers = $0 }
    whenIs(Bool.self, dict["stream"]) { config.streamingMode = $0 ? LDStreamingMode.streaming : LDStreamingMode.polling }
    whenIs(Bool.self, dict["offline"]) { config.startOnline = !$0 }
    whenIs(Bool.self, dict["disableBackgroundUpdating"]) { config.enableBackgroundUpdates = !$0 }
    whenIs(Bool.self, dict["useReport"]) { config.useReport = $0 }
    whenIs(Bool.self, dict["inlineUsersInEvents"]) { config.inlineUserInEvents = $0 }
    whenIs(Bool.self, dict["evaluationReasons"]) { config.evaluationReasons = $0 }
    whenIs(Bool.self, dict["diagnosticOptOut"]) { config.diagnosticOptOut = $0 }
    whenIs(Bool.self, dict["autoAliasingOptOut"]) { config.autoAliasingOptOut = $0 }
    whenIs(Bool.self, dict["allAttributesPrivate"]) { config.allUserAttributesPrivate = $0 }
    whenIs([Any].self, dict["privateAttributeNames"]) { config.privateUserAttributes = $0.compactMap { $0 as? String } }
    whenIs(String.self, dict["wrapperName"]) { config.wrapperName = $0 }
    whenIs(String.self, dict["wrapperVersion"]) { config.wrapperVersion = $0 }
    return config
  }

  func userFrom(dict: [String: Any?]) -> LDUser {
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

  func toBridge(failureReason: ConnectionInformation.LastConnectionFailureReason?) -> [String: Any?]? {
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
  func toBridge(connectionInformation: ConnectionInformation?) -> [String: Any?]? {
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

  func bridgeEvalDetail<T>(_ detail: LDEvaluationDetail<T>) -> [String: Any?] {
    ["value": detail.value, "variationIndex": detail.variationIndex, "reason": detail.reason] as [String: Any?]
  }

  func withLDClient(_ result: @escaping FlutterResult, _ closure: ((LDClient) -> ())) {
    guard let client = LDClient.get()
    else {
      result(FlutterError(code: "NO_CLIENT",
                          message: "Client has not been configured. Call LDClient.start to configure the SDK before using other SDK methods.",
                          details: nil))
      return
    }
    closure(client)
  }

  public func handle(_ call: FlutterMethodCall, result: @escaping FlutterResult) {
    let args = call.arguments as? [String: Any]
    switch call.method {
    case "start":
      let config = configFrom(dict: args?["config"] as! [String: Any])
      let user = userFrom(dict: args?["user"] as! [String: Any])
      let completion = { self.channel.invokeMethod("completeStart", arguments: nil) }
      if let client = LDClient.get() {
        // We've already initialized the native SDK so just switch to the new user.
        client.identify(user: user, completion: completion)
      } else {
        // We have not already initialized the native SDK.
        LDClient.start(config: config, user: user, completion: completion)
        LDClient.get()!.observeFlagsUnchanged(owner: self) { self.channel.invokeMethod("handleFlagsReceived", arguments: [String]()) }
        LDClient.get()!.observeAll(owner: self) { self.channel.invokeMethod("handleFlagsReceived", arguments: Array($0.keys)) }
      }
      result(nil)
    case "identify":
      withLDClient(result) { $0.identify(user: userFrom(dict: args?["user"] as! [String: Any])) { result(nil) } }
    case "alias":
      withLDClient(result) { client in
        client.alias(context: userFrom(dict: args?["user"] as! [String: Any]),
                     previousContext: userFrom(dict: args?["previousUser"] as! [String: Any]))
        result(nil)
      }
    case "track":
      withLDClient(result) { client in
        try? client.track(key: args?["eventName"] as! String,
                          data: args?["data"],
                          metricValue: args?["metricValue"] as? Double)
        result(nil)
      }
    case "boolVariation":
      withLDClient(result) { client in
        result(client.variation(forKey: args?["flagKey"] as! String, defaultValue: args?["defaultValue"] as? Bool))
      }
    case "boolVariationDetail":
      withLDClient(result) { client in
        let detail = client.variationDetail(forKey: args?["flagKey"] as! String, defaultValue: args?["defaultValue"] as? Bool)
        result(bridgeEvalDetail(detail))
      }
    case "intVariation":
      withLDClient(result) { client in
        result(client.variation(forKey: args?["flagKey"] as! String, defaultValue: args?["defaultValue"] as? Int))
      }
    case "intVariationDetail":
      withLDClient(result) { client in
        let detail = client.variationDetail(forKey: args?["flagKey"] as! String, defaultValue: args?["defaultValue"] as? Int)
        result(bridgeEvalDetail(detail))
      }
    case "doubleVariation":
      withLDClient(result) { client in
        result(client.variation(forKey: args?["flagKey"] as! String, defaultValue: args?["defaultValue"] as? Double))
      }
    case "doubleVariationDetail":
      withLDClient(result) { client in
        let detail = client.variationDetail(forKey: args?["flagKey"] as! String, defaultValue: args?["defaultValue"] as? Double)
        result(bridgeEvalDetail(detail))
      }
    case "stringVariation":
      withLDClient(result) { client in
        result(client.variation(forKey: args?["flagKey"] as! String, defaultValue: args?["defaultValue"] as? String))
      }
    case "stringVariationDetail":
      withLDClient(result) { client in
        let detail = client.variationDetail(forKey: args?["flagKey"] as! String, defaultValue: args?["defaultValue"] as? String)
        result(bridgeEvalDetail(detail))
      }
    case "jsonVariation":
      let flagKey = args?["flagKey"] as! String
      withLDClient(result) { client in
        if let defaultValue = args?["defaultValue"] as? Bool {
          result(client.variation(forKey: flagKey, defaultValue: defaultValue) as Bool)
        } else if let defaultValue = args?["defaultValue"] as? Int {
          result(client.variation(forKey: flagKey, defaultValue: defaultValue) as Int)
        } else if let defaultValue = args?["defaultValue"] as? Double {
          result(client.variation(forKey: flagKey, defaultValue: defaultValue) as Double)
        } else if let defaultValue = args?["defaultValue"] as? String {
          result(client.variation(forKey: flagKey, defaultValue: defaultValue) as String)
        } else if let defaultValue = args?["defaultValue"] as? [Any] {
          result(client.variation(forKey: flagKey, defaultValue: defaultValue) as [Any])
        } else if let defaultValue = args?["defaultValue"] as? [String: Any] {
          result(client.variation(forKey: flagKey, defaultValue: defaultValue) as [String: Any])
        } else {
          result(nil)
        }
      }
    case "jsonVariationDetail":
      let flagKey = args?["flagKey"] as! String
      withLDClient(result) { client in
        if let defaultValue = args?["defaultValue"] as? Bool {
          let detail = client.variationDetail(forKey: flagKey, defaultValue: defaultValue)
          result(bridgeEvalDetail(detail))
        } else if let defaultValue = args?["defaultValue"] as? Int {
          let detail = client.variationDetail(forKey: flagKey, defaultValue: defaultValue)
          result(bridgeEvalDetail(detail))
        } else if let defaultValue = args?["defaultValue"] as? Double {
          let detail = client.variationDetail(forKey: flagKey, defaultValue: defaultValue)
          result(bridgeEvalDetail(detail))
        } else if let defaultValue = args?["defaultValue"] as? String {
          let detail = client.variationDetail(forKey: flagKey, defaultValue: defaultValue)
          result(bridgeEvalDetail(detail))
        } else if let defaultValue = args?["defaultValue"] as? [Any] {
          let detail = client.variationDetail(forKey: flagKey, defaultValue: defaultValue)
          result(bridgeEvalDetail(detail))
        } else if let defaultValue = args?["defaultValue"] as? [String: Any] {
          let detail = client.variationDetail(forKey: flagKey, defaultValue: defaultValue)
          result(bridgeEvalDetail(detail))
        } else {
          result(nil)
        }
      }
    case "allFlags":
      withLDClient(result) { result($0.allFlags) }
    case "flush":
      LDClient.get()?.flush()
      result(nil)
    case "setOnline":
      withLDClient(result) { client in
        client.setOnline(args?["online"] as! Bool)
        result(nil)
      }
    case "isOffline":
      withLDClient(result) { result(!$0.isOnline) }
    case "getConnectionInformation":
      withLDClient(result) { result(toBridge(connectionInformation: $0.getConnectionInformation())) }
    case "startFlagListening":
      let flagKey = call.arguments as! String
      let observerOwner = Owner();
      withLDClient(result) { client in
        owners[flagKey] = observerOwner;
        client.observe(key: flagKey, owner: observerOwner, handler: flagChangeListener)
        result(nil)
      }
    case "stopFlagListening":
      let flagKey = call.arguments as! String
      withLDClient(result) { client in
        if let owner = owners[flagKey] {
          client.stopObserving(owner: owner)
          owners[flagKey] = nil
        }
        result(nil)
      }
    case "close":
      LDClient.get()?.close()
      result(nil)
    default:
      result(FlutterMethodNotImplemented)
    }
  }
}

private class Owner { }
