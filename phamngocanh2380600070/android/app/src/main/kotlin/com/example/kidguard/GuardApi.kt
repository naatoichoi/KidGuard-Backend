package com.example.kidguard

import android.content.Context
import org.json.JSONArray
import org.json.JSONObject
import java.net.HttpURLConnection
import java.net.URI

/** Short timeouts; enforcement runs independently of this network worker. */
class GuardApi(private val context: Context) {
    private val store = GuardStore(context)
    private fun request(credentials: JSONObject, path: String, body: JSONObject? = null,
                        authenticated: Boolean = true): Pair<Int, JSONObject> {
        val base = URI(credentials.getString("baseUrl"))
        require(base.scheme == "https" && !base.host.isNullOrEmpty())
        val connection = URI(base.toString().trimEnd('/') + "/" + path).toURL().openConnection() as HttpURLConnection
        return try {
            connection.connectTimeout = 5000; connection.readTimeout = 5000
            connection.instanceFollowRedirects = false
            connection.requestMethod = if (body == null) "GET" else "POST"
            connection.setRequestProperty("Accept", "application/json")
            if (authenticated) connection.setRequestProperty("Authorization", "Bearer ${credentials.getString("token")}")
            if (body != null) {
                connection.doOutput = true
                connection.setRequestProperty("Content-Type", "application/json; charset=utf-8")
                connection.outputStream.use { it.write(body.toString().toByteArray(Charsets.UTF_8)) }
            }
            val status = connection.responseCode
            val stream = if (status in 200..299) connection.inputStream else connection.errorStream
            val text = stream?.bufferedReader()?.use { it.readText() }.orEmpty()
            status to if (text.isBlank()) JSONObject() else JSONObject(text)
        } finally { connection.disconnect() }
    }

    @Synchronized fun sync() {
        val credentials = store.credentials() ?: return
        if (!store.enabled || store.networkPaused || !UsageReader.allowed(context)) return
        var result = request(credentials, "ScreenTime/limits/status/${credentials.getInt("deviceId")}")
        if (result.first == 401) {
            if (store.networkPaused) return
            val refreshed = request(credentials, "Pairing/refresh-token", JSONObject()
                .put("deviceIdentifier", credentials.getString("identifier"))
                .put("deviceSecret", credentials.getString("secret")), false)
            check(refreshed.first == 200) { "Phiên thiết bị không hợp lệ; mở KidGuard để đăng nhập lại." }
            credentials.put("token", refreshed.second.getString("token"))
            // Do not restore credentials if the Flutter UI re-enrolled a different device during the request.
            if (store.credentials()?.optString("secret") != credentials.optString("secret")) return
            store.saveCredentials(credentials)
            result = request(credentials, "ScreenTime/limits/status/${credentials.getInt("deviceId")}")
        }
        check(result.first == 200) { "Chưa tải được giới hạn (HTTP ${result.first})." }
        if (store.networkPaused || store.credentials()?.optString("secret") != credentials.optString("secret")) return
        store.rules = result.second.toString()
        val snapshot = UsageReader.read(context).flutter(context)
        val body = JSONObject().put("deviceId", credentials.getInt("deviceId"))
            .put("usageDate", snapshot["usageDate"]).put("apps", JSONArray(snapshot["apps"] as List<*>))
        if ((snapshot["apps"] as List<*>).isNotEmpty()) {
            val synced = request(credentials, "ScreenTime/sync", body)
            check(synced.first in 200..299) { "Chưa đồng bộ thời gian (HTTP ${synced.first})." }
        }
        store.lastSync = System.currentTimeMillis()
        store.error = ""
    }
}
