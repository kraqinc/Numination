package com.wren.ide.core.network

import android.content.Context
import android.net.Uri
import androidx.browser.customtabs.CustomTabsIntent
import androidx.core.net.toUri
import com.google.gson.Gson

object OAuthLauncher {
    private val BACKEND_ORIGIN get() = BackendConfig.apiOrigin()

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

    /** El Magic Link (numination://auth?magic=...&email=...) trae un token
     * opaco, no un JWT -- hay que canjearlo contra el backend en
     * /auth/magic-link/verify antes de confiar en la sesión. Separado de
     * parseAuthDeepLink porque ese devuelve un JWT ya firmado (Google/GitHub),
     * mientras este solo devuelve las piezas crudas para canjear. */
    fun parseMagicLinkDeepLink(uri: Uri?): MagicLinkDeepLinkResult? {
        if (uri == null) return null
        if (uri.host != "auth" || (uri.scheme != "wren" && uri.scheme != "numination")) return null

        val magicToken = uri.getQueryParameter("magic") ?: return null
        val email = uri.getQueryParameter("email") ?: return null

        return MagicLinkDeepLinkResult(magicToken = magicToken, email = email)
    }
}

data class AuthDeepLinkResult(
    val token: String,
    val email: String?,
    val name: String?,
    val provider: String
)

data class MagicLinkDeepLinkResult(
    val magicToken: String,
    val email: String
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
