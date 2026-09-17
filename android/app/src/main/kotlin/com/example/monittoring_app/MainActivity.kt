package com.example.monittoring_app

import android.content.Context
import android.content.Intent
import android.content.pm.PackageManager
import android.net.Uri
import android.os.Build
import android.os.PowerManager
import android.provider.Settings
import androidx.core.app.ActivityCompat
import androidx.core.content.ContextCompat
import com.example.monittoring_app.bridges.BatteryReader
import com.example.monittoring_app.bridges.NotifyHub
import com.example.monittoring_app.bridges.ThermalReader
import com.example.monittoring_app.bridges.UsageReader
import com.example.monittoring_app.monitor.MonitorService
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel

class MainActivity : FlutterActivity() {

    companion object {
        private const val REQ_POST_NOTIFICATIONS = 7101
    }

    private var pendingNotifResult: MethodChannel.Result? = null

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        val messenger = flutterEngine.dartExecutor.binaryMessenger
        val thermal = ThermalReader(this)
        val battery = BatteryReader(this)
        val usage = UsageReader(this)
        val notifyHub = NotifyHub(this)

        MethodChannel(messenger, "monittoring/thermal").setMethodCallHandler { call, result ->
            try {
                when (call.method) {
                    "listZones" -> result.success(thermal.listZones())
                    "readZones" -> {
                        val names = call.argument<List<String>>("names") ?: emptyList()
                        result.success(thermal.readZones(names))
                    }
                    "thermalStatus" -> result.success(thermal.thermalStatus())
                    else -> result.notImplemented()
                }
            } catch (e: Exception) {
                result.error("native_error", e.message, null)
            }
        }

        MethodChannel(messenger, "monittoring/battery").setMethodCallHandler { call, result ->
            try {
                when (call.method) {
                    "getInfo" -> result.success(battery.getInfo())
                    else -> result.notImplemented()
                }
            } catch (e: Exception) {
                result.error("native_error", e.message, null)
            }
        }

        MethodChannel(messenger, "monittoring/apps").setMethodCallHandler { call, result ->
            try {
                when (call.method) {
                    "listInstalled" -> Thread {
                        try {
                            val apps = usage.listInstalled()
                            runOnUiThread { result.success(apps) }
                        } catch (e: Exception) {
                            runOnUiThread { result.error("native_error", e.message, null) }
                        }
                    }.start()
                    "hasUsageAccess" -> result.success(usage.hasUsageAccess())
                    "openUsageAccessSettings" -> result.success(usage.openUsageAccessSettings())
                    "usageToday" -> result.success(usage.usageToday())
                    "usageRange" -> {
                        val start = call.argument<Number>("startMs")?.toLong() ?: 0L
                        val end = call.argument<Number>("endMs")?.toLong() ?: System.currentTimeMillis()
                        result.success(usage.usageRange(start, end))
                    }
                    else -> result.notImplemented()
                }
            } catch (e: Exception) {
                result.error("native_error", e.message, null)
            }
        }

        MethodChannel(messenger, "monittoring/monitor").setMethodCallHandler { call, result ->
            try {
                when (call.method) {
                    "startMonitor" -> {
                        ContextCompat.startForegroundService(
                            this,
                            Intent(this, MonitorService::class.java)
                        )
                        result.success(true)
                    }
                    "stopMonitor" -> {
                        stopService(Intent(this, MonitorService::class.java))
                        result.success(true)
                    }
                    "isMonitorRunning" -> result.success(MonitorService.running)
                    "isIgnoringBatteryOptimizations" -> {
                        val pm = getSystemService(Context.POWER_SERVICE) as PowerManager
                        result.success(pm.isIgnoringBatteryOptimizations(packageName))
                    }
                    "requestIgnoreBatteryOptimizations" -> {
                        try {
                            startActivity(
                                Intent(
                                    Settings.ACTION_REQUEST_IGNORE_BATTERY_OPTIMIZATIONS,
                                    Uri.parse("package:$packageName")
                                )
                            )
                            result.success(true)
                        } catch (e: Exception) {
                            result.success(false)
                        }
                    }
                    "openAppSettings" -> {
                        try {
                            startActivity(
                                Intent(
                                    Settings.ACTION_APPLICATION_DETAILS_SETTINGS,
                                    Uri.parse("package:$packageName")
                                )
                            )
                            result.success(true)
                        } catch (e: Exception) {
                            result.success(false)
                        }
                    }
                    else -> result.notImplemented()
                }
            } catch (e: Exception) {
                result.error("native_error", e.message, null)
            }
        }

        MethodChannel(messenger, "monittoring/notify").setMethodCallHandler { call, result ->
            try {
                when (call.method) {
                    "sendTest" -> result.success(notifyHub.sendTest(call.argument<String>("kind") ?: "temp"))
                    "refreshChannels" -> {
                        notifyHub.refreshAlertChannels()
                        result.success(true)
                    }
                    "hasNotificationPermission" -> result.success(hasNotificationPermission())
                    "requestNotificationPermission" -> {
                        when {
                            hasNotificationPermission() -> result.success(true)
                            pendingNotifResult != null -> result.error("busy", null, null)
                            else -> {
                                pendingNotifResult = result
                                ActivityCompat.requestPermissions(
                                    this,
                                    arrayOf(android.Manifest.permission.POST_NOTIFICATIONS),
                                    REQ_POST_NOTIFICATIONS
                                )
                            }
                        }
                    }
                    else -> result.notImplemented()
                }
            } catch (e: Exception) {
                result.error("native_error", e.message, null)
            }
        }
    }

    private fun hasNotificationPermission(): Boolean =
        Build.VERSION.SDK_INT < 33 ||
            checkSelfPermission(android.Manifest.permission.POST_NOTIFICATIONS) ==
            PackageManager.PERMISSION_GRANTED

    override fun onRequestPermissionsResult(
        requestCode: Int,
        permissions: Array<out String>,
        grantResults: IntArray
    ) {
        super.onRequestPermissionsResult(requestCode, permissions, grantResults)
        if (requestCode == REQ_POST_NOTIFICATIONS) {
            pendingNotifResult?.success(
                grantResults.isNotEmpty() && grantResults[0] == PackageManager.PERMISSION_GRANTED
            )
            pendingNotifResult = null
        }
    }
}
