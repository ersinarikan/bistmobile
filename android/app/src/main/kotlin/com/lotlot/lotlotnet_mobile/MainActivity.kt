package com.lotlot.lotlotnet_mobile

import android.app.NotificationChannel
import android.app.NotificationManager
import android.os.Build
import android.os.Bundle
import io.flutter.embedding.android.FlutterActivity

class MainActivity : FlutterActivity() {
    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)
        ensureDefaultNotificationChannel()
    }

    /** Matches Manifest default_notification_channel_id — Android 8+ tray. */
    private fun ensureDefaultNotificationChannel() {
        if (Build.VERSION.SDK_INT < Build.VERSION_CODES.O) return
        val channel = NotificationChannel(
            CHANNEL_ID,
            "LOTLOT bildirimleri",
            NotificationManager.IMPORTANCE_DEFAULT,
        ).apply {
            description = "Hisse ve sinyal bildirimleri"
        }
        val manager = getSystemService(NotificationManager::class.java) ?: return
        manager.createNotificationChannel(channel)
    }

    companion object {
        const val CHANNEL_ID = "lotlot_alerts"
    }
}
