package com.wren.ide.core.network

import android.content.Context
import com.wren.ide.BuildConfig
import android.net.Uri
import androidx.browser.customtabs.CustomTabsIntent
import androidx.core.net.toUri
import com.google.gson.Gson

object OAuthLauncher {
    private val BACKEND_ORIGIN = BuildConfig.API_BASE_URL.removeSuffix("/api")

    fun launchGithubLogin(context: Context) {
        launch(context, "$BACKEND_ORIGIN/api/auth/github")
    }

    private fun launch(context: Context, url: String) {
        val customTabsIntent = CustomTabsIntent.Builder()
            .setShowTitle(true)
            .build()
        customTabsIntent.launchUrl(context, url.toUri())
    }

    fun parseAuthDeepLink(uri: Uri?): AuthDeepLinkResult? {
        if (uri == null) return null
        if (uri.host != "auth" || (uri.scheme != "wren" && uri.scheme != "numination")) return null

        val token = uri.getQueryParameter("token") ?: return null
        val email = uri.getQueryParameter("email")
        val name = uri.getQueryParameter("name")
        val provider = uri.getQueryParameter("provider") ?: "google"

        return AuthDeepLinkResult(
            token = token,
            email = email,
            name = name,
            provider = provider
        )
    }
}

data class AuthDeepLinkResult(
    val token: String,
    val email: String?,
    val name: String?,
    val provider: String
)

private data class JwtPayload(
    val sub: String? = null,
    val email: String? = null,
    val role: String? = null,
    val tier: String? = null
)

fun decodeJwtPayloadOrNull(token: String): JwtPayloadInfo? {
    return try {
        val parts = token.split(".")
        if (parts.size != 3) return null
        val decoded = android.util.Base64.decode(
            parts[1].replace('-', '+').replace('_', '/'),
            android.util.Base64.DEFAULT
        )
        val json = String(decoded, Charsets.UTF_8)
        val parsed = Gson().fromJson(json, JwtPayload::class.java)
        JwtPayloadInfo(
            role = parsed.role ?: "USER",
            tier = parsed.tier ?: "FREE"
        )
    } catch (_: Throwable) {
        null
    }
}

data class JwtPayloadInfo(val role: String, val tier: String)
