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
import com.wren.ide.core.network.BackendConfig
import com.wren.ide.core.network.ConnectionStatusBanner
import com.wren.ide.core.network.LoginResponse
import com.wren.ide.core.network.NetworkClient
import com.wren.ide.core.network.OAuthLauncher
import com.wren.ide.core.network.decodeJwtPayloadOrNull
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

                val googleClientId = context.getString(R.string.google_web_client_id)
                val credentialManager = remember { CredentialManager.create(context) }

                // Helper moved above launchGoogleSignIn to avoid forward-reference compilation errors.
                fun openWorkspaceOrPermission() {
                    currentScreen = if (WrenFileStorage.hasAllFilesAccess()) "workspace" else "storage_permission"
                }

                // Google Sign-In vía Credential Manager (reemplaza el GoogleSignInClient
                // legado). El flujo antiguo pasaba por un Activity de navegador/WebView de
                // Google que, para cuentas sin confianza previa en el dispositivo, mostraba
                // una pantalla extra de "verifica que eres tú" con un número a confirmar.
                // Credential Manager usa el selector de cuentas nativo del sistema y no
                // dispara esa pantalla -- no necesitamos ni queremos ningún número ahí.
                fun launchGoogleSignIn() {
                    // IMPORTANTE: usamos lifecycleScope (atado al ciclo de vida de la
                    // Activity), NO rememberCoroutineScope(). getCredential() lanza
                    // HiddenActivity de Credential Manager como una Activity real; eso
                    // dispara una recomposición del árbol de Compose mientras el usuario
                    // elige su cuenta, y rememberCoroutineScope() cancela la corrutina en
                    // curso cuando eso pasa -- confirmado con logcat: el flujo llegaba
                    // hasta que el usuario elegía la cuenta y luego moría en silencio,
                    // sin excepción que atrapar ni Toast que mostrar.
                    lifecycleScope.launch {
                        try {
                            val option = GetSignInWithGoogleOption.Builder(googleClientId).build()
                            val request = GetCredentialRequest.Builder()
                                .addCredentialOption(option)
                                .build()
                            val result = credentialManager.getCredential(
                                context = context,
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
                            }

                            if (idToken.isNullOrBlank()) {
                                Toast.makeText(context, "Google no devolvió ID token", Toast.LENGTH_SHORT).show()
                                return@launch
                            }

                            try {
                                val response = withContext(Dispatchers.IO) {
                                    NetworkClient.post(
                                        "/auth/google/native",
                                        mapOf("idToken" to idToken)
                                    )
                                }
                                val body = response.body?.string().orEmpty()
                                val loginResponse = runCatching {
                                    Gson().fromJson(body, LoginResponse::class.java)
                                }.getOrNull()

                                if (response.isSuccessful && loginResponse != null && loginResponse.token.isNotBlank()) {
                                    sessionManager.jwtToken = loginResponse.token
                                    sessionManager.userEmail = loginResponse.user.email
                                    sessionManager.userRole = loginResponse.user.role
                                    sessionManager.userTier = loginResponse.user.tier
                                    sessionManager.userCredits = loginResponse.user.balance
                                    NetworkClient.setAuthToken(loginResponse.token)
                                    openWorkspaceOrPermission()
                                } else {
                                    val message = runCatching {
                                        val map = Gson().fromJson(body, Map::class.java)
                                        map["error"] as? String
                                    }.getOrNull() ?: "No se pudo iniciar sesión con Google"
                                    Toast.makeText(context, message, Toast.LENGTH_LONG).show()
                                }
                            } catch (t: Throwable) {
                                Toast.makeText(context, t.message ?: "Error de Google", Toast.LENGTH_LONG).show()
                            }
                        } catch (_: GetCredentialCancellationException) {
                            // El usuario cerró el selector de cuentas -- no hace falta avisar.
                        } catch (_: NoCredentialException) {
                            Toast.makeText(
                                context,
                                "No hay ninguna cuenta de Google en este dispositivo",
                                Toast.LENGTH_LONG
                            ).show()
                        } catch (_: GoogleIdTokenParsingException) {
                            Toast.makeText(context, "Google devolvió una respuesta inválida", Toast.LENGTH_SHORT).show()
                        } catch (e: GetCredentialException) {
                            Toast.makeText(context, e.message ?: "No se pudo iniciar sesión con Google", Toast.LENGTH_SHORT).show()
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
                        sessionManager.jwtToken = oauthResult.token
                        sessionManager.userEmail = oauthResult.email ?: sessionManager.userEmail
                        val jwtInfo = decodeJwtPayloadOrNull(oauthResult.token)
                        sessionManager.userRole = jwtInfo?.role ?: sessionManager.userRole
                        sessionManager.userTier = jwtInfo?.tier ?: sessionManager.userTier
                        NetworkClient.setAuthToken(oauthResult.token)

                        withContext(Dispatchers.IO) {
                            val response = NetworkClient.get("/credits")
                            val body = response.body?.string()
                            response.close()
                            if (response.isSuccessful && body != null) {
                                val json = NetworkClient.getGson().fromJson(body, Map::class.java)
                                (json["balance"] as? Double)?.let {
                                    sessionManager.userCredits = it.toInt()
                                }
                            }
                        }

                        pendingAuthIntent = null
                        openWorkspaceOrPermission()
                        return@LaunchedEffect
                    }

                    // Caso 2: Magic Link -- trae un token opaco que hay que
                    // canjear contra el backend antes de tener una sesión real.
                    val magicResult = OAuthLauncher.parseMagicLinkDeepLink(uri)
                    if (magicResult != null) {
                        try {
                            val response = withContext(Dispatchers.IO) {
                                NetworkClient.post(
                                    "/auth/magic-link/verify",
                                    mapOf("email" to magicResult.email, "token" to magicResult.magicToken)
                                )
                            }
                            val body = response.body?.string().orEmpty()
                            val loginResponse = runCatching {
                                Gson().fromJson(body, LoginResponse::class.java)
                            }.getOrNull()

                            if (response.isSuccessful && loginResponse != null && loginResponse.token.isNotBlank()) {
                                sessionManager.jwtToken = loginResponse.token
                                sessionManager.userEmail = loginResponse.user.email
                                sessionManager.userRole = loginResponse.user.role
                                sessionManager.userTier = loginResponse.user.tier
                                sessionManager.userCredits = loginResponse.user.balance
                                NetworkClient.setAuthToken(loginResponse.token)

                                pendingAuthIntent = null
                                openWorkspaceOrPermission()
                            } else {
                                val parsed = runCatching {
                                    Gson().fromJson(body, Map::class.java)
                                }.getOrNull()
                                val error = (parsed?.get("error") as? String) ?: "El enlace ya no es válido, pide uno nuevo."
                                Toast.makeText(context, error, Toast.LENGTH_LONG).show()
                                pendingAuthIntent = null
                            }
                        } catch (_: Throwable) {
                            Toast.makeText(context, "No se pudo verificar el enlace. Revisa tu conexión.", Toast.LENGTH_LONG).show()
                            pendingAuthIntent = null
                        }
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
                                    onMagicLinkSent = { sentEmail ->
                                        pendingMagicLinkEmail = sentEmail
                                        currentScreen = "enter_code_email"
                                    },
                                    onGoogleLogin = { launchGoogleSignIn() },
                                    onGithubLogin = { OAuthLauncher.launchGithubLogin(context) }
                                )
                            }
                            "enter_code_email" -> {
                                EnterCodeEmailScreen(
                                    email = pendingMagicLinkEmail,
                                    onBack = { currentScreen = "auth" },
                                    onChangeEmail = { currentScreen = "auth" }
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
