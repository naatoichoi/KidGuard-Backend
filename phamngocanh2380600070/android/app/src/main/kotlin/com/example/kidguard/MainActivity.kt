package com.example.kidguard

import io.flutter.embedding.android.FlutterFragmentActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.EventChannel
import android.content.Context
import android.hardware.Sensor
import android.hardware.SensorEvent
import android.hardware.SensorEventListener
import android.hardware.SensorManager
import android.app.admin.DevicePolicyManager
import android.content.ComponentName
import android.content.Intent
import android.provider.Settings
import io.flutter.plugin.common.MethodChannel
import org.json.JSONObject
import java.util.concurrent.Executors
import android.location.Geocoder
import java.util.Locale

class MainActivity : FlutterFragmentActivity(), SensorEventListener {
    private var sink: EventChannel.EventSink? = null
    private val sensors by lazy { getSystemService(Context.SENSOR_SERVICE) as SensorManager }
    private val io = Executors.newSingleThreadExecutor()
    private val locationIo = Executors.newSingleThreadExecutor()
    private fun isEmulator(): Boolean = android.os.Build.MODEL.contains("sdk_gphone") ||
        android.os.Build.HARDWARE.contains("ranchu") || android.os.Build.HARDWARE.contains("goldfish")

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, "kidguard/guard")
            .setMethodCallHandler { call, result ->
                val store = GuardStore(this)
                when (call.method) {
                    "pauseNetwork" -> { store.networkPaused = true; result.success(null) }
                    "mapAttribution" -> {
                        startActivity(Intent(Intent.ACTION_VIEW, android.net.Uri.parse("https://www.openstreetmap.org/copyright")))
                        result.success(null)
                    }
                    "reverseGeocode" -> locationIo.execute {
                        val address = try {
                            val latitude = call.argument<Number>("latitude")!!.toDouble()
                            val longitude = call.argument<Number>("longitude")!!.toDouble()
                            require(latitude.isFinite() && longitude.isFinite() && latitude in -90.0..90.0 && longitude in -180.0..180.0)
                            @Suppress("DEPRECATION")
                            if (Geocoder.isPresent()) Geocoder(this, Locale.forLanguageTag("vi-VN"))
                                .getFromLocation(latitude, longitude, 1)?.firstOrNull()?.getAddressLine(0) else null
                        } catch (_: Exception) { null }
                        runOnUiThread { result.success(address) }
                    }
                    "status" -> {
                        val component = ComponentName(this, GuardAccessibilityService::class.java)
                        val enabledServices = Settings.Secure.getString(contentResolver,
                            Settings.Secure.ENABLED_ACCESSIBILITY_SERVICES).orEmpty().split(':')
                        val policy = getSystemService(Context.DEVICE_POLICY_SERVICE) as DevicePolicyManager
                        result.success(mapOf("usageAccess" to UsageReader.allowed(this),
                            "accessibility" to enabledServices.any { ComponentName.unflattenFromString(it) == component },
                            "deviceAdmin" to policy.isAdminActive(ComponentName(this, GuardAdminReceiver::class.java)),
                            "enabled" to store.enabled, "enrolled" to (store.credentials() != null), "emulator" to isEmulator(),
                            "lastSync" to store.lastSync, "error" to store.error))
                    }
                    "configure" -> {
                        try {
                            val args = JSONObject(call.arguments as Map<*, *>)
                            val old = store.credentials()
                            if (old?.optInt("deviceId") != args.optInt("deviceId") ||
                                old?.optString("identifier") != args.optString("identifier")) {
                                store.rules = "{}"; store.lastSync = 0; store.enabled = false
                            }
                            store.saveCredentials(args)
                            store.networkPaused = false
                            result.success(null)
                        } catch (_: Exception) { result.error("CONFIG", "Không lưu được thông tin giám sát.", null) }
                    }
                    "enable" -> {
                        store.enabled = call.argument<Boolean>("enabled") == true
                        result.success(null)
                    }
                    "usageSnapshot", "sync" -> io.execute {
                        try {
                            val data = if (call.method == "usageSnapshot") UsageReader.read(this).flutter(this)
                                else { GuardApi(this).sync(); null }
                            runOnUiThread { result.success(data) }
                        } catch (error: Exception) {
                            runOnUiThread { result.error("USAGE", error.message, null) }
                        }
                    }
                    "usageSettings" -> { startActivity(Intent(Settings.ACTION_USAGE_ACCESS_SETTINGS)); result.success(null) }
                    "accessibilitySettings" -> { startActivity(Intent(Settings.ACTION_ACCESSIBILITY_SETTINGS)); result.success(null) }
                    "adminSettings" -> {
                        startActivity(Intent(DevicePolicyManager.ACTION_ADD_DEVICE_ADMIN)
                            .putExtra(DevicePolicyManager.EXTRA_DEVICE_ADMIN, ComponentName(this, GuardAdminReceiver::class.java))
                            .putExtra(DevicePolicyManager.EXTRA_ADD_EXPLANATION, "Cho phép KidGuard khóa màn hình khi hết thời gian phụ huynh đặt."))
                        result.success(null)
                    }
                    else -> result.notImplemented()
                }
            }
        EventChannel(flutterEngine.dartExecutor.binaryMessenger, "kidguard/motion")
            .setStreamHandler(object : EventChannel.StreamHandler {
                override fun onListen(arguments: Any?, events: EventChannel.EventSink) {
                    val sensor = sensors.getDefaultSensor(Sensor.TYPE_LINEAR_ACCELERATION)
                    if (sensor == null) {
                        events.error("UNAVAILABLE", "Thiết bị không có cảm biến gia tốc tuyến tính.", null)
                        return
                    }
                    sink = events
                    if (!sensors.registerListener(this@MainActivity, sensor, 100000)) {
                        sink = null
                        events.error("UNAVAILABLE", "Không thể bật cảm biến chuyển động.", null)
                    }
                }
                override fun onCancel(arguments: Any?) {
                    sensors.unregisterListener(this@MainActivity)
                    sink = null
                }
            })
    }

    override fun onSensorChanged(event: SensorEvent) {
        sink?.success(event.values.take(3).map { it.toDouble() })
    }

    override fun onAccuracyChanged(sensor: Sensor?, accuracy: Int) {}

    override fun onDestroy() {
        sensors.unregisterListener(this)
        io.shutdownNow()
        locationIo.shutdownNow()
        sink = null
        super.onDestroy()
    }
}
