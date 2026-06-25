package com.vantamusic.audioengine

import java.io.File
import java.io.FileOutputStream
import java.io.InputStream
import java.util.UUID

internal class ContentStagingManager(
    private val stagingDirectory: File,
    private val idGenerator: () -> String = { UUID.randomUUID().toString() },
    private val maxStagedContentBytes: Long = MAX_STAGED_CONTENT_BYTES,
) {
    companion object {
        const val STAGED_CONTENT_PREFIX = "content-"
        const val STAGED_CONTENT_EXTENSION = ".wav"
        const val STAGED_CONTENT_FLAC_EXTENSION = ".flac"
        const val MAX_STAGED_CONTENT_BYTES = 512L * 1024L * 1024L
        const val COPY_BUFFER_BYTES = 64 * 1024
    }

    fun stage(
        input: InputStream,
        currentStagedFile: File? = null,
        extension: String = STAGED_CONTENT_EXTENSION,
    ): ContentStagingResult {
        cleanupCurrent(currentStagedFile)

        if (!stagingDirectory.exists() && !stagingDirectory.mkdirs()) {
            return ContentStagingResult.StageFailed
        }

        val staged = File(
            stagingDirectory,
            "$STAGED_CONTENT_PREFIX${idGenerator()}${safeExtension(extension)}",
        )

        return try {
            input.use { source ->
                FileOutputStream(staged).use { output ->
                    val buffer = ByteArray(COPY_BUFFER_BYTES)
                    var copiedBytes = 0L
                    while (true) {
                        val read = source.read(buffer)
                        if (read == -1) break
                        copiedBytes += read.toLong()
                        if (copiedBytes > maxStagedContentBytes) {
                            staged.delete()
                            return ContentStagingResult.TooLarge
                        }
                        output.write(buffer, 0, read)
                    }
                }
            }
            ContentStagingResult.Staged(staged)
        } catch (_: Exception) {
            staged.delete()
            ContentStagingResult.StageFailed
        }
    }

    fun cleanupCurrent(currentStagedFile: File?) {
        currentStagedFile?.delete()
    }

    fun cleanupStale(currentStagedFile: File?) {
        val current = currentStagedFile?.canonicalPath
        stagingDirectory.listFiles { file ->
            file.isFile &&
                file.name.startsWith(STAGED_CONTENT_PREFIX) &&
                (file.name.endsWith(STAGED_CONTENT_EXTENSION) || file.name.endsWith(STAGED_CONTENT_FLAC_EXTENSION))
        }?.forEach { file ->
            if (current == null || file.canonicalPath != current) {
                file.delete()
            }
        }
    }

    private fun safeExtension(extension: String): String {
        return when (extension.lowercase()) {
            STAGED_CONTENT_FLAC_EXTENSION -> STAGED_CONTENT_FLAC_EXTENSION
            else -> STAGED_CONTENT_EXTENSION
        }
    }
}

internal sealed class ContentStagingResult {
    data class Staged(val file: File) : ContentStagingResult()
    data object TooLarge : ContentStagingResult()
    data object StageFailed : ContentStagingResult()
}
