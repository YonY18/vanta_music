package com.vantamusic.audioengine

import kotlin.test.assertEquals
import kotlin.test.assertFalse
import kotlin.test.assertTrue
import org.junit.Test

class NativeLoadFailureDiagnosticsTest {
    @Test
    fun loadFailureEmitsLifecycleBackendAttemptDiagnostics() {
        val logs = nativeLoadFailureDiagnosticMessages(loadSucceeded = false) {
            "output=open result=failed code=-1 backend=unknown " +
                "backend_strategy=aaudio-first backend_order=aaudio,opensl " +
                "backend_attempts=aaudio:-1,opensl:-1"
        }

        assertEquals(1, logs.size)
        assertTrue(logs.single().contains("output=open result=failed"))
        assertTrue(logs.single().contains("backend_attempts=aaudio:-1,opensl:-1"))
        assertFalse(logs.single().contains("content://"))
        assertFalse(logs.single().contains("/storage/"))
    }

    @Test
    fun loadSuccessDoesNotEmitFailureDiagnostics() {
        val logs = nativeLoadFailureDiagnosticMessages(loadSucceeded = true) {
            error("lifecycle status must not be requested on successful load")
        }

        assertTrue(logs.isEmpty())
    }
}
