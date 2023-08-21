package com.launchdarkly.launchdarkly_flutter_client_sdk

import com.launchdarkly.sdk.android.LDConfig
import com.launchdarkly.sdk.android.LDConfig.Builder.AutoEnvAttributes
import com.launchdarkly.sdk.android.integrations.ApplicationInfoBuilder
import com.launchdarkly.sdk.android.integrations.HttpConfigurationBuilder
import com.launchdarkly.sdk.android.integrations.EventProcessorBuilder
import com.launchdarkly.sdk.android.integrations.ServiceEndpointsBuilder
import com.launchdarkly.sdk.android.integrations.StreamingDataSourceBuilder
import io.mockk.every
import io.mockk.spyk
import io.mockk.slot
import io.mockk.verify
import kotlin.test.Test
import kotlin.test.assertEquals
import kotlin.test.assertIs
import kotlin.test.assertFalse
import kotlin.test.assertTrue
import org.junit.runner.RunWith
import org.robolectric.RobolectricTestRunner

@RunWith(RobolectricTestRunner::class)
internal class ConfigTest {

    @Test
    fun `test internalConfigFromMap with general coverage`() {
        val input: Map<String, Any> = hashMapOf(
                "mobileKey" to "mobileKey",
                "applicationId" to "myAppId",
                "applicationName" to "myAppName",
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
                "autoEnvAttributes" to true,
                "allAttributesPrivate" to true,
                "privateAttributes" to listOf("name", "avatar"),
        )

        val spyBuilder = spyk(LDConfig.Builder(AutoEnvAttributes.Enabled))
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

        val output = LaunchdarklyFlutterClientSdkPlugin.internalConfigFromMap(input, spyBuilder)
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

        assertTrue(output.isAutoEnvAttributes())
    }

    @Test
    fun `test internalConfigFromMap builds application data correctly`() {
        val input: Map<String, Any> = hashMapOf(
                "applicationId" to "myAppId",
                "applicationName" to "myAppName",
                "applicationVersion" to "myAppVersion",
                "applicationVersionName" to "myAppVersionName",
        )

        val spyBuilder = spyk(LDConfig.Builder(AutoEnvAttributes.Enabled))
        val slot = slot<ApplicationInfoBuilder>()
        every { spyBuilder.applicationInfo(capture(slot)) } answers { callOriginal() }

        LaunchdarklyFlutterClientSdkPlugin.internalConfigFromMap(input, spyBuilder)

        val capturedAppInfo = slot.captured.createApplicationInfo()
        assertEquals("myAppId", capturedAppInfo.getApplicationId())
        assertEquals("myAppName", capturedAppInfo.getApplicationName())
        assertEquals("myAppVersion", capturedAppInfo.getApplicationVersion())
        assertEquals("myAppVersionName", capturedAppInfo.getApplicationVersionName())
    }

    @Test
    fun `test internalConfigFromMap handles missing application info as expected`() {
        val input: Map<String, Any> = emptyMap()
        val spyBuilder = spyk(LDConfig.Builder(AutoEnvAttributes.Enabled))
        LaunchdarklyFlutterClientSdkPlugin.internalConfigFromMap(input, spyBuilder)
        // verify setting application info does not occur.
        verify(exactly = 0) { spyBuilder.applicationInfo(any()) }
    }

    @Test
    fun `test internalConfigFromMap private attributes`() {
        val input: Map<String, Any> = hashMapOf(
                "mobileKey" to "mobileKey",
                "allAttributesPrivate" to true,
                "privateAttributes" to listOf("name", "avatar"),
        )

        val spyBuilder = spyk(LDConfig.Builder(AutoEnvAttributes.Enabled))
        val eventsSlot = slot<EventProcessorBuilder>()
        every { spyBuilder.events(capture(eventsSlot)) } answers { callOriginal() }
        LaunchdarklyFlutterClientSdkPlugin.internalConfigFromMap(input, spyBuilder)
        assertIs<EventProcessorBuilder>(eventsSlot.captured)
    }

    @Test
    fun `test configFromMap autoEnvAttributes true`() {
        val input: Map<String, Any> = hashMapOf(
            "mobileKey" to "mobileKey",
            "autoEnvAttributes" to true,
        )

        val output = LaunchdarklyFlutterClientSdkPlugin.configFromMap(input)
        assertTrue(output.isAutoEnvAttributes())
    }

    @Test
    fun `test configFromMap autoEnvAttributes false`() {
        val input: Map<String, Any> = hashMapOf(
            "mobileKey" to "mobileKey",
            "autoEnvAttributes" to false,
        )

        val output = LaunchdarklyFlutterClientSdkPlugin.configFromMap(input)
        assertFalse(output.isAutoEnvAttributes())
    }

    @Test
    fun `test configFromMap autoEnvAttributes missing`() {
        val input: Map<String, Any> = hashMapOf(
            "mobileKey" to "mobileKey",
        )

        val output = LaunchdarklyFlutterClientSdkPlugin.configFromMap(input)
        assertFalse(output.isAutoEnvAttributes())
    }
}