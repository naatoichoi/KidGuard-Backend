package com.example.kidguard

import android.accessibilityservice.AccessibilityService
import android.app.KeyguardManager
import android.app.Notification
import android.app.NotificationChannel
import android.app.NotificationManager
import android.app.PendingIntent
import android.app.admin.DevicePolicyManager
import android.content.ComponentName
import android.content.Context
import android.content.Intent
import android.graphics.Color
import android.graphics.PixelFormat
import android.os.Handler
import android.os.Looper
import android.view.Gravity
import android.view.View
import android.view.WindowManager
import android.view.accessibility.AccessibilityEvent
import android.widget.Button
import android.widget.LinearLayout
import android.widget.TextView
import org.json.JSONObject
import java.util.concurrent.Executors
import java.util.concurrent.TimeUnit

class GuardAccessibilityService : AccessibilityService() {
    private val main = Handler(Looper.getMainLooper())
    private val workers = Executors.newScheduledThreadPool(2)
    private lateinit var store: GuardStore
    @Volatile private var foreground = ""
    private var overlay: View? = null
    private var overlayKey = ""
    private var lastLock = 0L

    override fun onServiceConnected() {
        store = GuardStore(this)
        workers.scheduleWithFixedDelay({
            try { evaluate() } catch (error: Exception) {
                store.error = error.message ?: "Không đọc được thời gian sử dụng."
            }
        }, 0, 3, TimeUnit.SECONDS)
        workers.scheduleWithFixedDelay({
            try { GuardApi(this).sync() } catch (error: Exception) {
                store.error = error.message ?: "Mất kết nối; đang dùng giới hạn đã lưu."
            }
        }, 0, 30, TimeUnit.SECONDS)
    }

    override fun onAccessibilityEvent(event: AccessibilityEvent?) {
        if (event?.eventType != AccessibilityEvent.TYPE_WINDOW_STATE_CHANGED) return
        val pkg = event.packageName?.toString() ?: return
        // Overlay belongs to our process; only actual Flutter activity events clear the foreground app.
        if (pkg == packageName && event.className?.toString() != MainActivity::class.java.name) return
        foreground = pkg
        if (pkg == packageName || pkg in safetyPackages()) hideOverlay()
    }

    private fun safetyPackages(): Set<String> {
        val dialer = (getSystemService(Context.TELECOM_SERVICE) as? android.telecom.TelecomManager)?.defaultDialerPackage
        return setOfNotNull(packageName, "android", "com.android.systemui", "com.android.settings",
            "com.android.emergency", "com.android.phone", "com.android.server.telecom", dialer)
    }

    private fun evaluate() {
        if (!store.enabled || store.credentials() == null || !UsageReader.allowed(this)) {
            main.post { hideOverlay() }; return
        }
        val snapshot = UsageReader.read(this)
        showMonitorNotification()
        val data = JSONObject(store.rules)
        val rules = data.optJSONArray("limits") ?: return
        val day = data.optString("usageDate")
        var totalBlocked = false
        var appBlocked = false
        val pkg = foreground
        for (index in 0 until rules.length()) {
            val row = rules.getJSONObject(index)
            val type = row.optString("limitType")
            val target = row.optString("packageName")
            val rule = GuardRule(type, target, row.optLong("dailyLimitMinutes"), row.optLong("extraMinutes"), day)
            if (type == "TOTAL" && GuardRules.exceeded(rule, snapshot.date, snapshot.seconds)) totalBlocked = true
            if (type == "APP" && target == pkg && GuardRules.exceeded(rule, snapshot.date, snapshot.seconds)) appBlocked = true
        }
        main.post {
            if (foreground != pkg) return@post
            val keyguard = getSystemService(Context.KEYGUARD_SERVICE) as KeyguardManager
            if (keyguard.isKeyguardLocked || pkg in safetyPackages() || pkg.isBlank()) { hideOverlay(); return@post }
            if (totalBlocked) {
                val policy = getSystemService(Context.DEVICE_POLICY_SERVICE) as DevicePolicyManager
                val admin = ComponentName(this, GuardAdminReceiver::class.java)
                if (policy.isAdminActive(admin) && System.currentTimeMillis() - lastLock > 3000) {
                    hideOverlay()
                    try { policy.lockNow(); lastLock = System.currentTimeMillis() }
                    catch (_: SecurityException) { showOverlay("TOTAL", "Đã hết thời gian điện thoại hôm nay.") }
                } else { showOverlay("TOTAL", "Đã hết thời gian điện thoại hôm nay.") }
            } else if (appBlocked) {
                showOverlay(pkg, "Ứng dụng này đã hết thời gian hôm nay. Các ứng dụng khác vẫn dùng được.")
            } else { hideOverlay() }
        }
    }

    @Suppress("DEPRECATION")
    private fun showMonitorNotification() {
        if (android.os.Build.VERSION.SDK_INT >= 33 &&
            checkSelfPermission(android.Manifest.permission.POST_NOTIFICATIONS) != android.content.pm.PackageManager.PERMISSION_GRANTED) return
        val manager = getSystemService(Context.NOTIFICATION_SERVICE) as NotificationManager
        if (android.os.Build.VERSION.SDK_INT >= 26)
            manager.createNotificationChannel(NotificationChannel("kidguard_monitor", "Theo dõi thời gian", NotificationManager.IMPORTANCE_LOW))
        val open = PendingIntent.getActivity(this, 0, Intent(this, MainActivity::class.java),
            PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE)
        val builder = if (android.os.Build.VERSION.SDK_INT >= 26) Notification.Builder(this, "kidguard_monitor") else Notification.Builder(this)
        manager.notify(301, builder.setSmallIcon(android.R.drawable.ic_lock_lock)
            .setContentTitle("KidGuard đang áp dụng giới hạn của phụ huynh")
            .setContentText("Chạm để mở KidGuard hoặc xin thêm giờ.")
            .setContentIntent(open).setOngoing(true).setOnlyAlertOnce(true).build())
    }

    private fun showOverlay(key: String, message: String) {
        if (overlay != null && overlayKey == key) return
        hideOverlay()
        val layout = LinearLayout(this).apply {
            orientation = LinearLayout.VERTICAL; gravity = Gravity.CENTER
            setPadding(48, 48, 48, 48); setBackgroundColor(Color.rgb(246, 245, 255))
            addView(TextView(context).apply {
                text = "Đến giờ nghỉ rồi"; textSize = 28f; setTextColor(Color.rgb(67, 49, 142)); gravity = Gravity.CENTER
            })
            addView(TextView(context).apply { text = message; textSize = 18f; gravity = Gravity.CENTER; setPadding(0, 24, 0, 24) })
            addView(Button(context).apply {
                text = "Về màn hình chính"
                setOnClickListener { performGlobalAction(GLOBAL_ACTION_HOME); hideOverlay() }
            })
            addView(Button(context).apply {
                text = "Mở KidGuard / Xin thêm giờ"
                setOnClickListener {
                    startActivity(Intent(context, MainActivity::class.java).addFlags(Intent.FLAG_ACTIVITY_NEW_TASK or Intent.FLAG_ACTIVITY_SINGLE_TOP))
                    hideOverlay()
                }
            })
        }
        try {
            (getSystemService(Context.WINDOW_SERVICE) as WindowManager).addView(layout,
                WindowManager.LayoutParams(WindowManager.LayoutParams.MATCH_PARENT, WindowManager.LayoutParams.MATCH_PARENT,
                    WindowManager.LayoutParams.TYPE_ACCESSIBILITY_OVERLAY,
                    WindowManager.LayoutParams.FLAG_NOT_FOCUSABLE, PixelFormat.OPAQUE))
            overlay = layout; overlayKey = key
        } catch (_: Exception) { store.error = "Không hiển thị được màn hình chặn ứng dụng." }
    }

    private fun hideOverlay() {
        overlay?.let { try { (getSystemService(Context.WINDOW_SERVICE) as WindowManager).removeView(it) } catch (_: Exception) {} }
        overlay = null; overlayKey = ""
    }

    override fun onInterrupt() { hideOverlay() }
    override fun onDestroy() {
        workers.shutdownNow(); hideOverlay()
        (getSystemService(Context.NOTIFICATION_SERVICE) as NotificationManager).cancel(301)
        super.onDestroy()
    }
}
