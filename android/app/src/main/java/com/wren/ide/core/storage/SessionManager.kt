package com.wren.ide.core.storage

import android.content.Context
import android.content.SharedPreferences

/**
 * Local cache of the authenticated Supabase session/profile used by the UI
 * and NetworkClient. Supabase remains the source of truth for the session.
 * Version 2 deliberately uses a new preferences namespace so old Numination
 * access tokens from the pre-Supabase auth system are never reused.
 */
class SessionManager(context: Context) {
    private val prefs: SharedPreferences =
        context.getSharedPreferences(PREFS_NAME, Context.MODE_PRIVATE)

    companion object {
        private const val PREFS_NAME = "numination_secure_preferences_v2"
        private const val KEY_ACCESS_TOKEN = "access_token"
        private const val KEY_USER_EMAIL = "user_email"
        private const val KEY_USER_ROLE = "user_role"
        private const val KEY_USER_TIER = "user_tier"
        private const val KEY_USER_CREDITS = "user_credits"
        private const val KEY_ACTIVE_PROJECT_ID = "active_project_id"
    }

    var accessToken: String?
        get() = prefs.getString(KEY_ACCESS_TOKEN, null)
        set(value) {
            prefs.edit().putString(KEY_ACCESS_TOKEN, value).apply()
        }

    var userEmail: String?
        get() = prefs.getString(KEY_USER_EMAIL, null)
        set(value) {
            prefs.edit().putString(KEY_USER_EMAIL, value).apply()
        }

    var userRole: String?
        get() = prefs.getString(KEY_USER_ROLE, "USER")
        set(value) {
            prefs.edit().putString(KEY_USER_ROLE, value ?: "USER").apply()
        }

    var userTier: String?
        get() = prefs.getString(KEY_USER_TIER, "FREE")
        set(value) {
            prefs.edit().putString(KEY_USER_TIER, value ?: "FREE").apply()
        }

    var userCredits: Int
        get() = prefs.getInt(KEY_USER_CREDITS, 0)
        set(value) {
            prefs.edit().putInt(KEY_USER_CREDITS, value).apply()
        }

    var activeProjectId: String?
        get() = prefs.getString(KEY_ACTIVE_PROJECT_ID, null)
        set(value) {
            prefs.edit().putString(KEY_ACTIVE_PROJECT_ID, value).apply()
        }

    val isLoggedIn: Boolean
        get() = accessToken != null

    fun clearSession() {
        prefs.edit().clear().apply()
    }
}
