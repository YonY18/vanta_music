package com.vantamusic.audioengine

import android.annotation.SuppressLint
import android.content.Context
import android.net.Uri
import android.os.Build
import android.os.Handler
import android.os.Looper
import android.os.PowerManager
import android.os.SystemClock
import android.provider.OpenableColumns
import android.util.Log
import io.flutter.embedding.engine.plugins.FlutterPlugin
import io.flutter.plugin.common.EventChannel
import io.flutter.plugin.common.MethodCall
import io.flutter.plugin.common.MethodChannel
import java.io.File

class VantaAudioEnginePlugin : FlutterPlugin, MethodChannel.MethodCallHandler {
    private companion object {
        const val STAGING_DIRECTORY_NAME = "vanta_audio_engine"
        const val PLAYBACK_POLL_INTERVAL_MS = 250L
        const val DIAGNOSTICS_LOG_INTERVAL_MS = 5_000L
        const val LOG_TAG = "VantaAudioEngine"
    }

    private lateinit var methodChannel: MethodChannel
    private lateinit var applicationContext: Context
    private var nativeLibraryLoaded = false
    private var stateSink: EventChannel.EventSink? = null
    private var positionSink: EventChannel.EventSink? = null
    private var durationSink: EventChannel.EventSink? = null
    private var stagedContentFile: File? = null
    private val playbackHandler = Handler(Looper.getMainLooper())
    private var playbackPolling = false
    private var completionEmitted = false
    private var lastTerminalState: String? = null
    private var playbackWakeLock: PowerManager.WakeLock? = null
    private val keepAliveState = NativePlaybackKeepAliveState()
    private var lastRenderDiagnosticsLogMs = 0L
    private var lastRenderDiagnostics: String? = null
    private var nativePlaybackStartedAtMs = 0L
    private var lastNativeErrorCode = "none"

    override fun onAttachedToEngine(binding: FlutterPlugin.FlutterPluginBinding) {
        applicationContext = binding.applicationContext
        nativeLibraryLoaded = try {
            System.loadLibrary("vanta_audio_engine")
            true
        } catch (_: UnsatisfiedLinkError) {
            false
        }
        methodChannel = MethodChannel(binding.binaryMessenger, "vanta_audio_engine/methods")
        methodChannel.setMethodCallHandler(this)
        EventChannel(binding.binaryMessenger, "vanta_audio_engine/playback_state")
            .setStreamHandler(SimpleStreamHandler { stateSink = it })
        EventChannel(binding.binaryMessenger, "vanta_audio_engine/position")
            .setStreamHandler(SimpleStreamHandler { positionSink = it })
        EventChannel(binding.binaryMessenger, "vanta_audio_engine/duration")
            .setStreamHandler(SimpleStreamHandler { durationSink = it })
        cleanupStaleStagedContentFiles()
    }

    override fun onDetachedFromEngine(binding: FlutterPlugin.FlutterPluginBinding) {
        stopPlaybackPolling()
        releaseNativePlaybackKeepAlive()
        if (nativeLibraryLoaded) {
            disposeNative()
        }
        cleanupStagedContentFile()
        cleanupStaleStagedContentFiles()
        methodChannel.setMethodCallHandler(null)
        stateSink = null
        positionSink = null
        durationSink = null
    }

    override fun onMethodCall(call: MethodCall, result: MethodChannel.Result) {
        when (call.method) {
            "init" -> {
                if (!requireNativeLibrary(result)) return
                cleanupStaleStagedContentFiles()
                initNative()
                emitState("idle")
                positionSink?.success(0)
                durationSink?.success(null)
                result.success(null)
            }
            "load" -> {
                if (!requireNativeLibrary(result)) return
                cleanupStaleStagedContentFiles()
                val path = call.argument<String>("path")
                val contentUri = call.argument<String>("uri")
                val resolvedPath = if (!contentUri.isNullOrBlank()) {
                    stageContentUri(
                        contentUri = contentUri,
                        suppliedMimeType = call.argument<String>("contentMimeType"),
                        suppliedDisplayName = call.argument<String>("contentDisplayName"),
                        result = result,
                    ) ?: return
                } else {
                    cleanupStagedContentFile()
                    path
                }
                if (resolvedPath.isNullOrBlank()) {
                    result.error("invalid-source", "Native load requires a local file path.", null)
                    return
                }
                if (!hasSupportedLocalAudioExtension(resolvedPath)) {
                    result.error("unsupported_format", "Native engine currently supports only local WAV, FLAC, or MP3 files.", null)
                    return
                }
                if (!File(resolvedPath).isFile) {
                    result.error("file_not_found", "Local source does not exist.", null)
                    return
                }
                emitState("loading")
                stopPlaybackPolling()
                completionEmitted = false
                lastTerminalState = null
                val loaded = loadNative(resolvedPath)
                if (loaded) {
                    lastNativeErrorCode = "none"
                    Log.i(LOG_TAG, outputLifecycleStatusNative())
                    resetNativeDiagnosticsLogState()
                    emitState("ready")
                    emitDuration()
                    positionSink?.success(positionMsNative())
                    result.success(null)
                } else {
                    val errorCode = loadErrorCodeNative()
                    lastNativeErrorCode = errorCode
                    nativeLoadFailureDiagnosticMessages(loaded, ::outputLifecycleStatusNative)
                        .forEach { Log.i(LOG_TAG, it) }
                    emitState("error", "Native engine could not prepare this audio file.")
                    cleanupStagedContentFile()
                    result.error(errorCode, "Native engine could not prepare this audio file.", null)
                }
            }
            "play" -> {
                if (!requireNativeLibrary(result)) return
                if (playNative()) {
                    lastNativeErrorCode = "none"
                    Log.i(LOG_TAG, outputLifecycleStatusNative())
                    acquirePlaybackWakeLock()
                    emitState("playing")
                    startPlaybackPolling()
                    result.success(null)
                } else {
                    lastNativeErrorCode = "output_error"
                    stopPlaybackPolling()
                    releaseNativePlaybackKeepAlive("play-failed")
                    emitState("error", "Native engine has no prepared local audio file.")
                    result.error("output_error", "Native engine output could not start.", null)
                }
            }
            "pause" -> {
                if (!requireNativeLibrary(result)) return
                val paused = pauseNative()
                Log.i(LOG_TAG, outputLifecycleStatusNative())
                logNativeRenderDiagnostics(force = true)
                stopPlaybackPolling()
                releaseNativePlaybackKeepAlive(if (paused) "pause" else "pause-failed")
                if (paused) {
                    emitPosition()
                    emitState("paused")
                    result.success(null)
                } else {
                    Log.i(LOG_TAG, "native-pause=failed keepalive=released")
                    result.error("native_method_error", "Native pause command failed.", null)
                }
            }
            "stop" -> {
                if (!requireNativeLibrary(result)) return
                logNativeRenderDiagnostics(force = true)
                val stopped = stopNative()
                Log.i(LOG_TAG, outputLifecycleStatusNative())
                stopPlaybackPolling()
                releaseNativePlaybackKeepAlive()
                cleanupStagedContentFile()
                if (stopped) {
                    positionSink?.success(0)
                    emitState("stopped")
                    result.success(null)
                } else {
                    result.error("native_method_error", "Native stop command failed.", null)
                }
            }
            "seek" -> {
                if (!requireNativeLibrary(result)) return
                val requestedPositionMs = call.argument<Number>("positionMs")?.toLong() ?: 0L
                val positionMs = clampSeekPositionMs(requestedPositionMs)
                if (seekNative(positionMs)) {
                    lastNativeErrorCode = "none"
                    completionEmitted = false
                    emitPosition()
                    result.success(null)
                } else {
                    lastNativeErrorCode = "seek_error"
                    result.error("seek_error", "Native seek command failed.", null)
                }
            }
            "setVolume" -> {
                if (!requireNativeLibrary(result)) return
                val volume = call.argument<Number>("volume")?.toFloat() ?: 1.0f
                if (setVolumeNative(volume.coerceIn(0.0f, 1.0f))) {
                    result.success(null)
                } else {
                    result.error("native_method_error", "Native volume command failed.", null)
                }
            }
            "dispose" -> {
                if (nativeLibraryLoaded) {
                    stopPlaybackPolling()
                    releaseNativePlaybackKeepAlive()
                    disposeNative()
                }
                cleanupStagedContentFile()
                cleanupStaleStagedContentFiles()
                emitState("idle")
                result.success(null)
            }
            else -> result.notImplemented()
        }
    }

    private fun emitState(status: String, errorMessage: String? = null) {
        if (lastTerminalState == "error" && status == "completed") return
        if (status == "error" || status == "completed") {
            lastTerminalState = status
        } else if (status == "loading" || status == "ready" || status == "playing") {
            lastTerminalState = null
        }
        stateSink?.success(mapOf("status" to status, "errorMessage" to errorMessage))
    }

    private fun emitPosition() {
        positionSink?.success(positionMsNative())
    }

    private fun emitDuration() {
        val durationMs = durationMsNative()
        durationSink?.success(if (durationMs >= 0L) durationMs else null)
    }

    private fun startPlaybackPolling() {
        if (playbackPolling) return
        playbackPolling = true
        playbackHandler.post(playbackPoll)
    }

    private fun stopPlaybackPolling() {
        playbackPolling = false
        playbackHandler.removeCallbacks(playbackPoll)
    }

    private val playbackPoll = object : Runnable {
        override fun run() {
            if (!playbackPolling) return

            val positionMs = positionMsNative()
            val durationMs = durationMsNative()
            logNativeRenderDiagnostics()
            positionSink?.success(positionMs)
            if (!completionEmitted && durationMs > 0L && positionMs >= durationMs) {
                completionEmitted = true
                playbackPolling = false
                logNativeRenderDiagnostics(force = true)
                val stopped = stopNative()
                Log.i(LOG_TAG, "native-completion-stop=${if (stopped) "ok" else "failed"}")
                Log.i(LOG_TAG, outputLifecycleStatusNative())
                stopPlaybackPolling()
                releaseNativePlaybackKeepAlive("completion")
                cleanupStagedContentFile()
                positionSink?.success(durationMs)
                emitState("completed")
                return
            }

            playbackHandler.postDelayed(this, PLAYBACK_POLL_INTERVAL_MS)
        }
    }

    private fun clampSeekPositionMs(positionMs: Long): Long {
        val durationMs = durationMsNative()
        val nonNegative = positionMs.coerceAtLeast(0L)
        return if (durationMs > 0L) nonNegative.coerceAtMost(durationMs) else nonNegative
    }

    private fun resetNativeDiagnosticsLogState() {
        lastRenderDiagnosticsLogMs = 0L
        lastRenderDiagnostics = null
    }

    private fun logNativeRenderDiagnostics(force: Boolean = false) {
        val diagnostics = renderDiagnosticsNative()
        val previous = lastRenderDiagnostics
        val changed = diagnostics != previous
        val nowMs = SystemClock.uptimeMillis()
        val intervalElapsed = nowMs - lastRenderDiagnosticsLogMs >= DIAGNOSTICS_LOG_INTERVAL_MS

        if (force || (changed && intervalElapsed)) {
            Log.i(LOG_TAG, "native-render $diagnostics ${keepAliveDiagnostics()}")
            lastRenderDiagnosticsLogMs = nowMs
            lastRenderDiagnostics = diagnostics
        } else if (changed) {
            lastRenderDiagnostics = diagnostics
        }
    }

    @SuppressLint("WakelockTimeout")
    private fun acquirePlaybackWakeLock() {
        val existingWakeLock = playbackWakeLock
        val transition = keepAliveState.markStarted()
        if (nativePlaybackStartedAtMs == 0L) {
            nativePlaybackStartedAtMs = SystemClock.uptimeMillis()
        }
        if (transition.shouldStartForegroundService) {
            try {
                val intent = NativePlaybackService.startIntent(applicationContext)
                if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
                    applicationContext.startForegroundService(intent)
                } else {
                    applicationContext.startService(intent)
                }
                Log.i(LOG_TAG, "foreground-service=start-requested type=mediaPlayback")
            } catch (_: Exception) {
                Log.i(LOG_TAG, "foreground-service=start-failed type=mediaPlayback")
            }
        }
        if (!transition.shouldAcquireWakeLock || existingWakeLock?.isHeld == true) return

        val powerManager = applicationContext.getSystemService(Context.POWER_SERVICE) as PowerManager
        val wakeLock = existingWakeLock ?: powerManager.newWakeLock(
            PowerManager.PARTIAL_WAKE_LOCK,
            "VantaMusic:NativePlayback",
        ).also {
            it.setReferenceCounted(false)
            playbackWakeLock = it
        }

        try {
            wakeLock.acquire()
            Log.i(LOG_TAG, "wake-lock=acquired native-background-playback=active")
        } catch (_: SecurityException) {
            Log.i(LOG_TAG, "wake-lock=denied native-background-playback=unprotected")
        }
    }

    private fun releaseNativePlaybackKeepAlive(reason: String = "release") {
        val transition = keepAliveState.markStopped()
        nativePlaybackStartedAtMs = 0L
        if (transition.shouldStopForegroundService) {
            try {
                applicationContext.startService(NativePlaybackService.stopIntent(applicationContext))
                Log.i(LOG_TAG, "foreground-service=stop-requested reason=$reason")
            } catch (_: Exception) {
                Log.i(LOG_TAG, "foreground-service=stop-failed reason=$reason")
            }
        }
        releasePlaybackWakeLock()
        Log.i(LOG_TAG, "keepalive=released reason=$reason")
    }

    private fun keepAliveDiagnostics(): String {
        val continuousPlaybackMs = if (nativePlaybackStartedAtMs > 0L) {
            SystemClock.uptimeMillis() - nativePlaybackStartedAtMs
        } else {
            0L
        }
        return "foreground_service_active=${if (keepAliveState.foregroundServiceActive) 1 else 0}" +
            " wakelock_active=${if (playbackWakeLock?.isHeld == true) 1 else 0}" +
            " continuous_playback_ms=$continuousPlaybackMs" +
            " last_native_error=$lastNativeErrorCode"
    }

    private fun releasePlaybackWakeLock() {
        val wakeLock = playbackWakeLock ?: return
        if (wakeLock.isHeld) {
            wakeLock.release()
            Log.i(LOG_TAG, "wake-lock=released native-background-playback=inactive")
        }
    }

    private fun requireNativeLibrary(result: MethodChannel.Result): Boolean {
        if (nativeLibraryLoaded) return true
        emitState("error", "Native engine library is unavailable.")
        result.error(
            "native-library-unavailable",
            "Native engine library is unavailable.",
            null,
        )
        return false
    }

    private fun stageContentUri(
        contentUri: String,
        suppliedMimeType: String?,
        suppliedDisplayName: String?,
        result: MethodChannel.Result,
    ): String? {
        val uri = try {
            Uri.parse(contentUri)
        } catch (_: Exception) {
            result.error("invalid-source", "Native load requires a valid content source.", null)
            return null
        }

        if (uri.scheme != "content") {
            result.error("unsupported_source", "Native engine accepts only local audio content sources.", null)
            return null
        }

        val resolver = applicationContext.contentResolver
        val resolvedMimeType = resolver.getType(uri)
        val metadata = queryOpenableMetadata(uri)
        val resolvedDisplayName = metadata.displayName
        val resolvedSizeBytes = metadata.sizeBytes
        val extension = supportedContentExtension(uri, resolvedMimeType, resolvedDisplayName, suppliedMimeType, suppliedDisplayName)
        if (extension == null) {
            result.error("unsupported_format", "Native engine currently supports only local WAV or FLAC content sources.", null)
            return null
        }
        if (resolvedSizeBytes != null && resolvedSizeBytes > ContentStagingManager.MAX_STAGED_CONTENT_BYTES) {
            result.error("content-too-large", "Native engine content source is too large to stage.", null)
            return null
        }

        val input = try {
            resolver.openInputStream(uri)
        } catch (_: Exception) {
            null
        }
        if (input == null) {
            result.error("content-open-failed", "Native engine could not open this content source.", null)
            return null
        }

        return when (val stagingResult = stagingManager().stage(input, stagedContentFile, extension)) {
            is ContentStagingResult.Staged -> {
                stagedContentFile = stagingResult.file
                stagingResult.file.absolutePath
            }
            ContentStagingResult.TooLarge -> {
                stagedContentFile = null
                result.error("content-too-large", "Native engine content source is too large to stage.", null)
                null
            }
            ContentStagingResult.StageFailed -> {
                stagedContentFile = null
                result.error("content-stage-failed", "Native engine could not stage this content source.", null)
                null
            }
        }
    }

    private fun queryOpenableMetadata(uri: Uri): OpenableMetadata {
        return try {
            applicationContext.contentResolver.query(
                uri,
                arrayOf(OpenableColumns.DISPLAY_NAME, OpenableColumns.SIZE),
                null,
                null,
                null,
            )?.use { cursor ->
                if (!cursor.moveToFirst()) return@use OpenableMetadata()
                val nameIndex = cursor.getColumnIndex(OpenableColumns.DISPLAY_NAME)
                val sizeIndex = cursor.getColumnIndex(OpenableColumns.SIZE)
                OpenableMetadata(
                    displayName = if (nameIndex >= 0) cursor.getString(nameIndex) else null,
                    sizeBytes = if (sizeIndex >= 0 && !cursor.isNull(sizeIndex)) cursor.getLong(sizeIndex) else null,
                )
            } ?: OpenableMetadata()
        } catch (_: Exception) {
            OpenableMetadata()
        }
    }

    private fun supportedContentExtension(
        uri: Uri,
        resolvedMimeType: String?,
        resolvedDisplayName: String?,
        suppliedMimeType: String?,
        suppliedDisplayName: String?,
    ): String? {
        return supportedContentMimeExtension(resolvedMimeType)
            ?: supportedContentMimeExtension(suppliedMimeType)
            ?: supportedContentPathExtension(resolvedDisplayName)
            ?: supportedContentPathExtension(suppliedDisplayName)
            ?: supportedContentPathExtension(uri.path)
    }

    private fun supportedContentMimeExtension(mimeType: String?): String? {
        return when (mimeType?.lowercase()) {
            "audio/flac", "audio/x-flac" -> ".flac"
            "audio/wav", "audio/x-wav", "audio/wave" -> ".wav"
            else -> null
        }
    }

    private fun supportedContentPathExtension(path: String?): String? {
        val lower = path?.lowercase() ?: return null
        return when {
            lower.endsWith(".flac") -> ".flac"
            lower.endsWith(".wav") -> ".wav"
            else -> null
        }
    }

    private fun supportedLocalPathExtension(path: String?): String? {
        val lower = path?.lowercase() ?: return null
        return when {
            lower.endsWith(".flac") -> ".flac"
            lower.endsWith(".mp3") -> ".mp3"
            lower.endsWith(".wav") -> ".wav"
            else -> null
        }
    }

    private fun hasSupportedLocalAudioExtension(path: String): Boolean = supportedLocalPathExtension(path) != null

    private fun cleanupStagedContentFile() {
        stagingManager().cleanupCurrent(stagedContentFile)
        stagedContentFile = null
    }

    private fun cleanupStaleStagedContentFiles() {
        stagingManager().cleanupStale(stagedContentFile)
    }

    private fun stagingDirectory(): File = File(applicationContext.cacheDir, STAGING_DIRECTORY_NAME)

    private fun stagingManager(): ContentStagingManager = ContentStagingManager(stagingDirectory())

    private external fun initNative(): Boolean
    private external fun loadNative(path: String): Boolean
    private external fun loadErrorCodeNative(): String
    private external fun outputLifecycleStatusNative(): String
    private external fun renderDiagnosticsNative(): String
    private external fun playNative(): Boolean
    private external fun pauseNative(): Boolean
    private external fun stopNative(): Boolean
    private external fun seekNative(positionMs: Long): Boolean
    private external fun setVolumeNative(volume: Float): Boolean
    private external fun positionMsNative(): Long
    private external fun durationMsNative(): Long
    private external fun disposeNative()
}

private data class OpenableMetadata(
    val displayName: String? = null,
    val sizeBytes: Long? = null,
)

private class SimpleStreamHandler(
    private val onSinkChanged: (EventChannel.EventSink?) -> Unit,
) : EventChannel.StreamHandler {
    override fun onListen(arguments: Any?, events: EventChannel.EventSink?) {
        onSinkChanged(events)
    }

    override fun onCancel(arguments: Any?) {
        onSinkChanged(null)
    }
}
