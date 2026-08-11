package com.wren.ide.data.auth

import android.content.Context
import androidx.credentials.CredentialManager
import androidx.credentials.CustomCredential
import androidx.credentials.GetCredentialRequest
import com.google.android.libraries.identity.googleid.GetSignInWithGoogleOption
import com.google.android.libraries.identity.googleid.GoogleIdTokenCredential
import com.wren.ide.R
import com.wren.ide.data.supabase.WrenSupabase
import io.github.jan.supabase.auth.OtpType
import io.github.jan.supabase.auth.SessionStatus
import io.github.jan.supabase.auth.auth
import io.github.jan.supabase.auth.providers.Github
import io.github.jan.supabase.auth.providers.Google
import io.github.jan.supabase.auth.providers.builtin.IDToken
import io.github.jan.supabase.auth.providers.builtin.OTP
import io.github.jan.supabase.auth.user.UserInfo
import kotlinx.coroutines.flow.StateFlow
import java.security.MessageDigest
import java.security.SecureRandom

/**
 * Unico punto de contacto con Supabase Auth. La UI (AuthScreen,
 * EnterCodeEmailScreen) y MainActivity nunca llaman a WrenSupabase.client
 * directamente -- todo pasa por aqui o por AuthViewModel.
 *
 * signInWithGoogle usa Credential Manager para obtener el ID token de Google
 * y lo entrega a supabase.auth.signInWith(IDToken). Supabase valida el token
 * contra el proveedor Google configurado; el backend propio no participa en
 * la verificacion de Google.
 */
class AuthRepository(private val context: Context) {

    private val auth get() = WrenSupabase.client.auth

    /** Estado de sesion observable -- Authenticated/NotAuthenticated/Initializing/RefreshFailure. */
    val sessionStatus: StateFlow<SessionStatus> = auth.sessionStatus

    suspend fun signInWithGoogle() {
        val webClientId = context.getString(R.string.default_web_client_id)
        val rawNonce = generateRawNonce()
        val hashedNonce = sha256Hex(rawNonce)

        // A Google se le manda el nonce hasheado (SHA-256, hex); a Supabase
        // se le manda el nonce crudo -- Supabase Auth hashea internamente lo
        // que recibe de vuelta en el ID token y lo compara contra este.
        val option = GetSignInWithGoogleOption.Builder(webClientId)
            .setNonce(hashedNonce)
            .build()
        val request = GetCredentialRequest.Builder()
            .addCredentialOption(option)
            .build()

        val credentialManager = CredentialManager.create(context)
        val result = credentialManager.getCredential(context = context, request = request)

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

    /**
     * Opens GitHub in a Custom Tab (configured in WrenSupabase) and returns
     * through numination://auth. MainActivity forwards those intents to
     * Supabase via handleDeeplinks(intent).
     */
    suspend fun signInWithGithub() {
        auth.signInWith(Github)
    }

    /** Envia un magic link por correo -- Supabase reemplaza el envio propio via Resend. */
    suspend fun signInWithEmailOtp(email: String) {
        auth.signInWith(OTP) {
            this.email = email
        }
    }

    /** Fallback por si en algun momento se usa un codigo de 6 digitos en vez del link. */
    suspend fun verifyEmailOtp(email: String, code: String) {
        auth.verifyEmailOtp(type = OtpType.Email.EMAIL, email = email, token = code)
    }

    suspend fun signOut() {
        auth.signOut()
    }

    fun getCurrentUser(): UserInfo? = auth.currentUserOrNull()

    /** Access token de la sesion Supabase actual -- este es el que se manda
     * como Bearer al backend propio (/credits, /projects, /owner, /ai/*),
     * en vez del JWT que antes firmaba lib/jwt.ts. */
    fun getCurrentAccessToken(): String? = auth.currentSessionOrNull()?.accessToken

    private fun generateRawNonce(): String {
        val bytes = ByteArray(32)
        SecureRandom().nextBytes(bytes)
        return bytes.joinToString("") { "%02x".format(it) }
    }

    private fun sha256Hex(value: String): String {
        val digest = MessageDigest.getInstance("SHA-256").digest(value.toByteArray())
        return digest.joinToString("") { "%02x".format(it) }
    }
}
