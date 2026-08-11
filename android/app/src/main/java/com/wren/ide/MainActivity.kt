package com.wren.ide
import com.wren.ide.BuildConfig

import android.content.Intent
import android.os.Bundle
import androidx.lifecycle.lifecycleScope
import androidx.activity.ComponentActivity
import androidx.activity.compose.setContent
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
import androidx.compose.runtime.collectAsState
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
import androidx.core.view.WindowCompat
import androidx.lifecycle.viewmodel.compose.viewModel
import com.google.gson.Gson
import com.wren.ide.core.network.AppVersionResponse
import com.wren.ide.core.network.BackendConfig
import com.wren.ide.core.network.ConnectionStatusBanner
import com.wren.ide.core.network.NetworkClient
import com.wren.ide.core.storage.AppLocaleController
import com.wren.ide.core.storage.SessionManager
import com.wren.ide.core.storage.StoragePermissionBanner
import com.wren.ide.core.storage.StoragePermissionGate
import com.wren.ide.core.storage.WrenFileStorage
import com.wren.ide.core.theme.PrimaryObsidian
import com.wren.ide.core.theme.WrenTheme
import com.wren.ide.data.auth.AuthUiState
import com.wren.ide.data.auth.AuthViewModel
import com.wren.ide.data.auth.AuthViewModelFactory
import com.wren.ide.data.supabase.WrenSupabase
import com.wren.ide.features.ai.AIAgentScreen
import com.wren.ide.features.auth.AuthScreen
import com.wren.ide.features.auth.EnterCodeEmailScreen
import com.wren.ide.features.credits.CreditsScreen
import com.wren.ide.features.editor.IDEWorkspaceScreen
import com.wren.ide.features.owner.OwnerAdminScreen
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.withContext

class MainActivity : ComponentActivity() {

    override fun onNewIntent(intent: Intent) {
        super.onNewIntent(intent)
        setIntent(intent)
        WrenSupabase.client.handleDeeplinks(intent)
    }

    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)
        WindowCompat.setDecorFitsSystemWindows(window, false)

        val sessionManager = SessionManager(applicationContext)
        BackendConfig.initialize(applicationContext)
        AppLocaleController.applyStoredLanguage(applicationContext)
        NetworkClient.setAuthToken(sessionManager.accessToken)

        // Supabase owns GitHub OAuth + Email OTP callback handling (PKCE).
        // This also works on a cold start when the app is opened directly by
        // the numination://auth deep link.
        WrenSupabase.client.handleDeeplinks(intent)

        setContent {
            WrenTheme {
                val context = LocalContext.current

                val authViewModel: AuthViewModel = viewModel(
                    factory = AuthViewModelFactory(application, sessionManager)
                )
                val authState by authViewModel.state.collectAsState()

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

                val authBusy = authState is AuthUiState.Loading
                val authError = (authState as? AuthUiState.Error)?.message

                fun openWorkspaceOrPermission() {
                    currentScreen = if (WrenFileStorage.hasAllFilesAccess()) "workspace" else "storage_permission"
                }

                // Reacciona a los cambios de sesion en vez de manejar cada
                // flujo (Google/GitHub/magic link/restauracion al abrir la
                // app) por separado -- todos terminan pasando por
                // AuthUiState.Authenticated.
                LaunchedEffect(authState) {
                    when (authState) {
                        is AuthUiState.Authenticated -> {
                            if (currentScreen == "auth" || currentScreen == "enter_code_email") {
                                openWorkspaceOrPermission()
                            }
                        }
                        is AuthUiState.Unauthenticated -> {
                            currentScreen = "auth"
                        }
                        else -> Unit
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
                                    onClearError = { authViewModel.clearError() },
                                    onRequestMagicLink = { email ->
                                        authViewModel.onRequestMagicLink(email) {
                                            pendingMagicLinkEmail = email
                                            currentScreen = "enter_code_email"
                                        }
                                    },
                                    onGoogleLogin = { authViewModel.onGoogleLogin() },
                                    onGithubLogin = { authViewModel.onGithubLogin() }
                                )
                            }
                            "enter_code_email" -> {
                                EnterCodeEmailScreen(
                                    email = pendingMagicLinkEmail,
                                    isLoading = authBusy,
                                    onBack = { currentScreen = "auth" },
                                    onChangeEmail = { currentScreen = "auth" },
                                    onResendLink = { email ->
                                        authViewModel.onRequestMagicLink(email)
                                    }
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
                                                authViewModel.signOut()
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
                text = if (autoEnabled) "Actualizacion disponible: $version" else "Hay una nueva version: $version",
                color = androidx.compose.ui.graphics.Color.White
            )
            androidx.compose.material3.TextButton(onClick = onOpen, enabled = downloadUrl.isNotBlank()) {
                androidx.compose.material3.Text("Descargar")
            }
        }
    }
}
