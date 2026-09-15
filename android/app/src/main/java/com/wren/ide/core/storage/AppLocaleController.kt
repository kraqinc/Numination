package com.wren.ide.core.storage

import android.content.Context
import androidx.appcompat.app.AppCompatDelegate
import androidx.core.os.LocaleListCompat

object AppLocaleController {
    fun applyStoredLanguage(context: Context) {
        val settings = AppSettingsManager(context)
        applyLanguage(settings.preferredLanguage)
    }

    fun applyLanguage(languageCode: String) {
        val locales = when (languageCode) {
            AppLanguage.SYSTEM.code -> LocaleListCompat.getEmptyLocaleList()
            else -> LocaleListCompat.forLanguageTags(languageCode)
        }
        AppCompatDelegate.setApplicationLocales(locales)
    }
}
