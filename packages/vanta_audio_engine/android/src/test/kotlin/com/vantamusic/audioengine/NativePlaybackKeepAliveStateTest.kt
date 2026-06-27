package com.vantamusic.audioengine

import kotlin.test.assertFalse
import kotlin.test.assertTrue
import org.junit.Test

class NativePlaybackKeepAliveStateTest {
    @Test
    fun startRequestsForegroundServiceAndWakeLockOnce() {
        val state = NativePlaybackKeepAliveState()

        val firstStart = state.markStarted()
        val repeatedStart = state.markStarted()

        assertTrue(firstStart.shouldStartForegroundService)
        assertTrue(firstStart.shouldAcquireWakeLock)
        assertFalse(repeatedStart.shouldStartForegroundService)
        assertFalse(repeatedStart.shouldAcquireWakeLock)
        assertTrue(state.foregroundServiceActive)
        assertTrue(state.wakeLockHeld)
    }

    @Test
    fun stopReleasesForegroundServiceAndWakeLockOnlyWhenActive() {
        val state = NativePlaybackKeepAliveState()
        state.markStarted()

        val stop = state.markStopped()
        val repeatedStop = state.markStopped()

        assertTrue(stop.shouldStopForegroundService)
        assertTrue(stop.shouldReleaseWakeLock)
        assertFalse(repeatedStop.shouldStopForegroundService)
        assertFalse(repeatedStop.shouldReleaseWakeLock)
        assertFalse(state.foregroundServiceActive)
        assertFalse(state.wakeLockHeld)
    }

    @Test
    fun completionCleanupReleasesForegroundServiceAndWakeLockExactlyOnce() {
        val state = NativePlaybackKeepAliveState()
        state.markStarted()

        val completion = state.markStopped()
        val duplicateCompletion = state.markStopped()

        assertTrue(completion.shouldStopForegroundService)
        assertTrue(completion.shouldReleaseWakeLock)
        assertFalse(duplicateCompletion.shouldStopForegroundService)
        assertFalse(duplicateCompletion.shouldReleaseWakeLock)
        assertFalse(state.foregroundServiceActive)
        assertFalse(state.wakeLockHeld)
    }
}
