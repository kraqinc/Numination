package com.wren.ide.features.auth

import android.widget.Toast
import androidx.compose.animation.AnimatedVisibility
import androidx.compose.foundation.Image
import androidx.compose.foundation.background
import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.height
import androidx.compose.foundation.layout.imePadding
import androidx.compose.foundation.layout.navigationBarsPadding
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.layout.size
import androidx.compose.foundation.layout.statusBarsPadding
import androidx.compose.foundation.layout.widthIn
import androidx.compose.foundation.rememberScrollState
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.foundation.text.KeyboardActions
import androidx.compose.foundation.text.KeyboardOptions
import androidx.compose.foundation.verticalScroll
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.filled.Email
import androidx.compose.material.icons.filled.ErrorOutline
import androidx.compose.material3.Button
import androidx.compose.material3.ButtonDefaults
import androidx.compose.material3.CircularProgressIndicator
import androidx.compose.material3.Icon
import androidx.compose.material3.OutlinedTextField
import androidx.compose.material3.OutlinedTextFieldDefaults
import androidx.compose.material3.Surface
import androidx.compose.material3.Text
import androidx.compose.runtime.Composable
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.remember
import androidx.compose.runtime.setValue
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.layout.ContentScale
import androidx.compose.ui.platform.LocalContext
import androidx.compose.ui.res.painterResource
import androidx.compose.ui.res.stringResource
import androidx.compose.ui.text.TextStyle
import androidx.compose.ui.text.font.FontFamily
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.text.input.ImeAction
import androidx.compose.ui.text.input.KeyboardType
import androidx.compose.ui.text.style.TextAlign
import androidx.compose.ui.unit.dp
import androidx.compose.ui.unit.sp
import com.wren.ide.R
import com.wren.ide.core.storage.SessionManager

internal data class ApiMessageResponse(
    val ok: Boolean? = null,
    val message: String? = null,
    val error: String? = null,
    val devLink: String? = null
)

private val EmailRegex = Regex("^[A-Za-z0-9+_.-]+@[A-Za-z0-9.-]+\\.[A-Za-z]{2,}$")

internal val AppBackground = Color(0xFF1C1D1B)
internal val AppSurface = Color(0xFF242523)
internal val AppSurfaceStrong = Color(0xFF2C2D2B)
internal val AppText = Color(0xFFF4F1EB)
internal val AppMuted = Color(0xFFB5B2AC)
internal val AppBorder = Color(0xFF454642)
internal val AppAccent = Color(0xFF6B54F6)
internal val AppAccentSoft = Color(0xFF9B8FFF)
internal val AppDanger = Color(0xFFE98770)
internal val AppSuccess = Color(0xFF9ED8B6)

@Composable
fun AuthScreen(
    @Suppress("UNUSED_PARAMETER") sessionManager: SessionManager,
    isLoading: Boolean,
    errorMessage: String?,
    onClearError: () -> Unit,
    onRequestMagicLink: (email: String) -> Unit,
    onGoogleLogin: (() -> Unit)? = null,
    onGithubLogin: (() -> Unit)? = null
) {
    val context = LocalContext.current

    var email by remember { mutableStateOf("") }
    var localError by remember { mutableStateOf<String?>(null) }

    fun submitEmail() {
        val trimmedEmail = email.trim().lowercase()
        if (!EmailRegex.matches(trimmedEmail)) {
            localError = context.getString(R.string.auth_error_invalid_email)
            return
        }
        localError = null
        onClearError()
        onRequestMagicLink(trimmedEmail)
    }

    val visibleError = localError ?: errorMessage
    val scrollState = rememberScrollState()

    Box(
        modifier = Modifier
            .fillMaxSize()
            .background(AppBackground)
    ) {
        Column(
            modifier = Modifier
                .fillMaxSize()
                .statusBarsPadding()
                .navigationBarsPadding()
                .imePadding()
        ) {
            Column(
                modifier = Modifier
                    .weight(1f)
                    .fillMaxWidth()
                    .verticalScroll(scrollState)
                    .padding(horizontal = 24.dp, vertical = 32.dp),
                horizontalAlignment = Alignment.CenterHorizontally,
                verticalArrangement = Arrangement.Center
            ) {
                Column(
                    modifier = Modifier.widthIn(max = 390.dp).fillMaxWidth(),
                    horizontalAlignment = Alignment.CenterHorizontally,
                    verticalArrangement = Arrangement.spacedBy(0.dp)
                ) {
                    BrandMark()

                    Spacer(22.dp)

                    Text(
                        text = stringResource(R.string.auth_tagline),
                        color = AppText,
                        fontFamily = FontFamily.Serif,
                        fontSize = 27.sp,
                        lineHeight = 32.sp,
                        textAlign = TextAlign.Center,
                        modifier = Modifier.fillMaxWidth()
                    )

                    Spacer(12.dp)

                    Text(
                        text = stringResource(R.string.auth_subtitle),
                        color = AppMuted,
                        fontSize = 14.sp,
                        lineHeight = 20.sp,
                        textAlign = TextAlign.Center,
                        modifier = Modifier.fillMaxWidth()
                    )

                    Spacer(32.dp)

                    Column(
                        modifier = Modifier.fillMaxWidth(),
                        verticalArrangement = Arrangement.spacedBy(12.dp)
                    ) {
                        ProviderButton(
                            iconRes = R.drawable.ic_google_mark,
                            label = stringResource(R.string.auth_continue_google),
                            enabled = !isLoading,
                            onClick = {
                                if (onGoogleLogin == null) {
                                    Toast.makeText(context, R.string.auth_google_unavailable, Toast.LENGTH_SHORT).show()
                                } else {
                                    onGoogleLogin()
                                }
                            }
                        )

                        ProviderButton(
                            iconRes = R.drawable.ic_github_mark,
                            label = stringResource(R.string.auth_continue_github),
                            enabled = !isLoading,
                            onClick = {
                                if (onGithubLogin == null) {
                                    Toast.makeText(context, R.string.auth_github_unavailable, Toast.LENGTH_SHORT).show()
                                } else {
                                    onGithubLogin()
                                }
                            }
                        )
                    }

                    Spacer(22.dp)

                    OrDivider()

                    Spacer(18.dp)

                    Column(
                        modifier = Modifier.fillMaxWidth(),
                        verticalArrangement = Arrangement.spacedBy(13.dp)
                    ) {
                        EmailField(
                            value = email,
                            enabled = !isLoading,
                            onValueChange = {
                                email = it
                                localError = null
                                onClearError()
                            },
                            onDone = ::submitEmail
                        )

                        PrimaryActionButton(
                            text = if (isLoading) {
                                stringResource(R.string.auth_sending_link)
                            } else {
                                stringResource(R.string.auth_continue)
                            },
                            enabled = !isLoading,
                            onClick = ::submitEmail
                        )
                    }

                    AnimatedVisibility(visible = visibleError != null) {
                        StatusMessage(
                            message = visibleError.orEmpty(),
                            color = AppDanger,
                            modifier = Modifier.padding(top = 14.dp)
                        )
                    }
                }
            }

            Text(
                text = stringResource(R.string.auth_terms),
                color = AppMuted.copy(alpha = 0.82f),
                fontSize = 11.sp,
                lineHeight = 16.sp,
                textAlign = TextAlign.Center,
                modifier = Modifier
                    .fillMaxWidth()
                    .padding(horizontal = 34.dp, vertical = 18.dp)
            )
        }

        if (isLoading) {
            Box(
                modifier = Modifier
                    .fillMaxSize()
                    .background(Color.Black.copy(alpha = 0.35f)),
                contentAlignment = Alignment.Center
            ) {
                CircularProgressIndicator(color = AppAccentSoft)
            }
        }
    }
}

@Composable
private fun Spacer(height: androidx.compose.ui.unit.Dp) {
    Box(modifier = Modifier.height(height))
}

@Composable
private fun BrandMark(modifier: Modifier = Modifier) {
    Column(
        modifier = modifier.fillMaxWidth(),
        horizontalAlignment = Alignment.CenterHorizontally,
        verticalArrangement = Arrangement.spacedBy(10.dp)
    ) {
        Image(
            painter = painterResource(R.drawable.numination_logo_mark),
            contentDescription = null,
            modifier = Modifier.size(68.dp),
            contentScale = ContentScale.Fit
        )
        Image(
            painter = painterResource(R.drawable.numination_logo_wordmark),
            contentDescription = "Numination",
            modifier = Modifier.height(44.dp).widthIn(max = 300.dp),
            contentScale = ContentScale.Fit
        )
    }
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
        modifier = Modifier.fillMaxWidth().height(52.dp),
        shape = RoundedCornerShape(15.dp),
        color = AppSurface,
        border = androidx.compose.foundation.BorderStroke(1.dp, AppBorder)
    ) {
        Row(
            modifier = Modifier.fillMaxSize().padding(horizontal = 18.dp),
            verticalAlignment = Alignment.CenterVertically,
            horizontalArrangement = Arrangement.Center
        ) {
            Image(
                painter = painterResource(iconRes),
                contentDescription = null,
                modifier = Modifier.size(21.dp)
            )
            Box(modifier = Modifier.size(width = 12.dp, height = 1.dp))
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
private fun OrDivider() {
    Row(
        modifier = Modifier.fillMaxWidth(),
        verticalAlignment = Alignment.CenterVertically,
        horizontalArrangement = Arrangement.spacedBy(12.dp)
    ) {
        Box(modifier = Modifier.weight(1f).height(1.dp).background(AppBorder))
        Text(text = stringResource(R.string.auth_or), color = AppMuted, fontSize = 13.sp)
        Box(modifier = Modifier.weight(1f).height(1.dp).background(AppBorder))
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
        placeholder = { Text(stringResource(R.string.auth_email_placeholder), color = AppMuted) },
        leadingIcon = {
            Icon(imageVector = Icons.Filled.Email, contentDescription = null, tint = AppAccentSoft)
        },
        keyboardOptions = KeyboardOptions(keyboardType = KeyboardType.Email, imeAction = ImeAction.Done),
        keyboardActions = KeyboardActions(onDone = { onDone() }),
        textStyle = TextStyle(color = AppText, fontSize = 16.sp),
        shape = RoundedCornerShape(15.dp),
        colors = darkFieldColors()
    )
}

@Composable
internal fun darkFieldColors() = OutlinedTextFieldDefaults.colors(
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
internal fun PrimaryActionButton(
    text: String,
    enabled: Boolean,
    onClick: () -> Unit
) {
    Button(
        onClick = onClick,
        enabled = enabled,
        modifier = Modifier.fillMaxWidth().height(52.dp),
        shape = RoundedCornerShape(15.dp),
        colors = ButtonDefaults.buttonColors(
            containerColor = AppAccent,
            contentColor = Color.White,
            disabledContainerColor = AppAccent.copy(alpha = 0.45f),
            disabledContentColor = Color.White.copy(alpha = 0.7f)
        )
    ) {
        Text(text = text, fontSize = 15.sp, fontWeight = FontWeight.Bold)
    }
}

@Composable
internal fun StatusMessage(
    message: String,
    color: Color,
    modifier: Modifier = Modifier
) {
    Row(
        modifier = modifier.fillMaxWidth(),
        verticalAlignment = Alignment.Top,
        horizontalArrangement = Arrangement.Center
    ) {
        Icon(
            imageVector = Icons.Filled.ErrorOutline,
            contentDescription = null,
            tint = color,
            modifier = Modifier.size(17.dp)
        )
        Box(modifier = Modifier.size(width = 7.dp, height = 1.dp))
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
