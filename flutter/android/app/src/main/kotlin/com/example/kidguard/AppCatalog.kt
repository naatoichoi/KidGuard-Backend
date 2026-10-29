package com.example.kidguard

import android.content.Context
import android.content.Intent

object AppCatalog {
    fun labels(context: Context): Map<String, String> {
        val excluded = UsageReader.excluded(context)
        @Suppress("DEPRECATION")
        val activities = context.packageManager.queryIntentActivities(
            Intent(Intent.ACTION_MAIN).addCategory(Intent.CATEGORY_LAUNCHER), 0)
        return activities.mapNotNull { info ->
            val pkg = info.activityInfo?.packageName ?: return@mapNotNull null
            if (pkg in excluded) return@mapNotNull null
            val label = info.activityInfo.applicationInfo.loadLabel(context.packageManager).toString()
            pkg to label.ifBlank { pkg }.take(150)
        }.toMap()
    }
}
