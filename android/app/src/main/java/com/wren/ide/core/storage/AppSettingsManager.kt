package com.wren.ide.core.storage

import android.content.Context
import android.content.SharedPreferences

enum class AppLanguage(val code: String, val label: String) {
    SYSTEM("system", "System"),
    ENGLISH("en", "English"),
    ESPANOL("es", "Español"),
    RUSSIAN("ru", "Русский"),
    CHINESE("zh", "中文"),
    GERMAN("de", "Deutsch");

    companion object {
        fun fromCode(code: String?): AppLanguage {
            return entries.firstOrNull { it.code == code } ?: SYSTEM
        }
    }
}

class AppSettingsManager(context: Context) {
    private val prefs: SharedPreferences = context.getSharedPreferences(PREFS_NAME, Context.MODE_PRIVATE)

    var autoUpdateEnabled: Boolean
        get() = prefs.getBoolean(KEY_AUTO_UPDATE_ENABLED, true)
        set(value) = prefs.edit().putBoolean(KEY_AUTO_UPDATE_ENABLED, value).apply()

    var preferredLanguage: String
        get() = prefs.getString(KEY_LANGUAGE, AppLanguage.SYSTEM.code) ?: AppLanguage.SYSTEM.code
        set(value) = prefs.edit().putString(KEY_LANGUAGE, value).apply()

    companion object {
        private const val PREFS_NAME = "numination_settings"
        private const val KEY_AUTO_UPDATE_ENABLED = "auto_update_enabled"
        private const val KEY_LANGUAGE = "preferred_language"
    }
}
