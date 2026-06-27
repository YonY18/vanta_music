package com.vantamusic.audioengine

internal class NativePlaybackKeepAliveState {
    var foregroundServiceActive: Boolean = false
        private set
    var wakeLockHeld: Boolean = false
        private set

    fun markStarted(): KeepAliveTransition {
        val shouldStartForegroundService = !foregroundServiceActive
        val shouldAcquireWakeLock = !wakeLockHeld
        foregroundServiceActive = true
        wakeLockHeld = true
        return KeepAliveTransition(
            shouldStartForegroundService = shouldStartForegroundService,
            shouldStopForegroundService = false,
            shouldAcquireWakeLock = shouldAcquireWakeLock,
            shouldReleaseWakeLock = false,
        )
    }

    fun markStopped(): KeepAliveTransition {
        val shouldStopForegroundService = foregroundServiceActive
        val shouldReleaseWakeLock = wakeLockHeld
        foregroundServiceActive = false
        wakeLockHeld = false
        return KeepAliveTransition(
            shouldStartForegroundService = false,
            shouldStopForegroundService = shouldStopForegroundService,
            shouldAcquireWakeLock = false,
            shouldReleaseWakeLock = shouldReleaseWakeLock,
        )
    }
}

internal data class KeepAliveTransition(
    val shouldStartForegroundService: Boolean,
    val shouldStopForegroundService: Boolean,
    val shouldAcquireWakeLock: Boolean,
    val shouldReleaseWakeLock: Boolean,
)
