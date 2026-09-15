package com.wren.ide.core.editor

import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.text.BasicTextField
import androidx.compose.runtime.Composable
import androidx.compose.ui.Modifier
import androidx.compose.ui.graphics.SolidColor
import androidx.compose.ui.text.TextStyle
import androidx.compose.ui.text.font.FontFamily
import androidx.compose.ui.text.input.OffsetMapping
import androidx.compose.ui.text.input.TextFieldValue
import androidx.compose.ui.text.input.TransformedText
import androidx.compose.ui.text.input.VisualTransformation
import androidx.compose.ui.unit.dp
import androidx.compose.ui.unit.sp
import com.wren.ide.core.theme.ElectricCyan
import com.wren.ide.core.theme.TextLight

@Composable
fun EditorInput(
    value: TextFieldValue,
    onValueChange: (TextFieldValue) -> Unit,
    modifier: Modifier = Modifier,
    language: EditorLanguage = EditorLanguage.KOTLIN
) {
    BasicTextField(
        value = value,
        onValueChange = onValueChange,
        textStyle = TextStyle(
            color = TextLight,
            fontSize = 14.sp,
            fontFamily = FontFamily.Monospace,
            lineHeight = 20.sp
        ),
        cursorBrush = SolidColor(ElectricCyan),
        visualTransformation = VisualTransformation { text ->
            val annotated = when (language) {
                EditorLanguage.KOTLIN -> SyntaxHighlighter.highlightKotlin(text.text)
            }
            TransformedText(annotated, OffsetMapping.Identity)
        },
        modifier = modifier
            .fillMaxSize()
            .padding(16.dp)
    )
}

enum class EditorLanguage {
    KOTLIN
}
