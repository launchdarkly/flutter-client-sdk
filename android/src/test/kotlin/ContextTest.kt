package com.launchdarkly.launchdarkly_flutter_client_sdk

import com.launchdarkly.sdk.ContextKind
import com.launchdarkly.sdk.android.LDConfig
import kotlin.test.Test
import kotlin.test.assertEquals
import kotlin.test.assertTrue
import kotlin.test.assertFalse
import kotlin.test.assertNotNull
import org.junit.runner.RunWith
import org.robolectric.RobolectricTestRunner

@RunWith(RobolectricTestRunner::class)
internal class ContextTest {

    @Test
    fun `single context`() {
        val input: List<Map<String, Any>> = listOf(
                hashMapOf(
                        "kind" to "myKind",
                        "key" to "myKey",
                )
        )
        val output = LaunchdarklyFlutterClientSdkPlugin.contextFrom(input)
        assertFalse(output.isMultiple())
        assertEquals(1, output.individualContextCount)
        assertEquals(ContextKind.of("myKind"), output.kind)
        assertEquals("myKey", output.key)
    }

    @Test
    fun `multi context`() {
        val input: List<Map<String, Any>> = listOf(
                hashMapOf(
                        "kind" to "myKind",
                        "key" to "myKey",
                ),
                hashMapOf(
                        "kind" to "anotherKind",
                        "key" to "anotherKey",
                )
        )
        val output = LaunchdarklyFlutterClientSdkPlugin.contextFrom(input)
        assertTrue(output.isMultiple())
        assertEquals(2, output.individualContextCount)
        assertNotNull(output.getIndividualContext("myKind"))
        assertNotNull(output.getIndividualContext("anotherKind"))
    }

    // TODO sc-195759: Support private, redacted attributes
}
