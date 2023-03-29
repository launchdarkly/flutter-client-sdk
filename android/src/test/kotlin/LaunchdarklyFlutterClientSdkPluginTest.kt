package com.launchdarkly.launchdarkly_flutter_client_sdk

import com.launchdarkly.sdk.UserAttribute;
import com.launchdarkly.sdk.android.LDConfig
import com.launchdarkly.sdk.android.integrations.ApplicationInfoBuilder;
import io.mockk.every
import io.mockk.spyk
import io.mockk.slot
import io.mockk.verify
import kotlin.test.Test
import kotlin.test.assertEquals
import org.junit.runner.RunWith;
import org.robolectric.RobolectricTestRunner

@RunWith(RobolectricTestRunner::class)
internal class LaunchdarklyFlutterClientSdkPluginTest {

    @Test
    fun `test configFromMap with general coverage`() {
        val input : Map<String, Any> = hashMapOf(
            "mobileKey" to "mobileKey",
            "pollUri" to "pollUri",
            "eventsUri" to "eventsUri",
            "streamUri" to "streamUri",
            "eventsCapacity" to 1,
            "eventsFlushIntervalMillis" to 2,
            "connectionTimeoutMillis" to 3,
            "pollingIntervalMillis" to 4,
            "backgroundPollingIntervalMillis" to 5,
            "diagnosticRecordingIntervalMillis" to 6,
            "maxCachedUsers" to 7,
            "stream" to true,
            "offline" to false,
            "disableBackgroundUpdating" to true,
            "useReport" to false,
            "inlineUsersInEvents" to true,
            "evaluationReasons" to false,
            "diagnosticOptOut" to true,
            "autoAliasingOptOut" to false,
            "allAttributesPrivate" to true,
            "privateAttributeNames" to listOf("name", "avatar")
        )

        val spyBuilder = spyk(LDConfig.Builder())
        val output = LaunchdarklyFlutterClientSdkPlugin.configFromMap(input, spyBuilder)

        verify { spyBuilder.mobileKey("mobileKey")}
        assertEquals("pollUri", output.getPollUri().toString())
        assertEquals("eventsUri", output.getEventsUri().toString())
        assertEquals("streamUri", output.getStreamUri().toString())
        verify { spyBuilder.eventsCapacity(1)}
        verify { spyBuilder.eventsFlushIntervalMillis(2)}
        verify { spyBuilder.connectionTimeoutMillis(3)}
        verify { spyBuilder.pollingIntervalMillis(4)}
        verify { spyBuilder.backgroundPollingIntervalMillis(5)}
        verify { spyBuilder.diagnosticRecordingIntervalMillis(6)}
        verify { spyBuilder.stream(true)}
        verify { spyBuilder.offline(false)}
        verify { spyBuilder.disableBackgroundUpdating(true)}
        verify { spyBuilder.useReport(false)}
        verify { spyBuilder.inlineUsersInEvents(true)}
        verify { spyBuilder.evaluationReasons(false)}
        verify { spyBuilder.diagnosticOptOut(true)}
        verify { spyBuilder.autoAliasingOptOut(false)}
        verify { spyBuilder.allAttributesPrivate()}

        var argValues = mutableListOf<UserAttribute?>()
        verify {
            spyBuilder.privateAttributes(*varargAllNullable { argValues.add(it); true })
        }
        assertEquals(2, argValues.size)
        assertEquals("name", argValues.get(0)!!.getName())
        assertEquals("avatar", argValues.get(1)!!.getName())
    }

    @Test
    fun `test configFromMap builds application data correctly`() {
        val input : Map<String, Any> = hashMapOf(
            "applicationId" to "myAppId",
            "applicationVersion" to "myAppVersion",
        )

        val spyBuilder = spyk(LDConfig.Builder())
        val slot = slot<ApplicationInfoBuilder>()
        every { spyBuilder.applicationInfo(capture(slot))} answers { callOriginal() }

        LaunchdarklyFlutterClientSdkPlugin.configFromMap(input, spyBuilder)
        
        val capturedAppInfo = slot.captured.createApplicationInfo()
        assertEquals("myAppId", capturedAppInfo.getApplicationId())
        assertEquals("myAppVersion", capturedAppInfo.getApplicationVersion())
    }

    @Test
    fun `test configFromMap handles missing application info as expected`() {
        val input : Map<String, Any> = emptyMap()

        val spyBuilder = spyk(LDConfig.Builder())
        val slot = slot<ApplicationInfoBuilder>()
        every { spyBuilder.applicationInfo(capture(slot))} answers { callOriginal() }

        LaunchdarklyFlutterClientSdkPlugin.configFromMap(input, spyBuilder)
        
        val capturedAppInfo = slot.captured.createApplicationInfo()
        assertEquals(null, capturedAppInfo.getApplicationId())
        assertEquals(null, capturedAppInfo.getApplicationVersion())
    }
}
