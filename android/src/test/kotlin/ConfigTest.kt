package com.launchdarkly.launchdarkly_flutter_client_sdk

import com.launchdarkly.sdk.android.LDConfig
import com.launchdarkly.sdk.android.integrations.ApplicationInfoBuilder;
import com.launchdarkly.sdk.android.integrations.HttpConfigurationBuilder;
import com.launchdarkly.sdk.android.integrations.EventProcessorBuilder;
import com.launchdarkly.sdk.android.integrations.ServiceEndpointsBuilder;
import com.launchdarkly.sdk.android.integrations.StreamingDataSourceBuilder;
import io.mockk.every
import io.mockk.spyk
import io.mockk.slot
import io.mockk.verify
import kotlin.test.Test
import kotlin.test.assertEquals
import kotlin.test.assertIs
import org.junit.runner.RunWith;
import org.robolectric.RobolectricTestRunner

@RunWith(RobolectricTestRunner::class)
internal class ConfigTest {

    @Test
    fun `test configFromMap with general coverage`() {
        val input: Map<String, Any> = hashMapOf(
                "mobileKey" to "mobileKey",
                "applicationId" to "myAppId",
                "applicationName" to "myAppName"
                "applicationVersion" to "myAppVersion",
                "applicationVersionName" to "myAppVersionName",
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
                "evaluationReasons" to false,
                "diagnosticOptOut" to true,
                "allAttributesPrivate" to true,
                "privateAttributes" to listOf("name", "avatar"),
        )

        val spyBuilder = spyk(LDConfig.Builder())
        val appInfoSlot = slot<ApplicationInfoBuilder>()
        val endpointsSlot = slot<ServiceEndpointsBuilder>()
        val streamingSourceSlot = slot<StreamingDataSourceBuilder>()
        val eventsSlot = slot<EventProcessorBuilder>()
        val httpSlot = slot<HttpConfigurationBuilder>()

        every { spyBuilder.applicationInfo(capture(appInfoSlot)) } answers { callOriginal() }
        every { spyBuilder.serviceEndpoints(capture(endpointsSlot)) } answers { callOriginal() }
        every { spyBuilder.dataSource(capture(streamingSourceSlot)) } answers { callOriginal() }
        every { spyBuilder.events(capture(eventsSlot)) } answers { callOriginal() }
        every { spyBuilder.http(capture(httpSlot)) } answers { callOriginal() }

        LaunchdarklyFlutterClientSdkPlugin.configFromMap(input, spyBuilder)
        verify { spyBuilder.mobileKey("mobileKey") }

        val capturedAppInfo = appInfoSlot.captured.createApplicationInfo()
        assertEquals("myAppId", capturedAppInfo.getApplicationId())
        assertEquals("myAppName", capturedAppInfo.getApplicationName())
        assertEquals("myAppVersion", capturedAppInfo.getApplicationVersion())
        assertEquals("myAppVersionName", capturedAppInfo.getApplicationVersionName())

        val capturedServiceEndpoints = endpointsSlot.captured.createServiceEndpoints()
        assertEquals("pollUri", capturedServiceEndpoints.getPollingBaseUri().toString())
        assertEquals("eventsUri", capturedServiceEndpoints.getEventsBaseUri().toString())
        assertEquals("streamUri", capturedServiceEndpoints.getStreamingBaseUri().toString())

        assertIs<StreamingDataSourceBuilder>(streamingSourceSlot.captured)
        assertIs<EventProcessorBuilder>(eventsSlot.captured)
        assertIs<HttpConfigurationBuilder>(httpSlot.captured)
    }

    @Test
    fun `test configFromMap builds application data correctly`() {
        val input: Map<String, Any> = hashMapOf(
                "applicationId" to "myAppId",
                "applicationName" to "myAppName",
                "applicationVersion" to "myAppVersion",
                "applicationVersionName" to "myAppVersionName",
        )

        val spyBuilder = spyk(LDConfig.Builder())
        val slot = slot<ApplicationInfoBuilder>()
        every { spyBuilder.applicationInfo(capture(slot)) } answers { callOriginal() }

        LaunchdarklyFlutterClientSdkPlugin.configFromMap(input, spyBuilder)

        val capturedAppInfo = slot.captured.createApplicationInfo()
        assertEquals("myAppId", capturedAppInfo.getApplicationId())
        assertEquals("myAppName", capturedAppInfo.getApplicationName())
        assertEquals("myAppVersion", capturedAppInfo.getApplicationVersion())
        assertEquals("myAppVersionName", capturedAppInfo.getApplicationVersionName())
    }

    @Test
    fun `test configFromMap handles missing application info as expected`() {
        val input: Map<String, Any> = emptyMap()

        val spyBuilder = spyk(LDConfig.Builder())
        val slot = slot<ApplicationInfoBuilder>()
        every { spyBuilder.applicationInfo(capture(slot)) } answers { callOriginal() }

        LaunchdarklyFlutterClientSdkPlugin.configFromMap(input, spyBuilder)

        val capturedAppInfo = slot.captured.createApplicationInfo()
        assertEquals(null, capturedAppInfo.getApplicationId())
        assertEquals(null, capturedAppInfo.getApplicationName())
        assertEquals(null, capturedAppInfo.getApplicationVersion())
        assertEquals(null, capturedAppInfo.getApplicationVersionName())
    }

    @Test
    fun `test configFromMap private attributes`() {
        val input: Map<String, Any> = hashMapOf(
                "mobileKey" to "mobileKey",
                "allAttributesPrivate" to true,
                "privateAttributes" to listOf("name", "avatar"),
        )

        val spyBuilder = spyk(LDConfig.Builder())
        val eventsSlot = slot<EventProcessorBuilder>()
        every { spyBuilder.events(capture(eventsSlot)) } answers { callOriginal() }
        LaunchdarklyFlutterClientSdkPlugin.configFromMap(input, spyBuilder)
        assertIs<EventProcessorBuilder>(eventsSlot.captured)
    }
}