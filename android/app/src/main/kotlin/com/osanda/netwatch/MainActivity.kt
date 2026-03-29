package com.osanda.netwatch

import android.app.ActivityManager
import android.app.AppOpsManager
import android.app.usage.NetworkStats
import android.app.usage.NetworkStatsManager
import android.app.usage.UsageStatsManager
import android.content.Context
import android.content.Intent
import android.content.pm.ApplicationInfo
import android.content.pm.PackageManager
import android.net.ConnectivityManager
import android.net.NetworkCapabilities
import android.net.TrafficStats
import android.os.Build
import android.os.Process
import android.provider.Settings
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel

class MainActivity : FlutterActivity() {

    private val CHANNEL = "com.osanda.netwatch/network"

    // Track previous byte counts for speed calculation
    private var prevRxBytes = 0L
    private var prevTxBytes = 0L
    private var prevTimestamp = 0L

    // Per-app byte tracking
    private val prevAppRx = HashMap<Int, Long>()
    private val prevAppTx = HashMap<Int, Long>()

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)

        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, CHANNEL)
            .setMethodCallHandler { call, result ->
                when (call.method) {

                    // ─── Check if usage stats permission is granted ──────────
                    "hasUsagePermission" -> {
                        result.success(hasUsageStatsPermission())
                    }

                    // ─── Open Usage Access settings screen ──────────────────
                    "requestUsagePermission" -> {
                        val intent = Intent(Settings.ACTION_USAGE_ACCESS_SETTINGS)
                        intent.flags = Intent.FLAG_ACTIVITY_NEW_TASK
                        startActivity(intent)
                        result.success(null)
                    }

                    // ─── Get total device speed (rx/tx bytes per second) ─────
                    "getDeviceSpeed" -> {
                        val currentRx = TrafficStats.getTotalRxBytes()
                        val currentTx = TrafficStats.getTotalTxBytes()
                        val now = System.currentTimeMillis()

                        val rxSpeed: Long
                        val txSpeed: Long

                        if (prevTimestamp == 0L) {
                            rxSpeed = 0L
                            txSpeed = 0L
                        } else {
                            val elapsed = (now - prevTimestamp) / 1000.0
                            rxSpeed = if (elapsed > 0) ((currentRx - prevRxBytes) / elapsed).toLong() else 0L
                            txSpeed = if (elapsed > 0) ((currentTx - prevTxBytes) / elapsed).toLong() else 0L
                        }

                        prevRxBytes = currentRx
                        prevTxBytes = currentTx
                        prevTimestamp = now

                        result.success(mapOf(
                            "rxBytesPerSec" to rxSpeed.coerceAtLeast(0L),
                            "txBytesPerSec" to txSpeed.coerceAtLeast(0L)
                        ))
                    }

                    // ─── Get per-app network usage + speed ───────────────────
                    "getAppNetworkStats" -> {
                        try {
                            val apps = getPerAppNetworkStats()
                            result.success(apps)
                        } catch (e: Exception) {
                            result.error("STATS_ERROR", e.message, null)
                        }
                    }

                    // ─── Kill / force stop an app ────────────────────────────
                    "killApp" -> {
                        val packageName = call.argument<String>("packageName")
                        if (packageName != null) {
                            try {
                                val am = getSystemService(Context.ACTIVITY_SERVICE) as ActivityManager
                                am.killBackgroundProcesses(packageName)
                                result.success(true)
                            } catch (e: Exception) {
                                result.error("KILL_ERROR", e.message, null)
                            }
                        } else {
                            result.error("INVALID_ARG", "packageName is required", null)
                        }
                    }

                    // ─── Check if device is on WiFi ──────────────────────────
                    "isOnWifi" -> {
                        val cm = getSystemService(Context.CONNECTIVITY_SERVICE) as ConnectivityManager
                        val network = cm.activeNetwork
                        val caps = cm.getNetworkCapabilities(network)
                        result.success(caps?.hasTransport(NetworkCapabilities.TRANSPORT_WIFI) == true)
                    }

                    else -> result.notImplemented()
                }
            }
    }

    // ─── Check usage stats permission ────────────────────────────────────────
    private fun hasUsageStatsPermission(): Boolean {
        val appOps = getSystemService(Context.APP_OPS_SERVICE) as AppOpsManager
        val mode = if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.Q) {
            appOps.unsafeCheckOpNoThrow(
                AppOpsManager.OPSTR_GET_USAGE_STATS,
                Process.myUid(),
                packageName
            )
        } else {
            @Suppress("DEPRECATION")
            appOps.checkOpNoThrow(
                AppOpsManager.OPSTR_GET_USAGE_STATS,
                Process.myUid(),
                packageName
            )
        }
        return mode == AppOpsManager.MODE_ALLOWED
    }

    // ─── Get per-app network stats using TrafficStats (API 14+, no permission needed) ──
    private fun getPerAppNetworkStats(): List<Map<String, Any>> {
        val pm = packageManager
        val result = mutableListOf<Map<String, Any>>()
        val now = System.currentTimeMillis()

        // Get all installed user apps
        val installedApps = pm.getInstalledApplications(PackageManager.GET_META_DATA)

        for (appInfo in installedApps) {
            // Skip system apps that have 0 traffic
            val uid = appInfo.uid
            val rxBytes = TrafficStats.getUidRxBytes(uid)
            val txBytes = TrafficStats.getUidTxBytes(uid)

            // Skip apps with no network activity ever
            if (rxBytes <= 0 && txBytes <= 0) continue

            // Calculate speed delta
            val prevRx = prevAppRx[uid] ?: rxBytes
            val prevTx = prevAppTx[uid] ?: txBytes

            val elapsed = if (prevTimestamp > 0) (now - prevTimestamp) / 1000.0 else 1.0
            val rxSpeed = if (elapsed > 0) ((rxBytes - prevRx) / elapsed).toLong().coerceAtLeast(0L) else 0L
            val txSpeed = if (elapsed > 0) ((txBytes - prevTx) / elapsed).toLong().coerceAtLeast(0L) else 0L

            prevAppRx[uid] = rxBytes
            prevAppTx[uid] = txBytes

            // Only include apps currently active (have speed > 0) or recently used
            val isActive = rxSpeed > 0 || txSpeed > 0

            val appName = try {
                pm.getApplicationLabel(appInfo).toString()
            } catch (e: Exception) {
                appInfo.packageName
            }

            val isSystemApp = (appInfo.flags and ApplicationInfo.FLAG_SYSTEM) != 0

            result.add(mapOf(
                "uid" to uid,
                "packageName" to appInfo.packageName,
                "appName" to appName,
                "rxBytes" to rxBytes,
                "txBytes" to txBytes,
                "rxBytesPerSec" to rxSpeed,
                "txBytesPerSec" to txSpeed,
                "isActive" to isActive,
                "isSystemApp" to isSystemApp
            ))
        }

        // Sort: active apps first, then by total bytes descending
        return result.sortedWith(
            compareByDescending<Map<String, Any>> { (it["rxBytesPerSec"] as Long) + (it["txBytesPerSec"] as Long) }
                .thenByDescending { (it["rxBytes"] as Long) + (it["txBytes"] as Long) }
        )
    }
}