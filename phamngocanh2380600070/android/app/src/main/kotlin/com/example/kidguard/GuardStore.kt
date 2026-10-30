package com.example.kidguard

import android.content.Context
import android.security.keystore.KeyGenParameterSpec
import android.security.keystore.KeyProperties
import android.util.Base64
import org.json.JSONObject
import java.security.KeyStore
import javax.crypto.Cipher
import javax.crypto.KeyGenerator
import javax.crypto.SecretKey
import javax.crypto.spec.GCMParameterSpec

/** Device enrollment remains separate from the signed-in Flutter UI session. */
class GuardStore(context: Context) {
    private val prefs = context.getSharedPreferences("kidguard_monitor", Context.MODE_PRIVATE)
    private fun key(): SecretKey {
        val store = KeyStore.getInstance("AndroidKeyStore").apply { load(null) }
        (store.getKey("kidguard_monitor", null) as? SecretKey)?.let { return it }
        return KeyGenerator.getInstance(KeyProperties.KEY_ALGORITHM_AES, "AndroidKeyStore").apply {
            init(KeyGenParameterSpec.Builder("kidguard_monitor",
                KeyProperties.PURPOSE_ENCRYPT or KeyProperties.PURPOSE_DECRYPT)
                .setBlockModes(KeyProperties.BLOCK_MODE_GCM)
                .setEncryptionPaddings(KeyProperties.ENCRYPTION_PADDING_NONE).build())
        }.generateKey()
    }
    @Synchronized fun credentials(): JSONObject? = try {
        val encoded = prefs.getString("credentials", null)
        if (encoded == null) null else {
            val bytes = Base64.decode(encoded, Base64.NO_WRAP)
            val cipher = Cipher.getInstance("AES/GCM/NoPadding")
            cipher.init(Cipher.DECRYPT_MODE, key(), GCMParameterSpec(128, bytes.copyOfRange(0, 12)))
            JSONObject(String(cipher.doFinal(bytes.copyOfRange(12, bytes.size)), Charsets.UTF_8))
        }
    } catch (_: Exception) { null }

    @Synchronized fun saveCredentials(data: JSONObject) {
        val cipher = Cipher.getInstance("AES/GCM/NoPadding")
        cipher.init(Cipher.ENCRYPT_MODE, key())
        val bytes = cipher.iv + cipher.doFinal(data.toString().toByteArray(Charsets.UTF_8))
        prefs.edit().putString("credentials", Base64.encodeToString(bytes, Base64.NO_WRAP)).apply()
    }
    var enabled: Boolean
        get() = prefs.getBoolean("enabled", false)
        set(value) { prefs.edit().putBoolean("enabled", value).apply() }
    var networkPaused: Boolean
        get() = prefs.getBoolean("network_paused", false)
        set(value) { prefs.edit().putBoolean("network_paused", value).apply() }
    var rules: String
        get() = prefs.getString("rules", "{}") ?: "{}"
        set(value) { prefs.edit().putString("rules", value).apply() }
    var lastSync: Long
        get() = prefs.getLong("last_sync", 0)
        set(value) { prefs.edit().putLong("last_sync", value).apply() }
    var error: String
        get() = prefs.getString("error", "") ?: ""
        set(value) { prefs.edit().putString("error", value).apply() }
}
