package com.vantamusic.audioengine

import android.content.Context
import android.net.Uri
import android.provider.OpenableColumns
import io.flutter.embedding.engine.plugins.FlutterPlugin
import io.flutter.plugin.common.EventChannel
import io.flutter.plugin.common.MethodCall
import io.flutter.plugin.common.MethodChannel
import java.io.File

class VantaAudioEnginePlugin : FlutterPlugin, MethodChannel.MethodCallHandler {
    private companion object {
        const val STAGING_DIRECTORY_NAME = "vanta_audio_engine"
    }

    private lateinit var methodChannel: MethodChannel
    private lateinit var applicationContext: Context
    private var nativeLibraryLoaded = false
    private var stateSink: EventChannel.EventSink? = null
    private var positionSink: EventChannel.EventSink? = null
    private var durationSink: EventChannel.EventSink? = null
    private var stagedContentFile: File? = null

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
                if (!resolvedPath.lowercase().endsWith(".wav")) {
                    result.error("unsupported-format", "Native engine currently supports only local WAV files.", null)
                    return
                }
                if (!File(resolvedPath).isFile) {
                    result.error("file-not-found", "Local source does not exist.", null)
                    return
                }
                emitState("loading")
                if (loadNative(resolvedPath)) {
                    emitState("ready")
                    emitDuration()
                    positionSink?.success(positionMsNative())
                    result.success(null)
                } else {
                    emitState("error", "Native engine could not prepare this WAV file.")
                    cleanupStagedContentFile()
                    result.error("native-load-failed", "Native engine could not prepare this WAV file.", null)
                }
            }
            "play" -> {
                if (!requireNativeLibrary(result)) return
                if (playNative()) {
                    emitState("playing")
                    result.success(null)
                } else {
                    emitState("error", "Native engine has no prepared local WAV file.")
                    result.error("not-prepared", "Native engine has no prepared local WAV file.", null)
                }
            }
            "pause" -> {
                if (!requireNativeLibrary(result)) return
                if (pauseNative()) {
                    emitPosition()
                    emitState("paused")
                    result.success(null)
                } else {
                    result.error("not-prepared", "Native engine has no prepared local WAV file.", null)
                }
            }
            "stop" -> {
                if (!requireNativeLibrary(result)) return
                val stopped = stopNative()
                cleanupStagedContentFile()
                if (stopped) {
                    positionSink?.success(0)
                    emitState("ready")
                    result.success(null)
                } else {
                    result.error("not-prepared", "Native engine has no prepared local WAV file.", null)
                }
            }
            "seek" -> {
                if (!requireNativeLibrary(result)) return
                val positionMs = call.argument<Number>("positionMs")?.toLong() ?: 0L
                if (seekNative(positionMs.coerceAtLeast(0L))) {
                    emitPosition()
                    result.success(null)
                } else {
                    result.error("not-prepared", "Native engine has no prepared local WAV file.", null)
                }
            }
            "setVolume" -> {
                if (!requireNativeLibrary(result)) return
                val volume = call.argument<Number>("volume")?.toFloat() ?: 1.0f
                if (setVolumeNative(volume.coerceIn(0.0f, 1.0f))) {
                    result.success(null)
                } else {
                    result.error("not-prepared", "Native engine has no prepared local WAV file.", null)
                }
            }
            "dispose" -> {
                if (nativeLibraryLoaded) {
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
        stateSink?.success(mapOf("status" to status, "errorMessage" to errorMessage))
    }

    private fun emitPosition() {
        positionSink?.success(positionMsNative())
    }

    private fun emitDuration() {
        val durationMs = durationMsNative()
        durationSink?.success(if (durationMs >= 0L) durationMs else null)
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
            result.error("unsupported-source", "Native engine accepts only local WAV sources.", null)
            return null
        }

        val resolver = applicationContext.contentResolver
        val resolvedMimeType = resolver.getType(uri)
        val metadata = queryOpenableMetadata(uri)
        val resolvedDisplayName = metadata.displayName
        val resolvedSizeBytes = metadata.sizeBytes
        if (!hasSupportedWavEvidence(uri, resolvedMimeType, resolvedDisplayName, suppliedMimeType, suppliedDisplayName)) {
            result.error("unsupported-format", "Native engine currently supports only local WAV content sources.", null)
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

        return when (val stagingResult = stagingManager().stage(input, stagedContentFile)) {
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

    private fun hasSupportedWavEvidence(
        uri: Uri,
        resolvedMimeType: String?,
        resolvedDisplayName: String?,
        suppliedMimeType: String?,
        suppliedDisplayName: String?,
    ): Boolean {
        return isSupportedWavMime(resolvedMimeType) ||
            isSupportedWavMime(suppliedMimeType) ||
            resolvedDisplayName?.lowercase()?.endsWith(".wav") == true ||
            suppliedDisplayName?.lowercase()?.endsWith(".wav") == true ||
            uri.path?.lowercase()?.endsWith(".wav") == true
    }

    private fun isSupportedWavMime(mimeType: String?): Boolean {
        return when (mimeType?.lowercase()) {
            "audio/wav", "audio/x-wav", "audio/wave" -> true
            else -> false
        }
    }

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
