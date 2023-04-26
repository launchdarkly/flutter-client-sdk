import XCTest
import launchdarkly_flutter_client_sdk
import LaunchDarkly

final class RunnerTests: XCTestCase {
  
  func testGeneralConfigCoverage() {
    let input: [String: Any?] = [
      "mobileKey" : "mobileKey",
      "pollUri" : "pollUri",
      "eventsUri" : "eventsUri",
      "streamUri" : "streamUri",
      "eventsCapacity" : 1,
      "eventsFlushIntervalMillis" : 2,
      "connectionTimeoutMillis" : 3,
      "pollingIntervalMillis" : 4,
      "backgroundPollingIntervalMillis" : 5,
      "diagnosticRecordingIntervalMillis" : 6,
      "maxCachedContexts" : 7,
      "stream" : true,
      "offline" : false,
      "disableBackgroundUpdating" : true,
      "useReport" : false,
      "evaluationReasons" : false,
      "diagnosticOptOut" : true,
      "allAttributesPrivate" : true,
      "privateAttributes" : ["name", "avatar"]
    ]
    
    let output = SwiftLaunchdarklyFlutterClientSdkPlugin.configFrom(dict: input)
    
    var expected = LDConfig(mobileKey: "mobileKey")
    expected.applicationInfo = ApplicationInfo()
    expected.baseUrl = URL(string: "pollUri")!
    expected.eventsUrl = URL(string: "eventsUri")!
    expected.streamUrl = URL(string: "streamUri")!
    expected.eventCapacity = 1
    expected.eventFlushInterval = 0.002
    expected.connectionTimeout = 0.003
    expected.flagPollingInterval = 0.004
    expected.backgroundFlagPollingInterval = 0.005
    expected.diagnosticRecordingInterval = 6
    expected.maxCachedContexts = 7
    expected.streamingMode = LDStreamingMode.streaming
    expected.startOnline = true
    expected.enableBackgroundUpdates = false
    expected.useReport = false
    expected.evaluationReasons = false
    expected.diagnosticOptOut = true
    expected.allContextAttributesPrivate = true
    expected.privateContextAttributes = [Reference("name"), Reference("avatar")]
    
    XCTAssertEqual(expected, output)
  }
  
  func testApplicationInfoConfiguredCorrectly() {
    let input = [
      "mobileKey" : "aMobileKey",
      "applicationId": "myApplicationId",
      "applicationVersion": "myApplicationVersion"
    ]
    let output = SwiftLaunchdarklyFlutterClientSdkPlugin.configFrom(dict: input)
    
    var expected = LDConfig(mobileKey: "aMobileKey")
    expected.applicationInfo = ApplicationInfo()
    expected.applicationInfo?.applicationIdentifier("myApplicationId")
    expected.applicationInfo?.applicationVersion("myApplicationVersion")
    
    XCTAssertEqual(expected, output)
  }
  
  func testApplicationInfoMissingIsHandled() {
    let input = [
      "mobileKey" : "aMobileKey"
    ]
    let output = SwiftLaunchdarklyFlutterClientSdkPlugin.configFrom(dict: input)
    
    var expected = LDConfig(mobileKey: "aMobileKey")
    expected.applicationInfo = ApplicationInfo()
    
    XCTAssertEqual(expected, output)
  }
  
  func testContextFromSingle() throws {
    let input = [
      [
        "kind" : "myKind",
        "key" : "myKey"
      ]
    ]
    
    let output = try SwiftLaunchdarklyFlutterClientSdkPlugin.contextFrom(list: input).get()
    
    var builder = LDContextBuilder(key: "myKey")
    builder.kind("myKind")
    let expected = try builder.build().get()
    
    XCTAssertEqual(expected, output)
  }
  
  func testContextFromMulti() throws {
    let input = [
      [
        "kind" : "myKind",
        "key" : "myKey"
      ],
      [
        "kind" : "anotherKind",
        "key" : "anotherKey"
      ]
    ]
    
    let output = try SwiftLaunchdarklyFlutterClientSdkPlugin.contextFrom(list: input).get()
    
    var builder1 = LDContextBuilder(key: "myKey")
    builder1.kind("myKind")
    var builder2 = LDContextBuilder(key: "anotherKey")
    builder2.kind("anotherKind")
    var multiBuilder = LDMultiContextBuilder()
    multiBuilder.addContext(try builder1.build().get())
    multiBuilder.addContext(try builder2.build().get())
    let expected = try multiBuilder.build().get()
    
    XCTAssertEqual(expected, output)
  }
  
  func testPrivateAttributesBasic() throws {
    let input = [
      [
        "kind" : "myKind",
        "key" : "myKey",
        "name" : "myName",
        "address" : "mainStreet",
        "_meta" : [
          "privateAttributes" : ["name", "address"]
        ]
      ]
    ]

    let output = try SwiftLaunchdarklyFlutterClientSdkPlugin.contextFrom(list: input).get()

    var builder1 = LDContextBuilder(key: "myKey")
    builder1.kind("myKind")
    builder1.name("myName")
    builder1.trySetValue("address", LDValue.string("mainStreet"))
    builder1.addPrivateAttribute(Reference("name"))
    builder1.addPrivateAttribute(Reference("address"))
    var multiBuilder = LDMultiContextBuilder()
    multiBuilder.addContext(try builder1.build().get())
    let expected = try multiBuilder.build().get()

    XCTAssertEqual(expected, output)
  }

  func testPrivateAttributesNull() throws {
    let input = [
      [
        "kind" : "myKind",
        "key" : "myKey",
        "name" : "myName",
        "address" : "mainStreet",
        "_meta" : [
          "privateAttributes" : nil
        ]
      ]
    ]

    let output = try SwiftLaunchdarklyFlutterClientSdkPlugin.contextFrom(list: input).get()

    var builder1 = LDContextBuilder(key: "myKey")
    builder1.kind("myKind")
    builder1.name("myName")
    builder1.trySetValue("address", LDValue.string("mainStreet"))
    var multiBuilder = LDMultiContextBuilder()
    multiBuilder.addContext(try builder1.build().get())
    let expected = try multiBuilder.build().get()

    XCTAssertEqual(expected, output)
  }
  
  func testPrivateAttributesEmptyList() throws {
    let input = [
      [
        "kind" : "myKind",
        "key" : "myKey",
        "name" : "myName",
        "address" : "mainStreet",
        "_meta" : [
          "privateAttributes" : []
        ]
      ]
    ]

    let output = try SwiftLaunchdarklyFlutterClientSdkPlugin.contextFrom(list: input).get()

    var builder1 = LDContextBuilder(key: "myKey")
    builder1.kind("myKind")
    builder1.name("myName")
    builder1.trySetValue("address", LDValue.string("mainStreet"))
    var multiBuilder = LDMultiContextBuilder()
    multiBuilder.addContext(try builder1.build().get())
    let expected = try multiBuilder.build().get()

    XCTAssertEqual(expected, output)
  }
}
