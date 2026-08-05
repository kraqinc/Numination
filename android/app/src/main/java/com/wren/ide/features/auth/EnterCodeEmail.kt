package com.wren.ide.features.auth

import android.content.Intent
import android.widget.Toast
import androidx.compose.foundation.Image
import androidx.compose.foundation.background
import androidx.compose.foundation.clickable
import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.height
import androidx.compose.foundation.layout.navigationBarsPadding
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.layout.size
import androidx.compose.foundation.layout.statusBarsPadding
import androidx.compose.foundation.layout.widthIn
import androidx.compose.foundation.rememberScrollState
import androidx.compose.foundation.shape.CircleShape
import androidx.compose.foundation.verticalScroll
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.filled.ArrowBack
import androidx.compose.material.icons.filled.MailOutline
import androidx.compose.material3.Icon
import androidx.compose.material3.IconButton
import androidx.compose.material3.Text
import androidx.compose.runtime.Composable
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.remember
import androidx.compose.runtime.rememberCoroutineScope
import androidx.compose.runtime.setValue
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.graphics.vector.ImageVector
import androidx.compose.ui.platform.LocalContext
import androidx.compose.ui.res.painterResource
import androidx.compose.ui.text.font.FontFamily
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.text.style.TextAlign
import androidx.compose.ui.unit.dp
import androidx.compose.ui.unit.sp
import com.google.gson.Gson
import com.wren.ide.R
import com.wren.ide.core.network.NetworkClient
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.delay
import kotlinx.coroutines.launch
import kotlinx.coroutines.withContext
import java.io.IOException

@Composable
fun EnterCodeEmailScreen(
    email: String,
    onBack: () -> Unit,
    onChangeEmail: () -> Unit
) {
    val context = LocalContext.current
    val scope = rememberCoroutineScope()

    var isResending by remember { mutableStateOf(false) }
    var resendCooldown by remember { mutableStateOf(0) }
    var statusMessage by remember { mutableStateOf<String?>(null) }
    var statusIsError by remember { mutableStateOf(false) }

    fun resendLink() {
        if (isResending || resendCooldown > 0) return
        isResending = true
        statusMessage = null

        scope.launch {
            try {
                val result = withContext(Dispatchers.IO) {
                    NetworkClient.post("/auth/magic-link", mapOf("email" to email)).use { response ->
                        response.code to response.body?.string().orEmpty()
                    }
                }
                val parsed = runCatching {
                    Gson().fromJson(result.second, ApiMessageResponse::class.java)
                }.getOrNull()

                isResending = false
                if (result.first in 200..299 && parsed?.ok != false) {
                    statusIsError = false
                    statusMessage = "Enlace reenviado a $email"
                    parsed?.devLink?.takeIf { it.isNotBlank() }?.let {
                        Toast.makeText(context, "Modo dev, enlace: $it", Toast.LENGTH_LONG).show()
                    }
                    resendCooldown = 30
                    while (resendCooldown > 0) {
                        delay(1000)
                        resendCooldown -= 1
                    }
                } else {
                    statusIsError = true
                    statusMessage = parsed?.error ?: parsed?.message ?: "No se pudo reenviar el enlace."
                }
            } catch (_: IOException) {
                isResending = false
                statusIsError = true
                statusMessage = "No pudimos conectar con Numination. Revisa tu conexión."
            } catch (_: Throwable) {
                isResending = false
                statusIsError = true
                statusMessage = "No se pudo reenviar el enlace."
            }
        }
    }

    fun openGmail() {
        val intent = context.packageManager.getLaunchIntentForPackage("com.google.android.gm")
        if (intent != null) {
            context.startActivity(intent)
        } else {
            val fallback = Intent(Intent.ACTION_MAIN).apply {
                addCategory(Intent.CATEGORY_APP_EMAIL)
                flags = Intent.FLAG_ACTIVITY_NEW_TASK
            }
            runCatching { context.startActivity(fallback) }
                .onFailure {
                    Toast.makeText(context, "No encontramos una app de correo instalada.", Toast.LENGTH_SHORT).show()
                }
        }
    }

    val scrollState = rememberScrollState()

    Column(
        modifier = Modifier
            .fillMaxSize()
            .background(AppBackground)
            .statusBarsPadding()
            .navigationBarsPadding()
    ) {
        IconButton(
            onClick = onBack,
            modifier = Modifier.padding(start = 8.dp, top = 4.dp)
        ) {
            Icon(imageVector = Icons.Filled.ArrowBack, contentDescription = "Volver", tint = AppText)
        }

        Column(
            modifier = Modifier
                .weight(1f)
                .fillMaxWidth()
                .verticalScroll(scrollState)
                .padding(horizontal = 24.dp, vertical = 12.dp),
            horizontalAlignment = Alignment.CenterHorizontally,
            verticalArrangement = Arrangement.Center
        ) {
            Column(
                modifier = Modifier.widthIn(max = 390.dp).fillMaxWidth(),
                horizontalAlignment = Alignment.CenterHorizontally,
                verticalArrangement = Arrangement.spacedBy(0.dp)
            ) {
                Image(
                    painter = painterResource(R.drawable.numination_logo_mark),
                    contentDescription = null,
                    modifier = Modifier.size(56.dp)
                )

                Gap(28.dp)

                Text(
                    text = "Revisa tu correo",
                    color = AppText,
                    fontFamily = FontFamily.Serif,
                    fontSize = 28.sp,
                    lineHeight = 33.sp,
                    textAlign = TextAlign.Center,
                    modifier = Modifier.fillMaxWidth()
                )

                Gap(12.dp)

                Text(
                    text = "Enviamos un enlace para iniciar sesión.",
                    color = AppMuted,
                    fontSize = 14.sp,
                    textAlign = TextAlign.Center,
                    modifier = Modifier.fillMaxWidth()
                )

                Gap(6.dp)

                Text(
                    text = email,
                    color = AppText,
                    fontSize = 15.sp,
                    fontWeight = FontWeight.SemiBold,
                    textAlign = TextAlign.Center,
                    modifier = Modifier.fillMaxWidth()
                )

                Gap(30.dp)

                MailIconBadge()

                Gap(30.dp)

                Column(
                    modifier = Modifier.fillMaxWidth(),
                    verticalArrangement = Arrangement.spacedBy(12.dp)
                ) {
                    PrimaryActionButton(
                        text = "Abrir Gmail",
                        enabled = true,
                        onClick = ::openGmail
                    )
                }

                Gap(22.dp)

                Text(
                    text = "Cambiar correo",
                    color = AppAccentSoft,
                    fontSize = 13.sp,
                    textAlign = TextAlign.Center,
                    modifier = Modifier
                        .fillMaxWidth()
                        .clickable(onClick = onChangeEmail)
                        .padding(8.dp)
                )

                Gap(4.dp)

                Text(
                    text = if (resendCooldown > 0) {
                        "Reenviar enlace (${resendCooldown}s)"
                    } else if (isResending) {
                        "Reenviando..."
                    } else {
                        "Reenviar enlace"
                    },
                    color = if (resendCooldown > 0 || isResending) AppMuted else AppAccentSoft,
                    fontSize = 13.sp,
                    textAlign = TextAlign.Center,
                    modifier = Modifier
                        .fillMaxWidth()
                        .clickable(enabled = resendCooldown == 0 && !isResending, onClick = ::resendLink)
                        .padding(8.dp)
                )

                statusMessage?.let {
                    Gap(10.dp)
                    StatusMessage(
                        message = it,
                        color = if (statusIsError) AppDanger else AppSuccess
                    )
                }
            }
        }
    }
}

@Composable
private fun Gap(height: androidx.compose.ui.unit.Dp) {
    Box(modifier = Modifier.height(height))
}

@Composable
private fun MailIconBadge() {
    Box(
        modifier = Modifier
            .size(72.dp)
            .background(AppSurface, CircleShape),
        contentAlignment = Alignment.Center
    ) {
        Icon(
            imageVector = Icons.Filled.MailOutline,
            contentDescription = null,
            tint = AppAccentSoft,
            modifier = Modifier.size(32.dp)
        )
    }
}
