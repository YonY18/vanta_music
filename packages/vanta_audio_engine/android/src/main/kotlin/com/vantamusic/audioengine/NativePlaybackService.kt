package com.vantamusic.audioengine

import android.app.Notification
import android.app.NotificationChannel
import android.app.NotificationManager
import android.app.Service
import android.content.Context
import android.content.Intent
import android.content.pm.ServiceInfo
import android.os.Build
import android.os.IBinder
import android.util.Log

class NativePlaybackService : Service() {
    companion object {
        private const val LOG_TAG = "VantaAudioEngine"
        private const val ACTION_START = "com.vantamusic.audioengine.NativePlaybackService.START"
        private const val ACTION_STOP = "com.vantamusic.audioengine.NativePlaybackService.STOP"
        private const val CHANNEL_ID = "vanta_native_playback"
        private const val NOTIFICATION_ID = 4307

        fun startIntent(context: Context): Intent = Intent(context, NativePlaybackService::class.java)
            .setAction(ACTION_START)

        fun stopIntent(context: Context): Intent = Intent(context, NativePlaybackService::class.java)
            .setAction(ACTION_STOP)
    }

    override fun onStartCommand(intent: Intent?, flags: Int, startId: Int): Int {
        return when (intent?.action) {
            ACTION_STOP -> {
                stopForegroundService()
                START_NOT_STICKY
            }
            else -> {
                startForegroundService()
                START_STICKY
            }
        }
    }

    override fun onBind(intent: Intent?): IBinder? = null

    private fun startForegroundService() {
        ensureNotificationChannel()
        val notification = Notification.Builder(this, CHANNEL_ID)
            .setSmallIcon(applicationInfo.icon)
            .setContentTitle("Vanta Music")
            .setContentText("Native playback is active")
            .setOngoing(true)
            .setCategory(Notification.CATEGORY_SERVICE)
            .build()

        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.Q) {
            startForeground(
                NOTIFICATION_ID,
                notification,
                ServiceInfo.FOREGROUND_SERVICE_TYPE_MEDIA_PLAYBACK,
            )
        } else {
            @Suppress("DEPRECATION")
            startForeground(NOTIFICATION_ID, notification)
        }
        Log.i(LOG_TAG, "foreground-service=started type=mediaPlayback")
    }

    private fun stopForegroundService() {
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.N) {
            stopForeground(STOP_FOREGROUND_REMOVE)
        } else {
            @Suppress("DEPRECATION")
            stopForeground(true)
        }
        Log.i(LOG_TAG, "foreground-service=stopped type=mediaPlayback")
        stopSelf()
    }

    private fun ensureNotificationChannel() {
        if (Build.VERSION.SDK_INT < Build.VERSION_CODES.O) return
        val manager = getSystemService(NotificationManager::class.java)
        val existing = manager.getNotificationChannel(CHANNEL_ID)
        if (existing != null) return
        manager.createNotificationChannel(
            NotificationChannel(
                CHANNEL_ID,
                "Native playback",
                NotificationManager.IMPORTANCE_LOW,
            ).apply {
                description = "Keeps experimental native playback active while playing."
            },
        )
    }
}
