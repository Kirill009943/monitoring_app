package com.example.monittoring_app.bridges

import android.app.AppOpsManager
import android.app.usage.UsageStatsManager
import android.content.Context
import android.content.Intent
import android.content.pm.PackageManager
import android.graphics.Bitmap
import android.graphics.Canvas
import android.graphics.drawable.BitmapDrawable
import android.graphics.drawable.Drawable
import android.provider.Settings
import android.util.Base64
import java.io.ByteArrayOutputStream
import java.util.Calendar

class UsageReader(private val context: Context) {

    fun hasUsageAccess(): Boolean {
        val appOps = context.getSystemService(Context.APP_OPS_SERVICE) as AppOpsManager
        return try {
            val mode = appOps.checkOpNoThrow(
                AppOpsManager.OPSTR_GET_USAGE_STATS,
                android.os.Process.myUid(),
                context.packageName
            )
            mode == AppOpsManager.MODE_ALLOWED
        } catch (e: Exception) {
            false
        }
    }

    fun openUsageAccessSettings(): Boolean {
        return try {
            context.startActivity(
                Intent(Settings.ACTION_USAGE_ACCESS_SETTINGS).addFlags(Intent.FLAG_ACTIVITY_NEW_TASK)
            )
            true
        } catch (e: Exception) {
            false
        }
    }

    fun usageToday(): ArrayList<HashMap<String, Any?>> {
        val cal = Calendar.getInstance()
        cal.set(Calendar.HOUR_OF_DAY, 0)
        cal.set(Calendar.MINUTE, 0)
        cal.set(Calendar.SECOND, 0)
        cal.set(Calendar.MILLISECOND, 0)
        return query(cal.timeInMillis, System.currentTimeMillis(), UsageStatsManager.INTERVAL_DAILY)
    }

    fun usageRange(startMs: Long, endMs: Long): ArrayList<HashMap<String, Any?>> =
        query(startMs, endMs, UsageStatsManager.INTERVAL_BEST)

    private fun query(startMs: Long, endMs: Long, interval: Int): ArrayList<HashMap<String, Any?>> {
        val out = ArrayList<HashMap<String, Any?>>()
        if (!hasUsageAccess()) return out
        val usm = context.getSystemService(Context.USAGE_STATS_SERVICE) as UsageStatsManager
        val stats = try {
            usm.queryUsageStats(interval, startMs, endMs)
        } catch (e: Exception) {
            null
        } ?: return out
        for (s in stats) {
            if (s.totalTimeInForeground <= 0) continue
            out.add(
                hashMapOf<String, Any?>(
                    "package" to s.packageName,
                    "fgSeconds" to (s.totalTimeInForeground / 1000L).toInt(),
                    "lastUsed" to s.lastTimeUsed
                )
            )
        }
        return out
    }

    fun listInstalled(): ArrayList<HashMap<String, Any?>> {
        val pm = context.packageManager
        val out = ArrayList<HashMap<String, Any?>>()
        val packages = try {
            pm.getInstalledApplications(PackageManager.GET_META_DATA)
        } catch (e: Exception) {
            emptyList()
        }
        for (app in packages) {
            if (app.packageName == context.packageName) continue
            val launch = try {
                pm.getLaunchIntentForPackage(app.packageName)
            } catch (e: Exception) {
                null
            } ?: continue
            val label = try {
                pm.getApplicationLabel(app).toString()
            } catch (e: Exception) {
                app.packageName
            }
            val icon = try {
                drawableToBase64(pm.getApplicationIcon(app.packageName))
            } catch (e: Exception) {
                ""
            }
            out.add(hashMapOf("package" to app.packageName, "label" to label, "icon" to icon))
        }
        out.sortBy { (it["label"] as? String)?.lowercase() ?: "" }
        return out
    }

    private fun drawableToBase64(d: Drawable): String {
        val size = 96
        val src = (d as? BitmapDrawable)?.bitmap
        val bitmap = if (src != null && !src.isRecycled) {
            Bitmap.createScaledBitmap(src, size, size, true)
        } else {
            val bmp = Bitmap.createBitmap(size, size, Bitmap.Config.ARGB_8888)
            val canvas = Canvas(bmp)
            d.setBounds(0, 0, size, size)
            d.draw(canvas)
            bmp
        }
        val stream = ByteArrayOutputStream()
        bitmap.compress(Bitmap.CompressFormat.PNG, 100, stream)
        return Base64.encodeToString(stream.toByteArray(), Base64.NO_WRAP)
    }
}
