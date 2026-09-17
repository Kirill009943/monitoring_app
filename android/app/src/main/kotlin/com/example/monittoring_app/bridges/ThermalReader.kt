package com.example.monittoring_app.bridges

import android.content.Context
import android.content.Intent
import android.content.IntentFilter
import android.os.BatteryManager
import android.os.Build
import android.os.PowerManager
import java.io.File

class ThermalReader(private val context: Context) {

    fun listZones(): ArrayList<HashMap<String, Any?>> {
        val out = ArrayList<HashMap<String, Any?>>()
        for (dir in zoneDirs()) {
            val name = readText(File(dir, "type"))?.trim()?.takeIf { it.isNotEmpty() } ?: dir.name
            val temp = parseTemp(readText(File(dir, "temp"))?.trim())
            out.add(zoneMap(name, dir.absolutePath, temp, temp != null))
        }
        val bt = batteryTempC()
        out.add(zoneMap("battery", "intent", bt, bt != null))
        return out
    }

    fun readZones(names: List<String>): ArrayList<HashMap<String, Any?>> {
        val wanted = names.toSet()
        val out = ArrayList<HashMap<String, Any?>>()
        if (wanted.contains("battery")) {
            batteryTempC()?.let { t ->
                out.add(hashMapOf<String, Any?>("name" to "battery", "tempC" to t))
            }
        }
        for (dir in zoneDirs()) {
            val name = readText(File(dir, "type"))?.trim()?.takeIf { it.isNotEmpty() } ?: dir.name
            if (!wanted.contains(name)) continue
            val temp = parseTemp(readText(File(dir, "temp"))?.trim()) ?: continue
            out.add(hashMapOf<String, Any?>("name" to name, "tempC" to temp))
        }
        return out
    }

    fun thermalStatus(): Int {
        if (Build.VERSION.SDK_INT < 29) return -1
        val pm = context.getSystemService(Context.POWER_SERVICE) as? PowerManager ?: return -1
        return try {
            pm.currentThermalStatus
        } catch (e: Exception) {
            -1
        }
    }

    private fun zoneDirs(): List<File> {
        return try {
            File("/sys/class/thermal")
                .listFiles { f -> f.isDirectory && f.name.startsWith("thermal_zone") }
                ?.sortedBy { it.name }
                ?: emptyList()
        } catch (e: SecurityException) {
            emptyList()
        }
    }

    private fun batteryTempC(): Double? {
        val intent: Intent? = try {
            context.registerReceiver(null, IntentFilter(Intent.ACTION_BATTERY_CHANGED))
        } catch (e: Exception) {
            null
        }
        val t = intent?.getIntExtra(BatteryManager.EXTRA_TEMPERATURE, Int.MIN_VALUE) ?: Int.MIN_VALUE
        return if (t == Int.MIN_VALUE) null else t / 10.0
    }

    private fun zoneMap(name: String, path: String, tempC: Double?, readable: Boolean): HashMap<String, Any?> =
        hashMapOf("name" to name, "path" to path, "tempC" to tempC, "readable" to readable)

    private fun readText(f: File): String? = try {
        f.readText()
    } catch (e: Exception) {
        null
    }

    private fun parseTemp(raw: String?): Double? {
        val v = raw?.toDoubleOrNull() ?: return null
        if (v <= -273.0) return null
        return if (v >= 1000.0) v / 1000.0 else v
    }
}
