package com.osanda.netwatch

import android.app.ActivityManager
import android.app.AppOpsManager
import android.app.usage.NetworkStats
import android.app.usage.NetworkStatsManager
import android.content.Context
import android.content.Intent
import android.content.pm.ApplicationInfo
import android.content.pm.PackageManager
import android.graphics.Bitmap
import android.graphics.Canvas
import android.graphics.drawable.BitmapDrawable
import android.graphics.drawable.Drawable
import android.net.ConnectivityManager
import android.net.NetworkCapabilities
import android.net.TrafficStats
import android.net.Uri
import android.os.Build
import android.os.Process
import android.provider.Settings
import android.telephony.TelephonyManager
import android.util.Log
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel
import java.io.ByteArrayOutputStream

class MainActivity : FlutterActivity() {

    private val TAG = "NetWatch"
    private val CHANNEL = "com.osanda.netwatch/network"

    private var devPrevRx = -1L
    private var devPrevTx = -1L
    private var devPrevTime = 0L

    private val iconCache = HashMap<String, ByteArray?>()

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)

        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, CHANNEL)
            .setMethodCallHandler { call, result ->
                when (call.method) {

                    "hasUsagePermission" -> result.success(hasUsageStatsPermission())

                    "requestUsagePermission" -> {
                        startActivity(
                            Intent(Settings.ACTION_USAGE_ACCESS_SETTINGS).apply {
                                flags = Intent.FLAG_ACTIVITY_NEW_TASK
                            }
                        )
                        result.success(null)
                    }

                    "getDeviceSpeed" -> {
                        val now = System.currentTimeMillis()
                        val curRx = TrafficStats.getTotalRxBytes()
                        val curTx = TrafficStats.getTotalTxBytes()
                        var rxSpeed = 0L
                        var txSpeed = 0L
                        if (devPrevRx >= 0 && devPrevTime > 0) {
                            val elapsedSec = (now - devPrevTime) / 1000.0
                            if (elapsedSec >= 0.5 && curRx >= devPrevRx) {
                                rxSpeed = ((curRx - devPrevRx) / elapsedSec).toLong()
                                txSpeed = ((curTx - devPrevTx) / elapsedSec).toLong()
                            }
                        }
                        devPrevRx = curRx
                        devPrevTx = curTx
                        devPrevTime = now
                        result.success(mapOf(
                            "rxBytesPerSec" to rxSpeed.coerceAtLeast(0L),
                            "txBytesPerSec" to txSpeed.coerceAtLeast(0L)
                        ))
                    }

                    "getAppNetworkStats" -> {
                        try {
                            result.success(getPerAppNetworkStats())
                        } catch (e: Exception) {
                            Log.e(TAG, "getAppNetworkStats error: ${e.message}", e)
                            result.error("STATS_ERROR", e.message, null)
                        }
                    }

                    // ── Kill: two-step approach ────────────────────────────────
                    // 1. killBackgroundProcesses — works for pure background apps
                    // 2. Also open system App Info page so user can Force Stop
                    //    apps that protect themselves (Play Store, WhatsApp, etc.)
                    "killApp" -> {
                        val pkg = call.argument<String>("packageName")
                        val openSettings = call.argument<Boolean>("openSettings") ?: false

                        if (pkg == null) {
                            result.error("INVALID_ARG", "packageName required", null)
                            return@setMethodCallHandler
                        }

                        if (openSettings) {
                            // Open the system App Info / Force Stop page
                            try {
                                val intent = Intent(Settings.ACTION_APPLICATION_DETAILS_SETTINGS).apply {
                                    data = Uri.fromParts("package", pkg, null)
                                    flags = Intent.FLAG_ACTIVITY_NEW_TASK
                                }
                                startActivity(intent)
                                result.success("opened_settings")
                            } catch (e: Exception) {
                                result.error("SETTINGS_ERROR", e.message, null)
                            }
                        } else {
                            // Try killing background processes first
                            try {
                                val am = getSystemService(Context.ACTIVITY_SERVICE) as ActivityManager
                                am.killBackgroundProcesses(pkg)
                                Log.d(TAG, "killBackgroundProcesses called for $pkg")
                                result.success("killed")
                            } catch (e: Exception) {
                                Log.e(TAG, "kill error for $pkg: ${e.message}")
                                result.error("KILL_ERROR", e.message, null)
                            }
                        }
                    }

                    "isOnWifi" -> {
                        val cm = getSystemService(Context.CONNECTIVITY_SERVICE) as ConnectivityManager
                        val caps = cm.getNetworkCapabilities(cm.activeNetwork)
                        result.success(caps?.hasTransport(NetworkCapabilities.TRANSPORT_WIFI) == true)
                    }

                    "getAppIcon" -> {
                        val pkg = call.argument<String>("packageName") ?: ""
                        result.success(getAppIconBytes(pkg))
                    }

                    "getDebugStats" -> result.success(getDebugStats())

                    else -> result.notImplemented()
                }
            }
    }

    private fun hasUsageStatsPermission(): Boolean {
        val appOps = getSystemService(Context.APP_OPS_SERVICE) as AppOpsManager
        val mode = if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.Q) {
            appOps.unsafeCheckOpNoThrow(
                AppOpsManager.OPSTR_GET_USAGE_STATS, Process.myUid(), packageName)
        } else {
            @Suppress("DEPRECATION")
            appOps.checkOpNoThrow(
                AppOpsManager.OPSTR_GET_USAGE_STATS, Process.myUid(), packageName)
        }
        return mode == AppOpsManager.MODE_ALLOWED
    }

    private fun getPerAppNetworkStats(): List<Map<String, Any>> {
        val nsm = getSystemService(Context.NETWORK_STATS_SERVICE) as NetworkStatsManager
        val pm = packageManager
        val now = System.currentTimeMillis()
        val windowMs = 4_000L
        val windowStart = now - windowMs

        val rxByUid = HashMap<Int, Long>()
        val txByUid = HashMap<Int, Long>()
        queryNetworkStats(nsm, ConnectivityManager.TYPE_WIFI, windowStart, now, rxByUid, txByUid)
        queryNetworkStats(nsm, ConnectivityManager.TYPE_MOBILE, windowStart, now, rxByUid, txByUid)

        val installedApps = pm.getInstalledApplications(PackageManager.GET_META_DATA)
        val resultList = mutableListOf<Map<String, Any>>()

        for (appInfo in installedApps) {
            val uid = appInfo.uid
            val rxWindow = rxByUid[uid] ?: 0L
            val txWindow = txByUid[uid] ?: 0L
            if (rxWindow == 0L && txWindow == 0L) continue

            val windowSec = windowMs / 1000.0
            val rxSpeed = (rxWindow / windowSec).toLong()
            val txSpeed = (txWindow / windowSec).toLong()
            val isActive = rxSpeed > 100L || txSpeed > 100L

            if (isActive) {
                val n = try { pm.getApplicationLabel(appInfo).toString() } catch (e: Exception) { appInfo.packageName }
                Log.d(TAG, "ACTIVE: $n ↓${rxSpeed}B/s ↑${txSpeed}B/s")
            }

            val totalRx = TrafficStats.getUidRxBytes(uid).coerceAtLeast(0L)
            val totalTx = TrafficStats.getUidTxBytes(uid).coerceAtLeast(0L)
            val appName = try { pm.getApplicationLabel(appInfo).toString() } catch (e: Exception) { appInfo.packageName }
            val isSystemApp = (appInfo.flags and ApplicationInfo.FLAG_SYSTEM) != 0

            resultList.add(mapOf(
                "uid"           to uid,
                "packageName"   to appInfo.packageName,
                "appName"       to appName,
                "rxBytes"       to totalRx,
                "txBytes"       to totalTx,
                "rxBytesPerSec" to rxSpeed,
                "txBytesPerSec" to txSpeed,
                "isActive"      to isActive,
                "isSystemApp"   to isSystemApp
            ))
        }

        return resultList.sortedWith(
            compareByDescending<Map<String, Any>> {
                (it["rxBytesPerSec"] as Long) + (it["txBytesPerSec"] as Long)
            }.thenByDescending {
                (it["rxBytes"] as Long) + (it["txBytes"] as Long)
            }
        )
    }

    private fun queryNetworkStats(
        nsm: NetworkStatsManager,
        networkType: Int,
        startTime: Long,
        endTime: Long,
        rxByUid: HashMap<Int, Long>,
        txByUid: HashMap<Int, Long>
    ) {
        try {
            val subscriberId: String? = if (networkType == ConnectivityManager.TYPE_MOBILE) null else null
            val stats: NetworkStats = nsm.querySummary(networkType, subscriberId, startTime, endTime)
            val bucket = NetworkStats.Bucket()
            while (stats.hasNextBucket()) {
                stats.getNextBucket(bucket)
                val uid = bucket.uid
                if (uid < 0) continue
                rxByUid[uid] = (rxByUid[uid] ?: 0L) + bucket.rxBytes
                txByUid[uid] = (txByUid[uid] ?: 0L) + bucket.txBytes
            }
            stats.close()
        } catch (e: Exception) {
            Log.e(TAG, "queryNetworkStats type=$networkType error: ${e.message}")
        }
    }

    private fun getDebugStats(): List<Map<String, Any>> {
        val nsm = getSystemService(Context.NETWORK_STATS_SERVICE) as NetworkStatsManager
        val pm = packageManager
        val now = System.currentTimeMillis()
        val dayAgo = now - 24 * 60 * 60 * 1000L

        val rxByUid = HashMap<Int, Long>()
        val txByUid = HashMap<Int, Long>()
        queryNetworkStats(nsm, ConnectivityManager.TYPE_WIFI, dayAgo, now, rxByUid, txByUid)
        queryNetworkStats(nsm, ConnectivityManager.TYPE_MOBILE, dayAgo, now, rxByUid, txByUid)

        val apps = pm.getInstalledApplications(PackageManager.GET_META_DATA)
        val result = mutableListOf<Map<String, Any>>()
        val seenUids = HashSet<Int>()

        for (app in apps) {
            val uid = app.uid
            if (seenUids.contains(uid)) continue
            seenUids.add(uid)
            val rx = rxByUid[uid] ?: 0L
            val tx = txByUid[uid] ?: 0L
            if (rx + tx < 100 * 1024) continue
            val name = try { pm.getApplicationLabel(app).toString() } catch (e: Exception) { app.packageName }
            result.add(mapOf(
                "appName"     to name,
                "packageName" to app.packageName,
                "uid"         to uid,
                "rxMB"        to rx / (1024 * 1024),
                "txMB"        to tx / (1024 * 1024)
            ))
        }
        return result.sortedByDescending { (it["rxMB"] as Long) + (it["txMB"] as Long) }
    }

    private fun getAppIconBytes(packageName: String): ByteArray? {
        iconCache[packageName]?.let { return it }
        return try {
            val drawable = packageManager.getApplicationIcon(packageName)
            val bmp = drawableToBitmap(drawable)
            val scaled = Bitmap.createScaledBitmap(bmp, 48, 48, true)
            val stream = ByteArrayOutputStream()
            scaled.compress(Bitmap.CompressFormat.PNG, 85, stream)
            val bytes = stream.toByteArray()
            iconCache[packageName] = bytes
            bytes
        } catch (e: Exception) {
            iconCache[packageName] = null
            null
        }
    }

    private fun drawableToBitmap(drawable: Drawable): Bitmap {
        if (drawable is BitmapDrawable && drawable.bitmap != null) return drawable.bitmap
        val w = drawable.intrinsicWidth.takeIf { it > 0 } ?: 48
        val h = drawable.intrinsicHeight.takeIf { it > 0 } ?: 48
        val bmp = Bitmap.createBitmap(w, h, Bitmap.Config.ARGB_8888)
        val canvas = Canvas(bmp)
        drawable.setBounds(0, 0, canvas.width, canvas.height)
        drawable.draw(canvas)
        return bmp
    }
}