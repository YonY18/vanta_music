package com.vantamusic.audioengine

internal fun nativeLoadFailureDiagnosticMessages(
    loadSucceeded: Boolean,
    lifecycleStatusProvider: () -> String,
): List<String> {
    if (loadSucceeded) return emptyList()
    return listOf(lifecycleStatusProvider())
}
