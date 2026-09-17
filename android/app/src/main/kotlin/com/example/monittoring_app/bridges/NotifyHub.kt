package com.example.monittoring_app.bridges

import android.app.Notification
import android.app.NotificationChannel
import android.app.NotificationManager
import android.app.PendingIntent
import android.content.Context
import android.content.Intent
import android.content.SharedPreferences
import android.os.Build
import java.util.Locale

class NotifyHub(private val context: Context) {

    companion object {
        const val CH_SERVICE = "monitor_service"
        const val CH_TEMP = "alerts_temperature"
        const val CH_APP = "alerts_app_time"
        const val SERVICE_NOTIF_ID = 1
    }

    private val prefs: SharedPreferences =
        context.getSharedPreferences("FlutterSharedPreferences", Context.MODE_PRIVATE)

    @Volatile
    private var alertsReady = false

    private val nm: NotificationManager
        get() = context.getSystemService(Context.NOTIFICATION_SERVICE) as NotificationManager

    fun ensureServiceChannel() {
        if (Build.VERSION.SDK_INT < 26) return
        val ch = NotificationChannel(CH_SERVICE, "Monitoring service", NotificationManager.IMPORTANCE_MIN)
        ch.description = "Persistent notification shown while Phone Monitor collects data in the background"
        ch.setShowBadge(false)
        nm.createNotificationChannel(ch)
    }

    fun refreshAlertChannels() {
        doRefreshAlertChannels()
        alertsReady = true
    }

    private fun ensureAlertChannels() {
        if (!alertsReady) refreshAlertChannels()
    }

    private fun doRefreshAlertChannels() {
        if (Build.VERSION.SDK_INT < 26) return
        recreateChannel(CH_TEMP, "Temperature alerts", "temp")
        recreateChannel(CH_APP, "App time alerts", "app")
    }

    private fun recreateChannel(id: String, label: String, kind: String) {
        try {
            // build first: if style prefs are unreadable the old channel survives
            val ch = buildAlertChannel(id, label, kind)
            nm.deleteNotificationChannel(id)
            nm.createNotificationChannel(ch)
        } catch (e: Exception) {
            try {
                nm.createNotificationChannel(
                    NotificationChannel(id, label, NotificationManager.IMPORTANCE_HIGH)
                )
            } catch (e2: Exception) {
            }
        }
    }

    private fun buildAlertChannel(id: String, label: String, kind: String): NotificationChannel {
        val importance = prefs.getIntSafe("flutter.notif_${kind}_importance", 4).coerceIn(2, 5)
        val nmImportance = when (importance) {
            2 -> NotificationManager.IMPORTANCE_LOW
            3 -> NotificationManager.IMPORTANCE_DEFAULT
            5 -> NotificationManager.IMPORTANCE_MAX
            else -> NotificationManager.IMPORTANCE_HIGH
        }
        val ch = NotificationChannel(id, label, nmImportance)
        ch.enableVibration(prefs.getBoolean("flutter.notif_${kind}_vibrate", true))
        if (!prefs.getBoolean("flutter.notif_${kind}_sound", true)) {
            ch.setSound(null, null)
        }
        return ch
    }

    fun buildServiceNotification(sensorCount: Int, appCount: Int): Notification {
        ensureServiceChannel()
        val pi = launchPendingIntent(0)
        val builder = if (Build.VERSION.SDK_INT >= 26) {
            Notification.Builder(context, CH_SERVICE)
        } else {
            Notification.Builder(context).setPriority(Notification.PRIORITY_MIN)
        }
        return builder
            .setContentTitle("Phone Monitor")
            .setContentText("Monitoring $sensorCount sensors · $appCount apps")
            .setSmallIcon(android.R.drawable.ic_menu_info_details)
            .setOngoing(true)
            .setContentIntent(pi)
            .build()
    }

    fun sendTempAlert(zone: String, tempC: Double, threshold: Double) {
        if (!prefs.getBoolean("flutter.notif_temp_enabled", true)) return
        val text = String.format(Locale.US, "%.1f°C (limit %.1f°C)", tempC, threshold)
        postAlert(CH_TEMP, "temp", "High temperature: $zone", text, 1000 + (zone.hashCode() and 0xFFFF))
    }

    fun sendAppAlert(label: String, usedMin: Long, limitMin: Int) {
        if (!prefs.getBoolean("flutter.notif_app_enabled", true)) return
        postAlert(CH_APP, "app", "Time limit reached", "$label: $usedMin min today (limit $limitMin min)", 2000 + (label.hashCode() and 0xFFFF))
    }

    fun sendTest(kind: String): Boolean {
        return try {
            refreshAlertChannels()
            if (kind == "temp") {
                sendTempAlert("cpu-0-big", 42.0, 40.0)
            } else {
                sendAppAlert("YouTube", 125, 120)
            }
            true
        } catch (e: Exception) {
            false
        }
    }

    private fun postAlert(channelId: String, kind: String, title: String, text: String, id: Int) {
        try {
            ensureAlertChannels()
            val pi = launchPendingIntent(id)
            val builder = if (Build.VERSION.SDK_INT >= 26) {
                Notification.Builder(context, channelId)
            } else {
                Notification.Builder(context).apply {
                    var defaults = 0
                    if (prefs.getBoolean("flutter.notif_${kind}_sound", true)) defaults = defaults or Notification.DEFAULT_SOUND
                    if (defaults != 0) setDefaults(defaults)
                    if (prefs.getBoolean("flutter.notif_${kind}_vibrate", true)) {
                        setVibrate(longArrayOf(0, 250, 100, 250))
                    }
                    setPriority(Notification.PRIORITY_HIGH)
                }
            }
            nm.notify(
                id,
                builder
                    .setContentTitle(title)
                    .setContentText(text)
                    .setSmallIcon(android.R.drawable.ic_menu_info_details)
                    .setAutoCancel(true)
                    .setContentIntent(pi)
                    .build()
            )
        } catch (e: Exception) {
            // no permission / channel issues must never crash callers
        }
    }

    private fun launchPendingIntent(requestCode: Int): PendingIntent {
        val intent = try {
            context.packageManager.getLaunchIntentForPackage(context.packageName) ?: Intent()
        } catch (e: Exception) {
            Intent()
        }
        return PendingIntent.getActivity(
            context,
            requestCode,
            intent,
            PendingIntent.FLAG_IMMUTABLE or PendingIntent.FLAG_UPDATE_CURRENT
        )
    }
}
