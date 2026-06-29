package com.vantamusic.audioengine

internal class NativePlaybackKeepAliveState {
    var wakeLockHeld: Boolean = false
        private set

    fun markStarted(): KeepAliveTransition {
        val shouldAcquireWakeLock = !wakeLockHeld
        wakeLockHeld = true
        return KeepAliveTransition(
            shouldAcquireWakeLock = shouldAcquireWakeLock,
            shouldReleaseWakeLock = false,
        )
    }

    fun markStopped(): KeepAliveTransition {
        val shouldReleaseWakeLock = wakeLockHeld
        wakeLockHeld = false
        return KeepAliveTransition(
            shouldAcquireWakeLock = false,
            shouldReleaseWakeLock = shouldReleaseWakeLock,
        )
    }
}

internal data class KeepAliveTransition(
    val shouldAcquireWakeLock: Boolean,
    val shouldReleaseWakeLock: Boolean,
)
