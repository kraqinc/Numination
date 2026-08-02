package com.wren.ide.core.theme

import androidx.compose.foundation.isSystemInDarkTheme
import com.wren.ide.R
import androidx.compose.material3.MaterialTheme
import androidx.compose.material3.Typography
import androidx.compose.material3.darkColorScheme
import androidx.compose.runtime.Composable
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.text.TextStyle
import androidx.compose.ui.text.font.FontFamily
import androidx.compose.ui.unit.sp

val PrimaryObsidian = Color(0xFF050607)
val SecondaryCard = Color(0xFF101215)
val TextLight = Color(0xFFF3F5F7)
val TextMuted = Color(0xFF9CA3AF)
val ElectricCyan = Color(0xFF27E7FF)
val TerminalGreen = Color(0xFF3CE57B)
val EditorYellow = Color(0xFFFFD36A)
val BorderGray = Color(0xFF232833)
val ErrorRed = Color(0xFFFF6474)

val AnthropicSerif = FontFamily.Serif
val ClaudeHand = FontFamily.Cursive
val NuminationMono = FontFamily.Monospace

private val DarkColorScheme = darkColorScheme(
    primary = ElectricCyan,
    onPrimary = PrimaryObsidian,
    secondary = SecondaryCard,
    onSecondary = TextLight,
    background = PrimaryObsidian,
    onBackground = TextLight,
    surface = SecondaryCard,
    onSurface = TextLight,
    error = ErrorRed,
    onError = TextLight
)

private val NuminationTypography = Typography(
    displayLarge = TextStyle(
        fontFamily = AnthropicSerif,
        fontSize = 56.sp,
        lineHeight = 60.sp,
        letterSpacing = 0.sp
    ),
    headlineLarge = TextStyle(
        fontFamily = AnthropicSerif,
        fontSize = 40.sp,
        lineHeight = 44.sp
    ),
    headlineMedium = TextStyle(
        fontFamily = AnthropicSerif,
        fontSize = 30.sp,
        lineHeight = 34.sp
    ),
    titleLarge = TextStyle(
        fontFamily = AnthropicSerif,
        fontSize = 22.sp,
        lineHeight = 28.sp
    ),
    titleMedium = TextStyle(
        fontFamily = AnthropicSerif,
        fontSize = 18.sp,
        lineHeight = 24.sp
    ),
    bodyLarge = TextStyle(
        fontFamily = ClaudeHand,
        fontSize = 16.sp,
        lineHeight = 24.sp
    ),
    bodyMedium = TextStyle(
        fontFamily = ClaudeHand,
        fontSize = 14.sp,
        lineHeight = 22.sp
    ),
    bodySmall = TextStyle(
        fontFamily = ClaudeHand,
        fontSize = 12.sp,
        lineHeight = 18.sp
    )
)

@Composable
fun WrenTheme(
    darkTheme: Boolean = isSystemInDarkTheme(),
    content: @Composable () -> Unit
) {
    MaterialTheme(
        colorScheme = DarkColorScheme,
        typography = NuminationTypography,
        content = content
    )
}
