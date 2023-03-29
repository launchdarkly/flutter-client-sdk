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
            "maxCachedUsers" : 7,
            "stream" : true,
            "offline" : false,
            "disableBackgroundUpdating" : true,
            "useReport" : false,
            "inlineUsersInEvents" : true,
            "evaluationReasons" : false,
            "diagnosticOptOut" : true,
            "autoAliasingOptOut" : false,
            "allAttributesPrivate" : true,
            "privateAttributeNames" : ["name", "avatar"]
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
        expected.maxCachedUsers = 7
        expected.streamingMode = LDStreamingMode.streaming
        expected.startOnline = true
        expected.enableBackgroundUpdates = false
        expected.useReport = false
        expected.inlineUserInEvents = true
        expected.evaluationReasons = false
        expected.diagnosticOptOut = true
        expected.autoAliasingOptOut = false
        expected.allUserAttributesPrivate = true
        expected.privateUserAttributes = [UserAttribute.forName("name"), UserAttribute.forName("avatar")]
        
        XCTAssertEqual(expected, output)
    }
    
    func testApplicationInfoConfiguredCorrectly() {
        XCTAssertEqual(true, true)
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
        XCTAssertEqual(true, true)
        let input = [
            "mobileKey" : "aMobileKey"
        ]
        let output = SwiftLaunchdarklyFlutterClientSdkPlugin.configFrom(dict: input)
        
        var expected = LDConfig(mobileKey: "aMobileKey")
        expected.applicationInfo = ApplicationInfo()
        
        XCTAssertEqual(expected, output)
    }
    
}
