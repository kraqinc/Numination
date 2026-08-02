package com.wren.ide.features.auth

import android.widget.Toast
import androidx.compose.animation.AnimatedVisibility
import androidx.compose.animation.Crossfade
import androidx.compose.animation.core.tween
import androidx.compose.foundation.BorderStroke
import androidx.compose.foundation.Image
import androidx.compose.foundation.background
import androidx.compose.foundation.clickable
import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.Spacer
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.height
import androidx.compose.foundation.layout.navigationBarsPadding
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.layout.size
import androidx.compose.foundation.layout.statusBarsPadding
import androidx.compose.foundation.layout.width
import androidx.compose.foundation.layout.widthIn
import androidx.compose.foundation.rememberScrollState
import androidx.compose.foundation.shape.CircleShape
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.foundation.text.KeyboardActions
import androidx.compose.foundation.text.KeyboardOptions
import androidx.compose.foundation.verticalScroll
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.filled.ArrowBack
import androidx.compose.material.icons.filled.ArrowForward
import androidx.compose.material.icons.filled.Email
import androidx.compose.material.icons.filled.ErrorOutline
import androidx.compose.material.icons.filled.Verified
import androidx.compose.material3.Button
import androidx.compose.material3.ButtonDefaults
import androidx.compose.material3.Icon
import androidx.compose.material3.IconButton
import androidx.compose.material3.OutlinedTextField
import androidx.compose.material3.OutlinedTextFieldDefaults
import androidx.compose.material3.Surface
import androidx.compose.material3.Text
import androidx.compose.runtime.Composable
import androidx.compose.runtime.LaunchedEffect
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.remember
import androidx.compose.runtime.rememberCoroutineScope
import androidx.compose.runtime.setValue
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.draw.clip
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.layout.ContentScale
import androidx.compose.ui.platform.LocalContext
import androidx.compose.ui.res.painterResource
import androidx.compose.ui.text.TextStyle
import androidx.compose.ui.text.font.FontFamily
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.text.input.ImeAction
import androidx.compose.ui.text.input.KeyboardType
import androidx.compose.ui.text.input.VisualTransformation
import androidx.compose.ui.text.style.TextAlign
import androidx.compose.ui.unit.dp
import androidx.compose.ui.unit.sp
import com.google.gson.Gson
import com.wren.ide.R
import com.wren.ide.core.network.LoginResponse
import com.wren.ide.core.network.NetworkClient
import com.wren.ide.core.storage.SessionManager
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.launch
import kotlinx.coroutines.withContext
import java.io.IOException

private enum class AuthStep { EMAIL, CODE }

private data class ApiMessageResponse(
    val ok: Boolean? = null,
    val message: String? = null,
    val error: String? = null,
    val devCode: String? = null
)

private val EmailRegex = Regex("^[A-Za-z0-9+_.-]+@[A-Za-z0-9.-]+\\.[A-Za-z]{2,}$")

private val AppBackground = Color(0xFF1C1D1B)
private val AppSurface = Color(0xFF242523)
private val AppSurfaceStrong = Color(0xFF2C2D2B)
private val AppText = Color(0xFFF4F1EB)
private val AppMuted = Color(0xFFB5B2AC)
private val AppBorder = Color(0xFF454642)
private val AppAccent = Color(0xFF6B54F6)
private val AppAccentSoft = Color(0xFF9B8FFF)
private val AppDanger = Color(0xFFE98770)
private val AppSuccess = Color(0xFF9ED8B6)

@Composable
fun AuthScreen(
    sessionManager: SessionManager,
    onAuthSuccess: () -> Unit,
    onGoogleLogin: (() -> Unit)? = null,
    onGithubLogin: (() -> Unit)? = null
) {
    val context = LocalContext.current
    val scope = rememberCoroutineScope()

    var step by remember { mutableStateOf(AuthStep.EMAIL) }
    var email by remember { mutableStateOf("") }
    var code by remember { mutableStateOf("") }
    var isLoading by remember { mutableStateOf(false) }
    var errorMessage by remember { mutableStateOf<String?>(null) }
    var helperMessage by remember { mutableStateOf<String?>(null) }

    LaunchedEffect(step) {
        errorMessage = null
        helperMessage = null
    }

    fun setSessionAndContinue(loginResponse: LoginResponse) {
        sessionManager.jwtToken = loginResponse.token
        sessionManager.userEmail = loginResponse.user.email
        sessionManager.userRole = loginResponse.user.role
        sessionManager.userTier = loginResponse.user.tier
        sessionManager.userCredits = loginResponse.user.balance
        NetworkClient.setAuthToken(loginResponse.token)
        onAuthSuccess()
    }

    fun requestCode() {
        val trimmedEmail = email.trim().lowercase()
        if (!EmailRegex.matches(trimmedEmail)) {
            errorMessage = "Escribe un correo válido para continuar."
            return
        }

        isLoading = true
        errorMessage = null
        helperMessage = null

        scope.launch {
            try {
                val result = withContext(Dispatchers.IO) {
                    NetworkClient.post("/auth/request-code", mapOf("email" to trimmedEmail)).use { response ->
                        response.code to response.body?.string().orEmpty()
                    }
                }
                val parsed = runCatching {
                    Gson().fromJson(result.second, ApiMessageResponse::class.java)
                }.getOrNull()

                isLoading = false
                if (result.first in 200..299 && parsed?.ok != false) {
                    helperMessage = parsed?.message
                        ?: "Revisa tu correo: enviamos un código de 6 dígitos."
                    parsed?.devCode?.takeIf { it.isNotBlank() }?.let {
                        helperMessage = "${helperMessage}\nCódigo de desarrollo: $it"
                    }
                    step = AuthStep.CODE
                } else {
                    errorMessage = parsed?.error ?: parsed?.message
                        ?: "No se pudo enviar el código. Inténtalo de nuevo."
                }
            } catch (_: IOException) {
                isLoading = false
                errorMessage = "No pudimos conectar con Numination. Revisa tu conexión e inténtalo de nuevo."
            } catch (_: Throwable) {
                isLoading = false
                errorMessage = "No se pudo enviar el código. Inténtalo de nuevo."
            }
        }
    }

    fun verifyCode() {
        val trimmedEmail = email.trim().lowercase()
        val trimmedCode = code.trim()

        if (!EmailRegex.matches(trimmedEmail)) {
            errorMessage = "Vuelve y corrige tu correo."
            return
        }
        if (!Regex("^\\d{6}$").matches(trimmedCode)) {
            errorMessage = "El código debe tener exactamente 6 dígitos."
            return
        }

        isLoading = true
        errorMessage = null
        helperMessage = null

        scope.launch {
            try {
                val result = withContext(Dispatchers.IO) {
                    NetworkClient.post(
                        "/auth/verify-code",
                        mapOf("email" to trimmedEmail, "code" to trimmedCode)
                    ).use { response ->
                        response.code to response.body?.string().orEmpty()
                    }
                }

                val loginResponse = runCatching {
                    Gson().fromJson(result.second, LoginResponse::class.java)
                }.getOrNull()

                isLoading = false
                if (result.first in 200..299 && !loginResponse?.token.isNullOrBlank()) {
                    setSessionAndContinue(loginResponse!!)
                } else {
                    val parsed = runCatching {
                        Gson().fromJson(result.second, ApiMessageResponse::class.java)
                    }.getOrNull()
                    errorMessage = parsed?.error ?: parsed?.message
                        ?: "No se pudo verificar el código. Inténtalo de nuevo."
                }
            } catch (_: IOException) {
                isLoading = false
                errorMessage = "No pudimos conectar con Numination. Revisa tu conexión e inténtalo de nuevo."
            } catch (_: Throwable) {
                isLoading = false
                errorMessage = "No se pudo verificar el código. Inténtalo de nuevo."
            }
        }
    }

    Column(
        modifier = Modifier
            .fillMaxSize()
            .background(AppBackground)
            .statusBarsPadding()
            .navigationBarsPadding()
    ) {
        val scrollState = rememberScrollState()

        Column(
            modifier = Modifier
                .weight(1f)
                .fillMaxWidth()
                .verticalScroll(scrollState)
                .padding(horizontal = 30.dp),
            horizontalAlignment = Alignment.CenterHorizontally,
            verticalArrangement = Arrangement.Center
        ) {
            Column(
                modifier = Modifier
                    .widthIn(max = 390.dp)
                    .fillMaxWidth(),
                horizontalAlignment = Alignment.CenterHorizontally
            ) {
                if (step == AuthStep.CODE) {
                    Row(
                        modifier = Modifier.fillMaxWidth(),
                        verticalAlignment = Alignment.CenterVertically
                    ) {
                        IconButton(
                            onClick = {
                                step = AuthStep.EMAIL
                                code = ""
                            }
                        ) {
                            Icon(
                                imageVector = Icons.Filled.ArrowBack,
                                contentDescription = "Volver al correo",
                                tint = AppText
                            )
                        }
                    }
                } else {
                    Spacer(modifier = Modifier.height(32.dp))
                }

                OfficialBrand(
                    modifier = Modifier.padding(top = if (step == AuthStep.CODE) 8.dp else 0.dp)
                )

                Spacer(modifier = Modifier.height(if (step == AuthStep.CODE) 38.dp else 52.dp))

                Crossfade(
                    targetState = step,
                    animationSpec = tween(220),
                    label = "auth-content"
                ) { currentStep ->
                    when (currentStep) {
                        AuthStep.EMAIL -> EmailLoginContent(
                            email = email,
                            isLoading = isLoading,
                            onEmailChange = {
                                email = it.lowercase()
                                errorMessage = null
                            },
                            onRequestCode = ::requestCode,
                            onGoogleLogin = {
                                if (onGoogleLogin == null) {
                                    Toast.makeText(context, "Google no está disponible todavía.", Toast.LENGTH_SHORT).show()
                                } else {
                                    onGoogleLogin()
                                }
                            },
                            onGithubLogin = {
                                if (onGithubLogin == null) {
                                    Toast.makeText(context, "GitHub no está disponible todavía.", Toast.LENGTH_SHORT).show()
                                } else {
                                    onGithubLogin()
                                }
                            }
                        )

                        AuthStep.CODE -> CodeLoginContent(
                            email = email,
                            code = code,
                            isLoading = isLoading,
                            onCodeChange = {
                                code = it.filter(Char::isDigit).take(6)
                                errorMessage = null
                            },
                            onVerify = ::verifyCode,
                            onChangeEmail = {
                                step = AuthStep.EMAIL
                                code = ""
                            }
                        )
                    }
                }

                AnimatedVisibility(visible = errorMessage != null) {
                    StatusMessage(
                        message = errorMessage.orEmpty(),
                        color = AppDanger,
                        icon = Icons.Filled.ErrorOutline
                    )
                }

                AnimatedVisibility(visible = helperMessage != null) {
                    StatusMessage(
                        message = helperMessage.orEmpty(),
                        color = AppSuccess,
                        icon = Icons.Filled.Verified
                    )
                }
            }
        }

        Text(
            text = "Al continuar aceptas los Términos de Servicio y la Política de Privacidad.",
            color = AppMuted.copy(alpha = 0.82f),
            fontSize = 11.sp,
            lineHeight = 16.sp,
            textAlign = TextAlign.Center,
            modifier = Modifier
                .fillMaxWidth()
                .padding(horizontal = 34.dp, vertical = 18.dp)
        )
    }
}

@Composable
private fun OfficialBrand(modifier: Modifier = Modifier) {
    Row(
        modifier = modifier,
        verticalAlignment = Alignment.CenterVertically,
        horizontalArrangement = Arrangement.Center
    ) {
        Image(
            painter = painterResource(R.drawable.numination_logo_mark),
            contentDescription = "Numination",
            modifier = Modifier.size(39.dp),
            contentScale = ContentScale.Fit
        )
        Spacer(modifier = Modifier.width(12.dp))
        Image(
            painter = painterResource(R.drawable.numination_logo_wordmark),
            contentDescription = "Numination",
            modifier = Modifier
                .width(202.dp)
                .height(44.dp),
            contentScale = ContentScale.Fit
        )
    }
}

@Composable
private fun EmailLoginContent(
    email: String,
    isLoading: Boolean,
    onEmailChange: (String) -> Unit,
    onRequestCode: () -> Unit,
    onGoogleLogin: () -> Unit,
    onGithubLogin: () -> Unit
) {
    Text(
        text = "La IA para quienes resuelven problemas.",
        color = AppText,
        fontFamily = FontFamily.Serif,
        fontWeight = FontWeight.Normal,
        fontSize = 30.sp,
        lineHeight = 36.sp,
        textAlign = TextAlign.Center,
        modifier = Modifier.fillMaxWidth()
    )

    Spacer(modifier = Modifier.height(12.dp))

    Text(
        text = "Construye, piensa y desbloquea ideas desde cualquier lugar.",
        color = AppMuted,
        fontSize = 14.sp,
        lineHeight = 20.sp,
        textAlign = TextAlign.Center,
        modifier = Modifier.fillMaxWidth()
    )

    Spacer(modifier = Modifier.height(38.dp))

    ProviderButton(
        iconRes = R.drawable.ic_google_mark,
        label = "Continuar con Google",
        enabled = !isLoading,
        onClick = onGoogleLogin
    )

    Spacer(modifier = Modifier.height(12.dp))

    ProviderButton(
        iconRes = R.drawable.ic_github_mark,
        label = "Continuar con GitHub",
        enabled = !isLoading,
        onClick = onGithubLogin
    )

    Spacer(modifier = Modifier.height(27.dp))

    Row(verticalAlignment = Alignment.CenterVertically) {
        Box(
            modifier = Modifier
                .weight(1f)
                .height(1.dp)
                .background(AppBorder)
        )
        Text(
            text = "  o  ",
            color = AppMuted,
            fontSize = 13.sp
        )
        Box(
            modifier = Modifier
                .weight(1f)
                .height(1.dp)
                .background(AppBorder)
        )
    }

    Spacer(modifier = Modifier.height(25.dp))

    EmailField(
        value = email,
        enabled = !isLoading,
        onValueChange = onEmailChange,
        onDone = onRequestCode
    )

    Spacer(modifier = Modifier.height(13.dp))

    PrimaryActionButton(
        text = if (isLoading) "Enviando código..." else "Continuar con correo",
        enabled = !isLoading,
        onClick = onRequestCode
    )
}

@Composable
private fun CodeLoginContent(
    email: String,
    code: String,
    isLoading: Boolean,
    onCodeChange: (String) -> Unit,
    onVerify: () -> Unit,
    onChangeEmail: () -> Unit
) {
    Text(
        text = "Revisa tu correo",
        color = AppText,
        fontFamily = FontFamily.Serif,
        fontSize = 31.sp,
        lineHeight = 37.sp,
        textAlign = TextAlign.Center,
        modifier = Modifier.fillMaxWidth()
    )

    Spacer(modifier = Modifier.height(12.dp))

    Text(
        text = "Enviamos un código de 6 dígitos a",
        color = AppMuted,
        fontSize = 14.sp,
        textAlign = TextAlign.Center,
        modifier = Modifier.fillMaxWidth()
    )

    Text(
        text = email,
        color = AppText,
        fontSize = 15.sp,
        fontWeight = FontWeight.SemiBold,
        textAlign = TextAlign.Center,
        modifier = Modifier
            .fillMaxWidth()
            .padding(top = 4.dp)
    )

    Spacer(modifier = Modifier.height(32.dp))

    CodeField(
        value = code,
        enabled = !isLoading,
        onValueChange = onCodeChange,
        onDone = onVerify
    )

    Spacer(modifier = Modifier.height(13.dp))

    PrimaryActionButton(
        text = if (isLoading) "Verificando..." else "Entrar a Numination",
        enabled = !isLoading,
        onClick = onVerify
    )

    Spacer(modifier = Modifier.height(20.dp))

    Text(
        text = "¿No es tu correo? Cambiar correo electrónico",
        color = AppAccentSoft,
        fontSize = 13.sp,
        textAlign = TextAlign.Center,
        modifier = Modifier
            .fillMaxWidth()
            .clickable(enabled = !isLoading, onClick = onChangeEmail)
            .padding(8.dp)
    )
}

@Composable
private fun ProviderButton(
    iconRes: Int,
    label: String,
    enabled: Boolean,
    onClick: () -> Unit
) {
    Surface(
        onClick = onClick,
        enabled = enabled,
        modifier = Modifier
            .fillMaxWidth()
            .height(54.dp),
        shape = RoundedCornerShape(15.dp),
        color = AppSurface,
        border = BorderStroke(1.dp, AppBorder)
    ) {
        Row(
            modifier = Modifier
                .fillMaxSize()
                .padding(horizontal = 18.dp),
            verticalAlignment = Alignment.CenterVertically,
            horizontalArrangement = Arrangement.Center
        ) {
            Image(
                painter = painterResource(iconRes),
                contentDescription = null,
                modifier = Modifier.size(21.dp)
            )
            Spacer(modifier = Modifier.width(12.dp))
            Text(
                text = label,
                color = if (enabled) AppText else AppMuted,
                fontSize = 15.sp,
                fontWeight = FontWeight.SemiBold
            )
        }
    }
}

@Composable
private fun EmailField(
    value: String,
    enabled: Boolean,
    onValueChange: (String) -> Unit,
    onDone: () -> Unit
) {
    OutlinedTextField(
        value = value,
        onValueChange = onValueChange,
        enabled = enabled,
        modifier = Modifier.fillMaxWidth(),
        singleLine = true,
        placeholder = { Text("Ingresa tu correo electrónico", color = AppMuted) },
        leadingIcon = {
            Icon(
                imageVector = Icons.Filled.Email,
                contentDescription = null,
                tint = AppAccentSoft
            )
        },
        keyboardOptions = KeyboardOptions(
            keyboardType = KeyboardType.Email,
            imeAction = ImeAction.Done
        ),
        keyboardActions = KeyboardActions(onDone = { onDone() }),
        textStyle = TextStyle(color = AppText, fontSize = 16.sp),
        shape = RoundedCornerShape(15.dp),
        colors = darkFieldColors()
    )
}

@Composable
private fun CodeField(
    value: String,
    enabled: Boolean,
    onValueChange: (String) -> Unit,
    onDone: () -> Unit
) {
    OutlinedTextField(
        value = value,
        onValueChange = onValueChange,
        enabled = enabled,
        modifier = Modifier.fillMaxWidth(),
        singleLine = true,
        placeholder = { Text("Código de 6 dígitos", color = AppMuted) },
        leadingIcon = {
            Icon(
                imageVector = Icons.Filled.Verified,
                contentDescription = null,
                tint = AppAccentSoft
            )
        },
        visualTransformation = VisualTransformation.None,
        keyboardOptions = KeyboardOptions(
            keyboardType = KeyboardType.NumberPassword,
            imeAction = ImeAction.Done
        ),
        keyboardActions = KeyboardActions(onDone = { onDone() }),
        textStyle = TextStyle(
            color = AppText,
            fontSize = 19.sp,
            letterSpacing = 5.sp,
            textAlign = TextAlign.Center
        ),
        shape = RoundedCornerShape(15.dp),
        colors = darkFieldColors()
    )
}

@Composable
private fun darkFieldColors() = OutlinedTextFieldDefaults.colors(
    focusedContainerColor = AppSurfaceStrong,
    unfocusedContainerColor = AppSurface,
    disabledContainerColor = AppSurface.copy(alpha = 0.55f),
    focusedBorderColor = AppAccentSoft,
    unfocusedBorderColor = AppBorder,
    disabledBorderColor = AppBorder.copy(alpha = 0.5f),
    focusedTextColor = AppText,
    unfocusedTextColor = AppText,
    cursorColor = AppAccentSoft,
    focusedLeadingIconColor = AppAccentSoft,
    unfocusedLeadingIconColor = AppMuted
)

@Composable
private fun PrimaryActionButton(
    text: String,
    enabled: Boolean,
    onClick: () -> Unit
) {
    Button(
        onClick = onClick,
        enabled = enabled,
        modifier = Modifier
            .fillMaxWidth()
            .height(54.dp),
        shape = RoundedCornerShape(15.dp),
        colors = ButtonDefaults.buttonColors(
            containerColor = AppAccent,
            contentColor = Color.White,
            disabledContainerColor = AppAccent.copy(alpha = 0.45f),
            disabledContentColor = Color.White.copy(alpha = 0.7f)
        )
    ) {
        Text(
            text = text,
            fontSize = 15.sp,
            fontWeight = FontWeight.Bold
        )
        if (enabled) {
            Spacer(modifier = Modifier.width(7.dp))
            Icon(
                imageVector = Icons.Filled.ArrowForward,
                contentDescription = null,
                modifier = Modifier.size(17.dp)
            )
        }
    }
}

@Composable
private fun StatusMessage(
    message: String,
    color: Color,
    icon: androidx.compose.ui.graphics.vector.ImageVector
) {
    Row(
        modifier = Modifier
            .fillMaxWidth()
            .padding(top = 18.dp),
        verticalAlignment = Alignment.Top,
        horizontalArrangement = Arrangement.Center
    ) {
        Icon(
            imageVector = icon,
            contentDescription = null,
            tint = color,
            modifier = Modifier
                .size(17.dp)
                .padding(top = 1.dp)
        )
        Spacer(modifier = Modifier.width(7.dp))
        Text(
            text = message,
            color = color,
            fontSize = 12.sp,
            lineHeight = 17.sp,
            textAlign = TextAlign.Center,
            modifier = Modifier.widthIn(max = 330.dp)
        )
    }
}