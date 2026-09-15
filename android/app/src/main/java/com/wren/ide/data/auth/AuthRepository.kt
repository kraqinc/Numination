package com.wren.ide.data.auth

import android.app.Activity
import android.content.Context
import androidx.credentials.CredentialManager
import androidx.credentials.CustomCredential
import androidx.credentials.GetCredentialRequest
import com.google.android.libraries.identity.googleid.GetSignInWithGoogleOption
import com.google.android.libraries.identity.googleid.GoogleIdTokenCredential
import com.wren.ide.BuildConfig
import com.wren.ide.data.supabase.WrenSupabase
import io.github.jan.supabase.auth.OtpType
import io.github.jan.supabase.auth.auth
import io.github.jan.supabase.auth.providers.Github
import io.github.jan.supabase.auth.providers.Google
import io.github.jan.supabase.auth.providers.builtin.IDToken
import io.github.jan.supabase.auth.providers.builtin.OTP
import io.github.jan.supabase.auth.status.SessionStatus
import io.github.jan.supabase.auth.user.UserInfo
import kotlinx.coroutines.flow.StateFlow
import java.security.MessageDigest
import java.security.SecureRandom

class AuthRepository(private val context: Context) {

    private val auth get() = WrenSupabase.client.auth

    val sessionStatus: StateFlow<SessionStatus> = auth.sessionStatus

    suspend fun signInWithGoogle(activity: Activity) {
        val webClientId = BuildConfig.SUPABASE_AUTH_GOOGLE_CLIENT_ID
        val rawNonce = generateRawNonce()
        val hashedNonce = sha256Hex(rawNonce)

        val option = GetSignInWithGoogleOption.Builder(webClientId)
            .setNonce(hashedNonce)
            .build()

        val request = GetCredentialRequest.Builder()
            .addCredentialOption(option)
            .build()

        val credentialManager = CredentialManager.create(activity)

        val result = credentialManager.getCredential(
            context = activity,
            request = request
        )

        val credential = result.credential

        val idToken = if (
            credential is CustomCredential &&
            credential.type == GoogleIdTokenCredential.TYPE_GOOGLE_ID_TOKEN_CREDENTIAL
        ) {
            GoogleIdTokenCredential.createFrom(credential.data).idToken
        } else {
            null
        } ?: throw IllegalStateException("Google no devolvio ID token")

        auth.signInWith(IDToken) {
            this.idToken = idToken
            this.provider = Google
            this.nonce = rawNonce
        }
    }

    suspend fun signInWithGithub() {
        auth.signInWith(Github)
    }

    suspend fun signInWithEmailOtp(email: String) {
        auth.signInWith(
            OTP,
            redirectUrl = "numination://auth/callback"
        ) {
            this.email = email
        }
    }

    suspend fun verifyEmailOtp(email: String, code: String) {
        auth.verifyEmailOtp(
            type = OtpType.Email.EMAIL,
            email = email,
            token = code
        )
    }

    suspend fun signOut() {
        auth.signOut()
    }

    fun getCurrentUser(): UserInfo? =
        auth.currentUserOrNull()

    fun getCurrentAccessToken(): String? =
        auth.currentSessionOrNull()?.accessToken

    private fun generateRawNonce(): String {
        val bytes = ByteArray(32)
        SecureRandom().nextBytes(bytes)
        return bytes.joinToString("") { "%02x".format(it) }
    }

    private fun sha256Hex(value: String): String {
        val digest = MessageDigest
            .getInstance("SHA-256")
            .digest(value.toByteArray())

        return digest.joinToString("") {
            "%02x".format(it)
        }
    }
}
