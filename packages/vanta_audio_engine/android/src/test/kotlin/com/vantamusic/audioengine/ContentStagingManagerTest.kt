package com.vantamusic.audioengine

import java.io.ByteArrayInputStream
import java.io.File
import kotlin.test.assertEquals
import kotlin.test.assertFalse
import kotlin.test.assertIs
import kotlin.test.assertTrue
import org.junit.Rule
import org.junit.Test
import org.junit.rules.TemporaryFolder

class ContentStagingManagerTest {
    @get:Rule
    val temporaryFolder = TemporaryFolder()

    @Test
    fun oversizedCopyReturnsControlledErrorAndDeletesPartialFile() {
        val stagingDir = temporaryFolder.newFolder("staging")
        val manager = ContentStagingManager(
            stagingDirectory = stagingDir,
            idGenerator = { "oversized" },
            maxStagedContentBytes = 4,
        )

        val result = manager.stage(ByteArrayInputStream(byteArrayOf(1, 2, 3, 4, 5)))

        assertEquals(ContentStagingResult.TooLarge, result)
        assertFalse(File(stagingDir, "content-oversized.wav").exists())
        assertTrue(stagingDir.listFiles().orEmpty().isEmpty())
    }

    @Test
    fun staleStagedFilesAreCleanedWhileCurrentFileIsPreserved() {
        val stagingDir = temporaryFolder.newFolder("staging")
        val current = File(stagingDir, "content-current.wav").also { it.writeText("current") }
        val stale = File(stagingDir, "content-stale.wav").also { it.writeText("stale") }
        val unrelated = File(stagingDir, "cover.jpg").also { it.writeText("image") }
        val manager = ContentStagingManager(stagingDir)

        manager.cleanupStale(current)

        assertTrue(current.exists())
        assertFalse(stale.exists())
        assertTrue(unrelated.exists())
    }

    @Test
    fun cleanupCurrentDeletesCurrentStagedFile() {
        val stagingDir = temporaryFolder.newFolder("staging")
        val current = File(stagingDir, "content-current.wav").also { it.writeText("current") }
        val manager = ContentStagingManager(stagingDir)

        manager.cleanupCurrent(current)

        assertFalse(current.exists())
    }

    @Test
    fun generatedStagedFilenameDoesNotUseDisplayNamesOrUris() {
        val stagingDir = temporaryFolder.newFolder("staging")
        val displayNameOrUri = "display-name-from-provider-content-uri"
        val manager = ContentStagingManager(
            stagingDirectory = stagingDir,
            idGenerator = { "123e4567-e89b-12d3-a456-426614174000" },
        )

        val result = manager.stage(
            input = ByteArrayInputStream(byteArrayOf(1, 2, 3)),
        )

        val staged = assertIs<ContentStagingResult.Staged>(result).file
        assertEquals("content-123e4567-e89b-12d3-a456-426614174000.wav", staged.name)
        assertTrue(staged.name.startsWith(ContentStagingManager.STAGED_CONTENT_PREFIX))
        assertTrue(staged.name.endsWith(ContentStagingManager.STAGED_CONTENT_EXTENSION))
        assertFalse(staged.name.contains(displayNameOrUri))
        assertFalse(staged.name.contains("content://"))
    }

    @Test
    fun flacStagingKeepsSafeGeneratedNameWithFlacExtension() {
        val stagingDir = temporaryFolder.newFolder("staging")
        val manager = ContentStagingManager(
            stagingDirectory = stagingDir,
            idGenerator = { "flac-id" },
        )

        val result = manager.stage(
            input = ByteArrayInputStream(byteArrayOf(1, 2, 3)),
            extension = ".flac",
        )

        val staged = assertIs<ContentStagingResult.Staged>(result).file
        assertEquals("content-flac-id.flac", staged.name)
        assertTrue(staged.name.startsWith(ContentStagingManager.STAGED_CONTENT_PREFIX))
    }
}
