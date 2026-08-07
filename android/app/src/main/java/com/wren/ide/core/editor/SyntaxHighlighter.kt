package com.wren.ide.core.editor

import androidx.compose.ui.graphics.Color
import androidx.compose.ui.text.AnnotatedString
import androidx.compose.ui.text.SpanStyle
import androidx.compose.ui.text.buildAnnotatedString
import androidx.compose.ui.text.font.FontStyle
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.text.withStyle
import com.wren.ide.core.theme.EditorYellow
import com.wren.ide.core.theme.ElectricCyan
import com.wren.ide.core.theme.TerminalGreen
import com.wren.ide.core.theme.TextMuted

object SyntaxHighlighter {
    private val kotlinKeywords = setOf(
        "package", "import", "class", "interface", "fun", "val", "var",
        "if", "else", "for", "while", "return", "try", "catch", "throw",
        "null", "true", "false", "object", "private", "public", "protected"
    )

    fun highlightKotlin(text: String): AnnotatedString {
        return buildAnnotatedString {
            var currentIndex = 0
            val tokenRegex = Regex("""(//.*)|(".*?")|(\d+)|([a-zA-Z_][a-zA-Z0-9_]*)|([^\s])""")

            tokenRegex.findAll(text).forEach { result ->
                val match = result.value
                val start = result.range.first

                if (start > currentIndex) {
                    append(text.substring(currentIndex, start))
                }

                when {
                    match.startsWith("//") -> {
                        withStyle(style = SpanStyle(color = TextMuted, fontStyle = FontStyle.Italic)) {
                            append(match)
                        }
                    }

                    match.startsWith("\"") && match.endsWith("\"") -> {
                        withStyle(style = SpanStyle(color = TerminalGreen)) {
                            append(match)
                        }
                    }

                    match.all { it.isDigit() } -> {
                        withStyle(style = SpanStyle(color = ElectricCyan)) {
                            append(match)
                        }
                    }

                    kotlinKeywords.contains(match) -> {
                        withStyle(style = SpanStyle(color = EditorYellow, fontWeight = FontWeight.Bold)) {
                            append(match)
                        }
                    }

                    else -> append(match)
                }

                currentIndex = result.range.last + 1
            }

            if (currentIndex < text.length) {
                append(text.substring(currentIndex))
            }
        }
    }
}
