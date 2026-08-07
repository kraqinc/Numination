package com.wren.ide.core.network

import com.google.gson.Gson
import com.wren.ide.core.storage.SessionManager

object AuthSessionHelper {

    fun parseLoginResponse(body: String): LoginResponse? {
        if (body.isBlank()) return null

        return runCatching {
            val json = Gson().fromJson(body, Map::class.java) ?: return null
            val token = json["token"] as? String ?: return null
            if (token.isBlank()) return null

            @Suppress("UNCHECKED_CAST")
            val userMap = json["user"] as? Map<String, Any?> ?: return null

            LoginResponse(
                message = json["message"] as? String ?: "",
                token = token,
                user = User(
                    id = userMap["id"]?.toString().orEmpty(),
                    email = userMap["email"]?.toString().orEmpty(),
                    role = userMap["role"]?.toString() ?: "USER",
                    tier = userMap["tier"]?.toString() ?: "FREE",
                    balance = parseBalance(userMap["balance"])
                )
            )
        }.getOrNull()
    }

    fun parseErrorMessage(body: String, fallback: String): String {
        return runCatching {
            val json = Gson().fromJson(body, Map::class.java)
            (json["error"] as? String)?.takeIf { it.isNotBlank() }
                ?: (json["message"] as? String)?.takeIf { it.isNotBlank() }
        }.getOrNull() ?: fallback
    }

    fun applySession(sessionManager: SessionManager, loginResponse: LoginResponse) {
        sessionManager.jwtToken = loginResponse.token
        sessionManager.userEmail = loginResponse.user.email
        sessionManager.userRole = loginResponse.user.role
        sessionManager.userTier = loginResponse.user.tier
        sessionManager.userCredits = loginResponse.user.balance
        NetworkClient.setAuthToken(loginResponse.token)
    }

    private fun parseBalance(value: Any?): Int {
        return when (value) {
            is Number -> value.toInt()
            is String -> value.toIntOrNull() ?: 0
            else -> 0
        }
    }
}
