package com.wren.ide.core.network

import android.content.Context
import com.wren.ide.BuildConfig
import org.json.JSONObject
import java.io.IOException

object BackendConfig {
    private const val CONFIG_FILE = "backend_config.json"

    @Volatile
    private var cachedApiBaseUrl: String? = null

    fun initialize(context: Context) {
        if (cachedApiBaseUrl != null) return
        synchronized(this) {
            if (cachedApiBaseUrl != null) return
            cachedApiBaseUrl = readApiBaseUrl(context.applicationContext) ?: BuildConfig.API_BASE_URL
        }
    }

    fun apiBaseUrl(): String = cachedApiBaseUrl ?: BuildConfig.API_BASE_URL

    fun apiOrigin(): String = apiBaseUrl().removeSuffix("/api").trimEnd('/')

    private fun readApiBaseUrl(context: Context): String? {
        return try {
            val json = context.assets.open(CONFIG_FILE).bufferedReader().use { it.readText() }
            val parsed = JSONObject(json)

            sequenceOf("apiBaseUrl", "baseUrl", "backendUrl", "url")
                .mapNotNull { key -> parsed.optString(key).trim().takeIf { it.isNotBlank() } }
                .firstOrNull()
                ?.trimEnd('/')
        } catch (_: IOException) {
            null
        } catch (_: Throwable) {
            null
        }
    }
}
