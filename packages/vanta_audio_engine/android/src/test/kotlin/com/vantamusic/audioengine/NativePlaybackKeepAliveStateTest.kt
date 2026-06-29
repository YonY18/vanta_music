package com.vantamusic.audioengine

import kotlin.test.assertFalse
import kotlin.test.assertTrue
import org.junit.Test

class NativePlaybackKeepAliveStateTest {
    @Test
    fun startRequestsWakeLockOnce() {
        val state = NativePlaybackKeepAliveState()

        val firstStart = state.markStarted()
        val repeatedStart = state.markStarted()

        assertTrue(firstStart.shouldAcquireWakeLock)
        assertFalse(repeatedStart.shouldAcquireWakeLock)
        assertTrue(state.wakeLockHeld)
    }

    @Test
    fun stopReleasesWakeLockOnlyWhenActive() {
        val state = NativePlaybackKeepAliveState()
        state.markStarted()

        val stop = state.markStopped()
        val repeatedStop = state.markStopped()

        assertTrue(stop.shouldReleaseWakeLock)
        assertFalse(repeatedStop.shouldReleaseWakeLock)
        assertFalse(state.wakeLockHeld)
    }

    @Test
    fun completionCleanupReleasesWakeLockExactlyOnce() {
        val state = NativePlaybackKeepAliveState()
        state.markStarted()

        val completion = state.markStopped()
        val duplicateCompletion = state.markStopped()

        assertTrue(completion.shouldReleaseWakeLock)
        assertFalse(duplicateCompletion.shouldReleaseWakeLock)
        assertFalse(state.wakeLockHeld)
    }
}
