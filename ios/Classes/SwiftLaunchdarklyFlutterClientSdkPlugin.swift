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

  private static func whenIs<T>(_: T.Type, _ value: Any??, _ call: (T) -> ()) {
    if let value = value as? T {
      call(value)
    }
  }

  public static func configFrom(dict: [String: Any?]) -> LDConfig {
    var config = LDConfig(mobileKey: dict["mobileKey"] as! String)

    var applicationInfo = ApplicationInfo()
    whenIs(String.self, dict["applicationId"]) { applicationInfo.applicationIdentifier($0) }
    whenIs(String.self, dict["applicationVersion"]) { applicationInfo.applicationVersion($0) }
    config.applicationInfo = applicationInfo

    whenIs(String.self, dict["pollUri"]) { config.baseUrl = URL(string: $0)! }
    whenIs(String.self, dict["eventsUri"]) { config.eventsUrl = URL(string: $0)! }
    whenIs(String.self, dict["streamUri"]) { config.streamUrl = URL(string: $0)! }

    whenIs(Int.self, dict["eventsCapacity"]) { config.eventCapacity = $0 }
    whenIs(Int.self, dict["eventsFlushIntervalMillis"]) { config.eventFlushInterval = Double($0) / 1000.0 }
    whenIs(Int.self, dict["connectionTimeoutMillis"]) { config.connectionTimeout = Double($0) / 1000.0 }
    whenIs(Int.self, dict["pollingIntervalMillis"]) { config.flagPollingInterval = Double($0) / 1000.0 }
    whenIs(Int.self, dict["backgroundPollingIntervalMillis"]) { config.backgroundFlagPollingInterval = Double($0) / 1000.0 }
    whenIs(Int.self, dict["diagnosticRecordingIntervalMillis"]) { config.diagnosticRecordingInterval = Double($0) / 1000.0 }
    whenIs(Int.self, dict["maxCachedContexts"]) { config.maxCachedContexts = $0 }
    whenIs(Bool.self, dict["stream"]) { config.streamingMode = $0 ? LDStreamingMode.streaming : LDStreamingMode.polling }
    whenIs(Bool.self, dict["offline"]) { config.startOnline = !$0 }
    whenIs(Bool.self, dict["disableBackgroundUpdating"]) { config.enableBackgroundUpdates = !$0 }
    whenIs(Bool.self, dict["useReport"]) { config.useReport = $0 }
    whenIs(Bool.self, dict["evaluationReasons"]) { config.evaluationReasons = $0 }
    whenIs(Bool.self, dict["diagnosticOptOut"]) { config.diagnosticOptOut = $0 }
    whenIs(Bool.self, dict["allAttributesPrivate"]) { config.allContextAttributesPrivate = $0 }
    whenIs([String].self, dict["privateAttributes"]) { config.privateContextAttributes = $0.map { Reference($0) } }
    whenIs(String.self, dict["wrapperName"]) { config.wrapperName = $0 }
    whenIs(String.self, dict["wrapperVersion"]) { config.wrapperVersion = $0 }
    return config
  }

  func userFrom(dict: [String: Any?]) -> LDUser {
    let user = LDUser(
      key: dict["key"] as? String,
      name: dict["name"] as? String,
      firstName: dict["firstName"] as? String,
      lastName: dict["firstName"] as? String,
      country: dict["country"] as? String,
      ipAddress: dict["ip"] as? String,
      email: dict["email"] as? String,
      avatar: dict["avatar"] as? String,
      
      custom: (dict["custom"] as? [String: Any] ?? [:]).mapValues { LDValue.fromBridge($0) },
      isAnonymous: dict["anonymous"] as? Bool,
      privateAttributes: (dict["privateAttributeNames"] as? [String] ?? []).map { UserAttribute.forName($0) }
    )

    return user
  }
  
  /// Creates a context from a list of provided dictionaries of serialized contexts.
  ///
  /// - Parameters:
  ///     - list: The list of dictionaries of serialized contexts.  Note that the format of this dict is
  ///     unique to the Flutter MethodChannel because it has kind and key as neighbors at the
  ///     same level in the dict.
  ///
  /// - Returns: A context
  /// - Throws: Error if an issue is encountered converting the `list` to contexts.
  public static func contextFrom(list: [[String: Any?]]) -> Result<LDContext, ContextBuilderError> {
    
    var multiBuilder = LDMultiContextBuilder()
    for contextDict in list {
      
      var builder = LDContextBuilder()
      for (attr, value) in contextDict {
        // ignore _meta
        if (attr == "_meta") {
          continue
        }
        
        // There is a bug in the iOS builder where trySetValue can't be used for kind
        if (attr == "kind") {
          builder.kind(value as! String)
        } else {
          builder.trySetValue(attr, LDValue.fromBridge(value))
        }
      }
      
      // grab private attributes out of _meta field if they are there
      let metaDict = contextDict["_meta"] as? [String: Any] ?? [:]
      let privateAttrs = metaDict["privateAttributes"] as? [String] ?? []
      privateAttrs.forEach{attr in
        builder.addPrivateAttribute(Reference(attr))
      }
      
      switch builder.build() {
      case .success(let context):
        multiBuilder.addContext(context)
      case .failure(let error):
        return Result.failure(error)
      }
    }
    
    return multiBuilder.build();
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

  func bridgeEvalDetail<T>(_ detail: LDEvaluationDetail<T>, _ bridge: ((T) -> Any?) = { $0 as Any }) -> [String: Any?] {
    var reason = detail.reason?.mapValues { $0.toBridge() }

    // sc-208071 - swift sending double for index - should be int - this is a temporary fix
    if let d = reason?["ruleIndex"] as? Double {
        reason?["ruleIndex"] = Int(d)
    }

    return [
      "value": bridge(detail.value),
      "variationIndex": detail.variationIndex,
      "reason": reason
    ] as [String: Any?]
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
  
  func startWithUser(configDict: [String: Any], userDict: [String: Any], result: @escaping FlutterResult) {
    let user = userFrom(dict: userDict)
    let completion = { self.channel.invokeMethod("completeStart", arguments: nil) }
    let config = SwiftLaunchdarklyFlutterClientSdkPlugin.configFrom(dict: configDict)
    if let client = LDClient.get() {
      // We've already initialized the native SDK so just switch to the new user.
      client.identify(user: user, completion: completion)
    } else {
      // We have not already initialized the native SDK.
      LDClient.start(config: config, user: user, completion: completion)
      LDClient.get()?.observeFlagsUnchanged(owner: self) { self.channel.invokeMethod("handleFlagsReceived", arguments: [String]()) }
      LDClient.get()?.observeAll(owner: self) { self.channel.invokeMethod("handleFlagsReceived", arguments: Array($0.keys)) }
    }
    result(nil)
  }
  
  func startWithContext(configDict: [String: Any], contextList: [[String: Any]], result: @escaping FlutterResult) {
    let completion = { self.channel.invokeMethod("completeStart", arguments: nil) }
    let config = SwiftLaunchdarklyFlutterClientSdkPlugin.configFrom(dict: configDict)
    switch SwiftLaunchdarklyFlutterClientSdkPlugin.contextFrom(list: contextList) {
    case .success(let context):
      if let client = LDClient.get() {
        // We've already initialized the native SDK so just switch to the new user.
        client.identify(context: context, completion: completion)
      } else {
        // We have not already initialized the native SDK.
        LDClient.start(config: config, context: context, completion: completion)
        LDClient.get()?.observeFlagsUnchanged(owner: self) { self.channel.invokeMethod("handleFlagsReceived", arguments: [String]()) }
        LDClient.get()?.observeAll(owner: self) { self.channel.invokeMethod("handleFlagsReceived", arguments: Array($0.keys)) }
      }
      result(nil)
    case .failure(let error):
      result(FlutterError(code: "INVALID_CONTEXT", message: error.localizedDescription, details: nil))
    }
  }
  
  func identifyWithUser(userDict: [String: Any], result: @escaping FlutterResult) {
    withLDClient(result) { $0.identify(user: userFrom(dict: userDict)) { result(nil) } }
  }
  
  func identifyWithContext(contextList: [[String: Any]], result: @escaping FlutterResult) {
    switch SwiftLaunchdarklyFlutterClientSdkPlugin.contextFrom(list: contextList) {
    case .success(let context):
      withLDClient(result) { $0.identify(context: context) { result(nil) } }
    case .failure(let error):
      result(FlutterError(code: "INVALID_CONTEXT", message: error.localizedDescription, details: nil))
    }
  }

  public func handle(_ call: FlutterMethodCall, result: @escaping FlutterResult) {
    let args = call.arguments as? [String: Any]
    switch call.method {
    case "start":
      let configArg = args?["config"] as! [String: Any]
      if let userArg = (args?["user"] as? [String: Any]) {
        startWithUser(configDict: configArg, userDict: userArg, result: result)
      } else {
        let contextArg = args!["context"] as! [[String: Any]]
        startWithContext(configDict: configArg, contextList: contextArg, result: result)
      }
    case "identify":
      if let userArg = (args?["user"] as? [String: Any]) {
        identifyWithUser(userDict: userArg, result: result)
      } else {
        let contextArg = args!["context"] as! [[String: Any]]
        identifyWithContext(contextList: contextArg, result: result)
      }
    case "track":
      withLDClient(result) { client in
        client.track(key: args?["eventName"] as! String,
                     data: LDValue.fromBridge(args?["data"]),
                     metricValue: args?["metricValue"] as? Double)
        result(nil)
      }
    case "boolVariation":
      withLDClient(result) { client in
        result(client.boolVariation(forKey: args?["flagKey"] as! String, defaultValue: args?["defaultValue"] as! Bool))
      }
    case "boolVariationDetail":
      withLDClient(result) { client in
        let detail = client.boolVariationDetail(forKey: args?["flagKey"] as! String, defaultValue: args?["defaultValue"] as! Bool)
        result(bridgeEvalDetail(detail))
      }
    case "intVariation":
      withLDClient(result) { client in
        result(client.intVariation(forKey: args?["flagKey"] as! String, defaultValue: args?["defaultValue"] as! Int))
      }
    case "intVariationDetail":
      withLDClient(result) { client in
        let detail = client.intVariationDetail(forKey: args?["flagKey"] as! String, defaultValue: args?["defaultValue"] as! Int)
        result(bridgeEvalDetail(detail))
      }
    case "doubleVariation":
      withLDClient(result) { client in
        result(client.doubleVariation(forKey: args?["flagKey"] as! String, defaultValue: args?["defaultValue"] as! Double))
      }
    case "doubleVariationDetail":
      withLDClient(result) { client in
        let detail = client.doubleVariationDetail(forKey: args?["flagKey"] as! String, defaultValue: args?["defaultValue"] as! Double)
        result(bridgeEvalDetail(detail))
      }
    case "stringVariation":
      withLDClient(result) { client in
        result(client.stringVariation(forKey: args?["flagKey"] as! String, defaultValue: args?["defaultValue"] as! String))
      }
    case "stringVariationDetail":
      withLDClient(result) { client in
        let detail = client.stringVariationDetail(forKey: args?["flagKey"] as! String, defaultValue: args?["defaultValue"] as! String)
        result(bridgeEvalDetail(detail))
      }
    case "jsonVariation":
      let flagKey = args?["flagKey"] as! String
      withLDClient(result) { client in
        result(client.jsonVariation(forKey: flagKey, defaultValue: LDValue.fromBridge(args?["defaultValue"])).toBridge())
      }
    case "jsonVariationDetail":
      let flagKey = args?["flagKey"] as! String
      withLDClient(result) { client in
        let detail = client.jsonVariationDetail(forKey: flagKey, defaultValue: LDValue.fromBridge(args?["defaultValue"]))
        result(bridgeEvalDetail(detail, { (value: LDValue) in value.toBridge() }))
      }
    case "allFlags":
      withLDClient(result) { result($0.allFlags?.mapValues { $0.toBridge() }) }
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

extension LDValue {
    static func fromBridge(_ value: Any?) -> LDValue {
        guard let value = value, !(value is NSNull)
        else { return .null }
        if let nsNumValue = value as? NSNumber {
            // Flutter bridges both numbers and booleans as `NSNumber`, see
            // https://docs.flutter.dev/development/platform-integration/platform-channels?tab=type-mappings-swift-tab
            // We need to know whether the `NSNumber` was created from a `Bool` value.
            // Adapted from https://stackoverflow.com/a/30223989
            let boolTypeId = CFBooleanGetTypeID()
            if CFGetTypeID(nsNumValue) == boolTypeId {
                return .bool(nsNumValue.boolValue)
            } else {
                return .number(Double(truncating: nsNumValue))
            }
        }
        if let stringValue = value as? String { return .string(stringValue) }
        if let arrayValue = value as? [Any] { return .array(arrayValue.map { fromBridge($0) }) }
        if let dictValue = value as? [String: Any] { return .object(dictValue.mapValues { fromBridge($0) }) }
        return .null
    }

    func toBridge() -> Any? {
        switch self {
        case .null: return nil
        case .bool(let boolValue): return boolValue
        case .number(let numValue): return numValue
        case .string(let stringValue): return stringValue
        case .array(let arrayValue): return arrayValue.map { $0.toBridge() }
        case .object(let objectValue): return objectValue.mapValues { $0.toBridge() }
        }
    }
}
