package com.example.kidguard

import android.app.AppOpsManager
import android.app.usage.UsageEvents
import android.app.usage.UsageStatsManager
import android.content.Context
import android.content.Intent
import android.os.Process
import java.text.SimpleDateFormat
import java.util.Calendar
import java.util.Locale
import java.util.TimeZone

data class UsageSnapshot(val date: String, val seconds: Map<String, Long>) {
    fun flutter(context: Context): Map<String, Any> {
        val installed = AppCatalog.labels(context)
        val apps = (installed.keys + seconds.keys).map { pkg ->
            val label = installed[pkg] ?: try { context.packageManager.getApplicationLabel(
                context.packageManager.getApplicationInfo(pkg, 0)).toString() } catch (_: Exception) { pkg }
            mapOf("packageName" to pkg, "appName" to label.take(150), "durationSeconds" to (seconds[pkg] ?: 0L))
        }.sortedByDescending { it["durationSeconds"] as Long }
        return mapOf("usageDate" to date, "apps" to apps)
    }
}

object UsageReader {
    fun allowed(context: Context): Boolean {
        val ops = context.getSystemService(Context.APP_OPS_SERVICE) as AppOpsManager
        @Suppress("DEPRECATION")
        return ops.checkOpNoThrow(AppOpsManager.OPSTR_GET_USAGE_STATS, Process.myUid(), context.packageName) == AppOpsManager.MODE_ALLOWED
    }

    fun excluded(context: Context): Set<String> {
        val home = context.packageManager.resolveActivity(Intent(Intent.ACTION_MAIN)
            .addCategory(Intent.CATEGORY_HOME), 0)?.activityInfo?.packageName
        return setOfNotNull(context.packageName, home, "android", "com.android.systemui")
    }

    fun read(context: Context, now: Long = System.currentTimeMillis()): UsageSnapshot {
        check(allowed(context)) { "Chưa cấp quyền truy cập thời gian sử dụng." }
        val utc = TimeZone.getTimeZone("UTC")
        val calendar = Calendar.getInstance(utc).apply {
            timeInMillis = now; set(Calendar.HOUR_OF_DAY, 0); set(Calendar.MINUTE, 0)
            set(Calendar.SECOND, 0); set(Calendar.MILLISECOND, 0)
        }
        val start = calendar.timeInMillis
        val day = SimpleDateFormat("yyyy-MM-dd", Locale.US).apply { timeZone = utc }.format(calendar.time)
        val events = (context.getSystemService(Context.USAGE_STATS_SERVICE) as UsageStatsManager)
            .queryEvents(start - 86400000L, now)
        val timeline = mutableListOf<ForegroundEvent>()
        val event = UsageEvents.Event()
        while (events.hasNextEvent()) {
            events.getNextEvent(event)
            if (event.eventType in setOf(1, 2, 16, 26))
                timeline.add(ForegroundEvent(event.timeStamp, event.packageName.orEmpty(), event.eventType))
        }
        return UsageSnapshot(day, UsageTimeline.aggregate(timeline, start, now, excluded(context)))
    }
}
