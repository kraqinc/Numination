package com.wren.ide
import com.wren.ide.BuildConfig

import android.content.Intent
import android.os.Bundle
import android.widget.Toast
import androidx.activity.ComponentActivity
import androidx.activity.compose.setContent
import androidx.lifecycle.lifecycleScope
import androidx.compose.animation.Crossfade
import androidx.compose.animation.core.tween
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.background
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.fillMaxHeight
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.runtime.Composable
import androidx.compose.runtime.LaunchedEffect
import androidx.compose.runtime.rememberCoroutineScope
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.remember
import androidx.compose.runtime.setValue
import androidx.compose.ui.Modifier
import androidx.compose.ui.draw.clip
import androidx.compose.ui.platform.LocalContext
import androidx.compose.material3.Text
import androidx.compose.material3.TextButton
import androidx.compose.material3.Surface
import androidx.compose.ui.graphics.Color
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.layout.Arrangement
import androidx.compose.ui.unit.dp
import androidx.credentials.CredentialManager
import androidx.credentials.CustomCredential
import androidx.credentials.GetCredentialRequest
import androidx.credentials.exceptions.GetCredentialCancellationException
import androidx.credentials.exceptions.GetCredentialException
import androidx.credentials.exceptions.NoCredentialException
import com.google.android.libraries.identity.googleid.GetSignInWithGoogleOption
import com.google.android.libraries.identity.googleid.GoogleIdTokenCredential
import com.google.android.libraries.identity.googleid.GoogleIdTokenParsingException
import com.google.gson.Gson
import androidx.core.view.WindowCompat
import com.wren.ide.core.network.AppVersionResponse
import com.wren.ide.core.network.AuthSessionHelper
import com.wren.ide.core.network.BackendConfig
import com.wren.ide.core.network.ConnectionStatusBanner
import com.wren.ide.core.network.LoginResponse
import com.wren.ide.core.network.NetworkClient
import com.wren.ide.core.network.OAuthLauncher
import com.wren.ide.core.network.decodeJwtPayloadOrNull
import com.wren.ide.core.storage.AppLocaleController
import com.wren.ide.core.storage.SessionManager
import com.wren.ide.core.storage.StoragePermissionBanner
import com.wren.ide.core.storage.StoragePermissionGate
import com.wren.ide.core.storage.WrenFileStorage
import com.wren.ide.core.theme.PrimaryObsidian
import com.wren.ide.core.theme.WrenTheme
import com.wren.ide.features.ai.AIAgentScreen
import com.wren.ide.features.auth.AuthScreen
import com.wren.ide.features.auth.EnterCodeEmailScreen
import com.wren.ide.features.credits.CreditsScreen
import com.wren.ide.features.editor.IDEWorkspaceScreen
import com.wren.ide.features.owner.OwnerAdminScreen
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.launch
import kotlinx.coroutines.withContext
import java.io.IOException

class MainActivity : ComponentActivity() {

    private var pendingAuthIntent by mutableStateOf<Intent?>(null)

    override fun onNewIntent(intent: Intent) {
        super.onNewIntent(intent)
        setIntent(intent)
        pendingAuthIntent = intent
    }

    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)
        WindowCompat.setDecorFitsSystemWindows(window, false)

        val sessionManager = SessionManager(applicationContext)
        BackendConfig.initialize(applicationContext)
        AppLocaleController.applyStoredLanguage(applicationContext)
        NetworkClient.setAuthToken(sessionManager.jwtToken)

        pendingAuthIntent = intent

        setContent {
            WrenTheme {
                val context = LocalContext.current
                var currentScreen by remember {
                    mutableStateOf(
                        when {
                            !sessionManager.isLoggedIn -> "auth"
                            WrenFileStorage.hasAllFilesAccess() -> "workspace"
                            else -> "storage_permission"
                        }
                    )
                }
                var updateInfo by remember { mutableStateOf<AppVersionResponse?>(null) }
                var updateError by remember { mutableStateOf<String?>(null) }
                var checkingUpdates by remember { mutableStateOf(false) }
                var pendingMagicLinkEmail by remember { mutableStateOf("") }
                var authBusy by remember { mutableStateOf(false) }
                var authError by remember { mutableStateOf<String?>(null) }

                val googleClientId = context.getString(R.string.google_web_client_id)
                val credentialManager = remember { CredentialManager.create(context) }

                fun openWorkspaceOrPermission() {
                    currentScreen = if (WrenFileStorage.hasAllFilesAccess()) "workspace" else "storage_permission"
                }

                fun completeLogin(loginResponse: LoginResponse) {
                    AuthSessionHelper.applySession(sessionManager, loginResponse)
                    authBusy = false
                    authError = null
                    openWorkspaceOrPermission()
                }

                fun requestMagicLink(email: String) {
                    lifecycleScope.launch {
                        authBusy = true
                        authError = null
                        try {
                            val result = withContext(Dispatchers.IO) {
                                NetworkClient.post("/auth/magic-link", mapOf("email" to email)).use { response ->
                                    response.code to response.body?.string().orEmpty()
                                }
                            }
                            val parsed = runCatching {
                                Gson().fromJson(result.second, com.wren.ide.features.auth.ApiMessageResponse::class.java)
                            }.getOrNull()

                            authBusy = false
                            if (result.first in 200..299 && parsed?.ok != false) {
                                parsed?.devLink?.takeIf { it.isNotBlank() }?.let { devLink ->
                                    Toast.makeText(context, "Modo dev, enlace: $devLink", Toast.LENGTH_LONG).show()
                                }
                                pendingMagicLinkEmail = email
                                currentScreen = "enter_code_email"
                            } else {
                                authError = parsed?.error ?: parsed?.message
                                    ?: AuthSessionHelper.parseErrorMessage(result.second, "No se pudo enviar el enlace.")
                            }
                        } catch (_: IOException) {
                            authBusy = false
                            authError = "No pudimos conectar con Numination. Revisa tu conexión."
                        } catch (_: Throwable) {
                            authBusy = false
                            authError = "No se pudo enviar el enlace. Inténtalo de nuevo."
                        }
                    }
                }

                fun verifyMagicLink(email: String, token: String) {
                    lifecycleScope.launch {
                        authBusy = true
                        try {
                            val result = withContext(Dispatchers.IO) {
                                NetworkClient.post(
                                    "/auth/magic-link/verify",
                                    mapOf("email" to email, "token" to token)
                                ).use { response ->
                                    response.code to response.body?.string().orEmpty()
                                }
                            }
                            val loginResponse = AuthSessionHelper.parseLoginResponse(result.second)
                            if (result.first in 200..299 && loginResponse != null) {
                                completeLogin(loginResponse)
                            } else {
                                authBusy = false
                                val message = AuthSessionHelper.parseErrorMessage(
                                    result.second,
                                    "El enlace ya no es válido. Pide uno nuevo."
                                )
                                Toast.makeText(context, message, Toast.LENGTH_LONG).show()
                            }
                        } catch (_: IOException) {
                            authBusy = false
                            Toast.makeText(
                                context,
                                "No se pudo verificar el enlace. Revisa tu conexión.",
                                Toast.LENGTH_LONG
                            ).show()
                        } catch (_: Throwable) {
                            authBusy = false
                            Toast.makeText(context, "El enlace no pudo verificarse.", Toast.LENGTH_LONG).show()
                        }
                    }
                }

                // Google Sign-In vía Credential Manager (reemplaza el GoogleSignInClient
                // legado). El flujo antiguo pasaba por un Activity de navegador/WebView de
                // Google que, para cuentas sin confianza previa en el dispositivo, mostraba
                // una pantalla extra de "verifica que eres tú" con un número a confirmar.
                // Credential Manager usa el selector de cuentas nativo del sistema y no
                // dispara esa pantalla -- no necesitamos ni queremos ningún número ahí.
                fun launchGoogleSignIn() {
                    lifecycleScope.launch {
                        authBusy = true
                        authError = null
                        try {
                            val option = GetSignInWithGoogleOption.Builder(googleClientId).build()
                            val request = GetCredentialRequest.Builder()
                                .addCredentialOption(option)
                                .build()
                            val credentialResult = credentialManager.getCredential(
                                context = context,
                                request = request
                            )

                            val credential = credentialResult.credential
                            val idToken = if (
                                credential is CustomCredential &&
                                credential.type == GoogleIdTokenCredential.TYPE_GOOGLE_ID_TOKEN_CREDENTIAL
                            ) {
                                GoogleIdTokenCredential.createFrom(credential.data).idToken
                            } else {
                                null
                            }

                            if (idToken.isNullOrBlank()) {
                                authBusy = false
                                Toast.makeText(context, "Google no devolvió ID token", Toast.LENGTH_SHORT).show()
                                return@launch
                            }

                            val networkResult = withContext(Dispatchers.IO) {
                                NetworkClient.post(
                                    "/auth/google/native",
                                    mapOf("idToken" to idToken)
                                ).use { response ->
                                    response.code to response.body?.string().orEmpty()
                                }
                            }
                            val loginResponse = AuthSessionHelper.parseLoginResponse(networkResult.second)

                            if (networkResult.first in 200..299 && loginResponse != null) {
                                completeLogin(loginResponse)
                            } else {
                                authBusy = false
                                val message = AuthSessionHelper.parseErrorMessage(
                                    networkResult.second,
                                    "No se pudo iniciar sesión con Google"
                                )
                                Toast.makeText(context, message, Toast.LENGTH_LONG).show()
                            }
                        } catch (_: GetCredentialCancellationException) {
                            authBusy = false
                        } catch (_: NoCredentialException) {
                            authBusy = false
                            Toast.makeText(
                                context,
                                "No hay ninguna cuenta de Google en este dispositivo",
                                Toast.LENGTH_LONG
                            ).show()
                        } catch (_: GoogleIdTokenParsingException) {
                            authBusy = false
                            Toast.makeText(context, "Google devolvió una respuesta inválida", Toast.LENGTH_SHORT).show()
                        } catch (e: GetCredentialException) {
                            authBusy = false
                            Toast.makeText(context, e.message ?: "No se pudo iniciar sesión con Google", Toast.LENGTH_SHORT).show()
                        } catch (t: Throwable) {
                            authBusy = false
                            Toast.makeText(context, t.message ?: "Error de Google", Toast.LENGTH_LONG).show()
                        }
                    }
                }

                LaunchedEffect(Unit) {
                    checkingUpdates = true
                    try {
                        val info = withContext(Dispatchers.IO) {
                            val response = NetworkClient.get("/meta/app-version?platform=android")
                            val body = response.body?.string().orEmpty()
                            response.close()
                            if (response.isSuccessful) {
                                Gson().fromJson(body, AppVersionResponse::class.java)
                            } else {
                                null
                            }
                        }
                        updateInfo = info
                    } catch (_: Throwable) {
                        updateError = "No se pudo comprobar actualizaciones"
                    } finally {
                        checkingUpdates = false
                    }
                }

                LaunchedEffect(pendingAuthIntent) {
                    val uri = pendingAuthIntent?.data

                    // Caso 1: deep link ya trae un JWT firmado (Google/GitHub).
                    val oauthResult = OAuthLauncher.parseAuthDeepLink(uri)
                    if (oauthResult != null) {
                        AuthSessionHelper.applySession(
                            sessionManager,
                            LoginResponse(
                                message = "OAuth",
                                token = oauthResult.token,
                                user = com.wren.ide.core.network.User(
                                    id = "",
                                    email = oauthResult.email.orEmpty(),
                                    role = decodeJwtPayloadOrNull(oauthResult.token)?.role ?: "USER",
                                    tier = decodeJwtPayloadOrNull(oauthResult.token)?.tier ?: "FREE",
                                    balance = 0
                                )
                            )
                        )

                        withContext(Dispatchers.IO) {
                            NetworkClient.get("/credits").use { response ->
                                val body = response.body?.string()
                                if (response.isSuccessful && body != null) {
                                    val json = NetworkClient.getGson().fromJson(body, Map::class.java)
                                    (json["balance"] as? Double)?.let {
                                        sessionManager.userCredits = it.toInt()
                                    }
                                }
                            }
                        }

                        pendingAuthIntent = null
                        authBusy = false
                        openWorkspaceOrPermission()
                        return@LaunchedEffect
                    }

                    val magicResult = OAuthLauncher.parseMagicLinkDeepLink(uri)
                    if (magicResult != null) {
                        pendingAuthIntent = null
                        verifyMagicLink(magicResult.email, magicResult.magicToken)
                    }
                }

                Column(modifier = Modifier.fillMaxSize().background(PrimaryObsidian)) {
                    ConnectionStatusBanner()

                    if (checkingUpdates) {
                        androidx.compose.material3.LinearProgressIndicator(modifier = Modifier.fillMaxWidth())
                    }

                    updateInfo?.let { info ->
                        if (info.version.isNotBlank() && info.version != BuildConfig.VERSION_NAME) {
                            UpdateBanner(
                                version = info.version,
                                downloadUrl = info.downloadUrl,
                                autoEnabled = info.mandatory,
                                onOpen = {
                                    if (info.downloadUrl.isNotBlank()) {
                                        val intent = Intent(Intent.ACTION_VIEW, android.net.Uri.parse(info.downloadUrl))
                                        context.startActivity(intent)
                                    }
                                }
                            )
                        }
                    }

                    if (updateError != null) {
                        androidx.compose.material3.Text(
                            text = updateError ?: "",
                            modifier = Modifier.fillMaxWidth(),
                        )
                    }

                    Crossfade(
                        targetState = currentScreen,
                        animationSpec = tween(260),
                        label = "screen",
                        modifier = Modifier.fillMaxSize()
                    ) { screen ->
                        when (screen) {
                            "auth" -> {
                                AuthScreen(
                                    sessionManager = sessionManager,
                                    isLoading = authBusy,
                                    errorMessage = authError,
                                    onClearError = { authError = null },
                                    onRequestMagicLink = ::requestMagicLink,
                                    onGoogleLogin = { launchGoogleSignIn() },
                                    onGithubLogin = { OAuthLauncher.launchGithubLogin(context) }
                                )
                            }
                            "enter_code_email" -> {
                                EnterCodeEmailScreen(
                                    email = pendingMagicLinkEmail,
                                    isLoading = authBusy,
                                    onBack = { currentScreen = "auth" },
                                    onChangeEmail = { currentScreen = "auth" },
                                    onResendLink = ::requestMagicLink
                                )
                            }
                            "storage_permission" -> {
                                StoragePermissionGate(onGranted = { currentScreen = "workspace" })
                            }
                            "workspace" -> {
                                Column(modifier = Modifier.fillMaxSize().background(PrimaryObsidian)) {
                                    StoragePermissionBanner()
                                    Box(modifier = Modifier.fillMaxSize()) {
                                        IDEWorkspaceScreen(
                                            sessionManager = sessionManager,
                                            onNavToAI = { currentScreen = "ai_agent" },
                                            onNavToCredits = { currentScreen = "credits" },
                                            onNavToOwner = { currentScreen = "owner_dashboard" },
                                            onLogout = {
                                                sessionManager.clearSession()
                                                NetworkClient.setAuthToken(null)
                                                currentScreen = "auth"
                                            },
                                            onOpenSettings = {}
                                        )
                                    }
                                }
                            }
                            "ai_agent" -> AIAgentScreen(sessionManager = sessionManager, onNavBack = { currentScreen = "workspace" })
                            "credits" -> CreditsScreen(sessionManager = sessionManager, onNavBack = { currentScreen = "workspace" })
                            "owner_dashboard" -> OwnerAdminScreen(sessionManager = sessionManager, onNavBack = { currentScreen = "workspace" })
                        }
                    }
                }
            }
        }
    }
}

@Composable
private fun UpdateBanner(version: String, downloadUrl: String, autoEnabled: Boolean, onOpen: () -> Unit) {
    androidx.compose.material3.Surface(
        modifier = Modifier.fillMaxWidth(),
        color = androidx.compose.ui.graphics.Color(0xFF11151A),
        tonalElevation = 4.dp
    ) {
        androidx.compose.foundation.layout.Row(
            modifier = Modifier
                .fillMaxWidth()
                .padding(14.dp),
            horizontalArrangement = androidx.compose.foundation.layout.Arrangement.SpaceBetween
        ) {
            androidx.compose.material3.Text(
                text = if (autoEnabled) "Actualización disponible: $version" else "Hay una nueva versión: $version",
                color = androidx.compose.ui.graphics.Color.White
            )
            androidx.compose.material3.TextButton(onClick = onOpen, enabled = downloadUrl.isNotBlank()) {
                androidx.compose.material3.Text("Descargar")
            }
        }
    }
}
