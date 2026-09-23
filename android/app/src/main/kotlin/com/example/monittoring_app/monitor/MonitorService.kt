package com.example.monittoring_app.monitor

import android.app.NotificationManager
import android.app.Service
import android.content.Context
import android.content.Intent
import android.content.SharedPreferences
import android.os.Handler
import android.os.HandlerThread
import android.os.IBinder
import com.example.monittoring_app.bridges.BatteryReader
import com.example.monittoring_app.bridges.NotifyHub
import com.example.monittoring_app.bridges.ThermalReader
import com.example.monittoring_app.bridges.UsageReader
import com.example.monittoring_app.bridges.getIntSafe
import java.util.Calendar
import org.json.JSONObject

class MonitorService : Service() {

    companion object {
        @Volatile
        var running = false
            private set

        @Volatile
        var lastTickMs = 0L
            private set

        @Volatile
        var lastError: String? = null
            private set

        private const val ALERT_COOLDOWN_MS = 10L * 60L * 1000L
        private const val PRUNE_INTERVAL_MS = 24L * 3600L * 1000L
        private const val TEMP_HYSTERESIS = 3.0
    }

    private lateinit var prefs: SharedPreferences
    private lateinit var notifyHub: NotifyHub
    private lateinit var thermal: ThermalReader
    private lateinit var battery: BatteryReader
    private lateinit var usage: UsageReader
    private lateinit var db: DbHelper

    private var thread: HandlerThread? = null
    private var handler: Handler? = null

    private val prevUsage = HashMap<String, Long>()
    private var usagePrimed = false
    private val tempLastAlert = HashMap<String, Long>()
    private val tempCooling = HashSet<String>()
    private val appAlertDay = HashMap<String, Int>()
    private var lastPruneMs = 0L

    private val tickRunnable = object : Runnable {
        override fun run() {
            val h = handler ?: return
            if (!prefs.getBoolean("flutter.monitoring_enabled", false)) {
                stopSelf()
                return
            }
            // schedule the next tick BEFORE doing any work, so a failing
            // tick can never break the chain
            val interval = prefs.getIntSafe("flutter.poll_interval_sec", 60).coerceIn(15, 600)
            h.postDelayed(this, interval * 1000L)
            try {
                tick()
                lastTickMs = System.currentTimeMillis()
                lastError = null
            } catch (t: Throwable) {
                lastError = (t.javaClass.simpleName + ": " + t.message).take(200)
            }
        }
    }

    override fun onCreate() {
        super.onCreate()
        notifyHub = NotifyHub(this)
        notifyHub.ensureServiceChannel()
        val notif = notifyHub.buildServiceNotification(0, 0, "--:--")
        try {
            // the manifest already declares foregroundServiceType="specialUse";
            // the 2-arg call uses it and is the most compatible across ROMs
            startForeground(NotifyHub.SERVICE_NOTIF_ID, notif)
        } catch (e: Exception) {
            lastError = "startForeground: " + (e.message ?: e.javaClass.simpleName)
            stopSelf()
            return
        }
        prefs = getSharedPreferences("FlutterSharedPreferences", Context.MODE_PRIVATE)
        thermal = ThermalReader(this)
        battery = BatteryReader(this)
        usage = UsageReader(this)
        db = DbHelper(this)
        notifyHub.refreshAlertChannels()
        val t = HandlerThread("monitor")
        t.start()
        thread = t
        handler = Handler(t.looper)
        running = true
        handler?.post(tickRunnable)
    }

    override fun onStartCommand(intent: Intent?, flags: Int, startId: Int): Int = START_STICKY

    override fun onDestroy() {
        running = false
        handler?.removeCallbacks(tickRunnable)
        thread?.quitSafely()
        thread = null
        handler = null
        try {
            db.close()
        } catch (e: Exception) {
        }
        super.onDestroy()
    }

    override fun onBind(intent: Intent?): IBinder? = null

    private fun tick() {
        if (!prefs.getBoolean("flutter.monitoring_enabled", false)) {
            stopSelf()
            return
        }
        val now = System.currentTimeMillis()
        val rows = ArrayList<DbHelper.SampleRow>()

        val monitored = try {
            prefs.getStringSet("flutter.monitored_sensors", emptySet()) ?: emptySet()
        } catch (e: Exception) {
            emptySet()
        }
        val thresholds = parseDoubleMap("flutter.temp_thresholds")
        if (monitored.isNotEmpty()) {
            for (z in thermal.readZones(monitored.toList())) {
                val name = z["name"] as? String ?: continue
                val tempC = (z["tempC"] as? Number)?.toDouble() ?: continue
                rows.add(DbHelper.SampleRow(now, "thermal", name, tempC))
                checkTempAlert(name, tempC, thresholds[name], now)
            }
        }

        val info = battery.getInfo()
        (info["level"] as? Number)?.takeIf { it.toInt() >= 0 }
            ?.let { rows.add(DbHelper.SampleRow(now, "battery", "level", it.toDouble())) }
        (info["tempC"] as? Number)
            ?.let { rows.add(DbHelper.SampleRow(now, "battery", "temp", it.toDouble())) }
        (info["voltageMv"] as? Number)?.takeIf { it.toInt() > 0 }
            ?.let { rows.add(DbHelper.SampleRow(now, "battery", "voltageMv", it.toDouble())) }
        (info["currentNowUa"] as? Number)?.takeIf { it.toInt() != 0 && it.toInt() != Int.MIN_VALUE }
            ?.let { rows.add(DbHelper.SampleRow(now, "battery", "currentUa", it.toDouble())) }
        (info["chargeCounterUah"] as? Number)?.takeIf { it.toInt() > 0 }
            ?.let { rows.add(DbHelper.SampleRow(now, "battery", "chargeUah", it.toDouble())) }
        val status = (info["status"] as? Number)?.toInt() ?: -1
        val charging = if (status == 2 || status == 5) 1.0 else 0.0
        rows.add(DbHelper.SampleRow(now, "battery", "charging", charging))

        val tracked = parseIntMap("flutter.tracked_apps")
        if (tracked.isNotEmpty() && usage.hasUsageAccess()) {
            val current = HashMap<String, Long>()
            for (u in usage.usageToday()) {
                val pkg = u["package"] as? String ?: continue
                if (!tracked.containsKey(pkg)) continue
                val secs = (u["fgSeconds"] as? Number)?.toLong() ?: continue
                current[pkg] = secs
                if (usagePrimed) {
                    val delta = secs - (prevUsage[pkg] ?: secs)
                    if (delta > 0) rows.add(DbHelper.SampleRow(now, "usage", pkg, delta.toDouble()))
                }
                checkAppAlert(pkg, secs, tracked[pkg] ?: 0)
            }
            prevUsage.clear()
            prevUsage.putAll(current)
            usagePrimed = true
        }

        if (rows.isNotEmpty()) db.insertSamples(rows)

        if (now - lastPruneMs > PRUNE_INTERVAL_MS) {
            val retention = prefs.getIntSafe("flutter.retention_days", 7).coerceAtLeast(1)
            db.prune(now - retention * 86400000L)
            lastPruneMs = now
        }

        try {
            val nm = getSystemService(Context.NOTIFICATION_SERVICE) as NotificationManager
            val cal = Calendar.getInstance()
            val time = "%02d:%02d".format(cal.get(Calendar.HOUR_OF_DAY), cal.get(Calendar.MINUTE))
            nm.notify(
                NotifyHub.SERVICE_NOTIF_ID,
                notifyHub.buildServiceNotification(monitored.size, tracked.size, time)
            )
        } catch (t: Throwable) {
            // notification updates are cosmetic
        }
    }

    private fun parseDoubleMap(key: String): Map<String, Double> {
        val out = HashMap<String, Double>()
        val s = prefs.getString(key, null) ?: return out
        try {
            val obj = JSONObject(s)
            for (k in obj.keys()) out[k] = obj.getDouble(k)
        } catch (e: Exception) {
        }
        return out
    }

    private fun parseIntMap(key: String): Map<String, Int> {
        val out = HashMap<String, Int>()
        val s = prefs.getString(key, null) ?: return out
        try {
            val obj = JSONObject(s)
            for (k in obj.keys()) out[k] = obj.getInt(k)
        } catch (e: Exception) {
        }
        return out
    }

    private fun checkTempAlert(zone: String, tempC: Double, threshold: Double?, now: Long) {
        threshold ?: return
        if (tempCooling.contains(zone)) {
            if (tempC < threshold - TEMP_HYSTERESIS) tempCooling.remove(zone)
            return
        }
        if (tempC >= threshold) {
            val last = tempLastAlert[zone] ?: 0L
            if (now - last >= ALERT_COOLDOWN_MS) {
                notifyHub.sendTempAlert(zone, tempC, threshold)
                tempLastAlert[zone] = now
                tempCooling.add(zone)
            }
        }
    }

    private fun checkAppAlert(pkg: String, fgSeconds: Long, limitMin: Int) {
        if (limitMin <= 0) return
        if (fgSeconds < limitMin * 60L) return
        val cal = Calendar.getInstance()
        val dayKey = cal.get(Calendar.YEAR) * 1000 + cal.get(Calendar.DAY_OF_YEAR)
        if (appAlertDay[pkg] == dayKey) return
        val label = try {
            packageManager.getApplicationLabel(
                @Suppress("DEPRECATION") packageManager.getApplicationInfo(pkg, 0)
            ).toString()
        } catch (e: Exception) {
            pkg
        }
        notifyHub.sendAppAlert(label, fgSeconds / 60L, limitMin)
        appAlertDay[pkg] = dayKey
    }
}
