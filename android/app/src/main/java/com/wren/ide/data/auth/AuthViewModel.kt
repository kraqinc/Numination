package com.wren.ide.data.auth

import android.app.Application
import androidx.credentials.exceptions.GetCredentialCancellationException
import androidx.credentials.exceptions.GetCredentialException
import androidx.credentials.exceptions.NoCredentialException
import androidx.lifecycle.AndroidViewModel
import androidx.lifecycle.ViewModel
import androidx.lifecycle.ViewModelProvider
import androidx.lifecycle.viewModelScope
import com.google.android.libraries.identity.googleid.GoogleIdTokenParsingException
import com.google.gson.Gson
import com.wren.ide.core.network.NetworkClient
import com.wren.ide.core.network.User
import com.wren.ide.core.storage.SessionManager
import io.github.jan.supabase.auth.status.SessionStatus
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.flow.MutableStateFlow
import kotlinx.coroutines.flow.StateFlow
import kotlinx.coroutines.flow.asStateFlow
import kotlinx.coroutines.launch
import kotlinx.coroutines.sync.Mutex
import kotlinx.coroutines.sync.withLock
import kotlinx.coroutines.withContext
import java.io.IOException

sealed class AuthUiState {
    data object Idle : AuthUiState()
    data object Loading : AuthUiState()
    data class Authenticated(val user: User) : AuthUiState()
    data object Unauthenticated : AuthUiState()
    data class Error(val message: String) : AuthUiState()
}

/**
 * Supabase is the source of truth for authentication. This ViewModel only
 * adapts Supabase session state to Numination's local profile cache and the
 * bearer token used by the existing Numination API.
 */
class AuthViewModel(
    application: Application,
    private val sessionManager: SessionManager
) : AndroidViewModel(application) {

    private val repository = AuthRepository(application.applicationContext)
    private val syncMutex = Mutex()
    private var lastToken: String? = null
    private var cachedUser: User? = null

    private val _state = MutableStateFlow<AuthUiState>(AuthUiState.Idle)
    val state: StateFlow<AuthUiState> = _state.asStateFlow()

    init {
        viewModelScope.launch {
            repository.sessionStatus.collect { status ->
                when (status) {
                    is SessionStatus.Authenticated -> syncAuthenticatedSession(forceProfile = false)
                    is SessionStatus.NotAuthenticated, is SessionStatus.RefreshFailure -> {
                        lastToken = null
                        cachedUser = null
                        sessionManager.clearSession()
                        NetworkClient.setAuthToken(null)
                        _state.value = AuthUiState.Unauthenticated
                    }
                    is SessionStatus.Initializing -> Unit
                }
            }
        }
    }

    fun onGoogleLogin() {
        viewModelScope.launch {
            _state.value = AuthUiState.Loading
            try {
                repository.signInWithGoogle()
                syncAuthenticatedSession(forceProfile = true)
            } catch (_: GetCredentialCancellationException) {
                _state.value = AuthUiState.Idle
            } catch (_: NoCredentialException) {
                _state.value = AuthUiState.Error(
                    "No hay ninguna cuenta de Google en este dispositivo"
                )
            } catch (_: GoogleIdTokenParsingException) {
                _state.value = AuthUiState.Error("Google devolvio una respuesta invalida")
            } catch (e: GetCredentialException) {
                _state.value = AuthUiState.Error(
                    readableMessage(e, "No se pudo iniciar sesion con Google")
                )
            } catch (t: Throwable) {
                _state.value = AuthUiState.Error(
                    readableMessage(t, "No se pudo iniciar sesion con Google")
                )
            }
        }
    }

    fun onGithubLogin() {
        viewModelScope.launch {
            _state.value = AuthUiState.Loading
            try {
                repository.signInWithGithub()
                // Supabase will import the callback session through handleDeeplinks.
            } catch (t: Throwable) {
                _state.value = AuthUiState.Error(
                    readableMessage(t, "No se pudo iniciar sesion con GitHub")
                )
            }
        }
    }

    fun onRequestMagicLink(email: String, onSent: () -> Unit = {}) {
        viewModelScope.launch {
            _state.value = AuthUiState.Loading
            try {
                repository.signInWithEmailOtp(email)
                _state.value = AuthUiState.Idle
                onSent()
            } catch (t: Throwable) {
                _state.value = AuthUiState.Error(
                    readableMessage(t, "No se pudo enviar el enlace")
                )
            }
        }
    }

    fun signOut() {
        viewModelScope.launch {
            runCatching { repository.signOut() }
            lastToken = null
            cachedUser = null
            sessionManager.clearSession()
            NetworkClient.setAuthToken(null)
            _state.value = AuthUiState.Unauthenticated
        }
    }

    fun clearError() {
        if (_state.value is AuthUiState.Error) _state.value = AuthUiState.Idle
    }

    private suspend fun syncAuthenticatedSession(forceProfile: Boolean) {
        syncMutex.withLock {
            val token = repository.getCurrentAccessToken()
            if (token.isNullOrBlank()) {
                _state.value = AuthUiState.Error("No se pudo obtener la sesion de Supabase")
                return
            }

            NetworkClient.setAuthToken(token)

            // Token refreshes should update the bearer token without doing a
            // second /auth/me call. A fresh login still refreshes the profile.
            if (!forceProfile && token == lastToken && cachedUser != null) {
                _state.value = AuthUiState.Authenticated(cachedUser!!)
                return
            }

            try {
                val result = withContext(Dispatchers.IO) {
                    NetworkClient.get("/auth/me").use { response ->
                        response.code to response.body?.string().orEmpty()
                    }
                }

                if (result.first !in 200..299) {
                    _state.value = AuthUiState.Error(
                        "No se pudo cargar el perfil (${result.first})"
                    )
                    return
                }

                val user = parseMeResponse(result.second)
                if (user == null) {
                    _state.value = AuthUiState.Error("Respuesta invalida del servidor")
                    return
                }

                lastToken = token
                cachedUser = user
                sessionManager.accessToken = token
                sessionManager.userEmail = user.email
                sessionManager.userRole = user.role
                sessionManager.userTier = user.tier
                sessionManager.userCredits = user.balance
                _state.value = AuthUiState.Authenticated(user)
            } catch (_: IOException) {
                _state.value = AuthUiState.Error(
                    "No pudimos conectar con Numination. Revisa tu conexion."
                )
            }
        }
    }

    private fun parseMeResponse(body: String): User? = runCatching {
        val json = Gson().fromJson(body, Map::class.java) ?: return null
        @Suppress("UNCHECKED_CAST")
        val userMap = json["user"] as? Map<String, Any?> ?: return null
        User(
            id = userMap["id"]?.toString().orEmpty(),
            email = userMap["email"]?.toString().orEmpty(),
            role = userMap["role"]?.toString() ?: "USER",
            tier = userMap["tier"]?.toString() ?: "FREE",
            balance = (userMap["balance"] as? Double)?.toInt() ?: 0
        )
    }.getOrNull()

    private fun readableMessage(t: Throwable, fallback: String): String =
        t.message?.takeIf { it.isNotBlank() } ?: fallback
}

class AuthViewModelFactory(
    private val application: Application,
    private val sessionManager: SessionManager
) : ViewModelProvider.Factory {
    @Suppress("UNCHECKED_CAST")
    override fun <T : ViewModel> create(modelClass: Class<T>): T =
        AuthViewModel(application, sessionManager) as T
}
