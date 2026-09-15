package com.wren.ide.features.chat

import androidx.compose.foundation.background
import androidx.compose.foundation.border
import androidx.compose.foundation.layout.*
import androidx.compose.foundation.lazy.LazyColumn
import androidx.compose.foundation.lazy.items
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.foundation.text.BasicTextField
import androidx.compose.foundation.text.KeyboardActions
import androidx.compose.foundation.text.KeyboardOptions
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.filled.AutoAwesome
import androidx.compose.material.icons.filled.Send
import androidx.compose.material3.*
import androidx.compose.runtime.*
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.draw.clip
import androidx.compose.ui.graphics.SolidColor
import androidx.compose.ui.text.TextStyle
import androidx.compose.ui.text.font.FontFamily
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.text.input.ImeAction
import androidx.compose.ui.unit.dp
import androidx.compose.ui.unit.sp
import com.google.gson.Gson
import com.wren.ide.core.network.ChatResponse
import com.wren.ide.core.network.NetworkClient
import com.wren.ide.core.storage.SessionManager
import com.wren.ide.core.theme.*
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.withContext
import kotlinx.coroutines.launch

@Composable
fun ChatPanel(
    sessionManager: SessionManager,
    fileContext: String? = null,
    modifier: Modifier = Modifier
) {
    val scope = rememberCoroutineScope()

    var prompt by remember { mutableStateOf("") }
    var isLoading by remember { mutableStateOf(false) }
    var error by remember { mutableStateOf<String?>(null) }
    var messages by remember {
        mutableStateOf(
            listOf(
                ChatMessage(
                    role = "assistant",
                    text = "Numination AI — tu copiloto de código. Pregunta sobre tu proyecto, pide refactors o genera archivos."
                )
            )
        )
    }

    fun submitPrompt() {
        if (prompt.isBlank() || isLoading) return
        if (sessionManager.userCredits <= 0) {
            error = "Créditos insuficientes."
            return
        }

        val userText = prompt.trim()
        val context = fileContext?.take(MAX_FILE_CONTEXT_CHARS)
        val contextualPrompt = if (!context.isNullOrBlank()) {
            "Contexto del archivo abierto:\n```\n$context\n```\n\n$userText"
        } else {
            userText
        }

        messages = messages + ChatMessage("user", userText)
        prompt = ""
        isLoading = true
        error = null

        scope.launch {
            val result = runCatching {
                withContext(Dispatchers.IO) {
                    NetworkClient.post("/ai/chat", mapOf("prompt" to contextualPrompt, "mode" to "chat")).use { response ->
                        if (!response.isSuccessful) {
                            throw IllegalStateException("El servidor no pudo procesar la solicitud (${response.code}).")
                        }

                        Gson().fromJson(response.body?.string().orEmpty(), ChatResponse::class.java)
                            ?: throw IllegalStateException("Respuesta vacía de Numination AI.")
                    }
                }
            }

            result.onSuccess { data ->
                if (data.success) {
                    sessionManager.userCredits = data.remainingCredits
                    messages = messages + ChatMessage("assistant", data.response)
                } else {
                    error = "Numination AI no pudo completar la solicitud."
                }
            }.onFailure { throwable ->
                error = when (throwable) {
                    is java.io.IOException -> "Sin conexión con Numination AI."
                    else -> throwable.message ?: "Ocurrió un error al hablar con Numination AI."
                }
            }
            isLoading = false
        }
    }

    Column(
        modifier = modifier
            .fillMaxSize()
            .background(PrimaryObsidian)
    ) {
        Row(
            modifier = Modifier
                .fillMaxWidth()
                .padding(horizontal = 16.dp, vertical = 12.dp),
            verticalAlignment = Alignment.CenterVertically
        ) {
            Icon(Icons.Filled.AutoAwesome, contentDescription = null, tint = ElectricCyan, modifier = Modifier.size(20.dp))
            Spacer(Modifier.width(8.dp))
            Column(modifier = Modifier.weight(1f)) {
                Text("AI Chat", color = TextLight, fontWeight = FontWeight.Bold, fontSize = 16.sp)
                Text("${sessionManager.userCredits} créditos", color = EditorYellow, fontSize = 11.sp)
            }
        }

        error?.let {
            Text(
                text = it,
                color = ErrorRed,
                fontSize = 12.sp,
                modifier = Modifier.padding(horizontal = 16.dp, vertical = 4.dp)
            )
        }

        LazyColumn(
            modifier = Modifier
                .weight(1f)
                .fillMaxWidth()
                .padding(horizontal = 16.dp),
            verticalArrangement = Arrangement.spacedBy(10.dp),
            contentPadding = PaddingValues(vertical = 8.dp)
        ) {
            items(messages) { msg ->
                ChatBubble(message = msg)
            }
            if (isLoading) {
                item {
                    Text("Pensando…", color = TextMuted, fontSize = 12.sp, fontStyle = androidx.compose.ui.text.font.FontStyle.Italic)
                }
            }
        }

        Row(
            modifier = Modifier
                .fillMaxWidth()
                .padding(12.dp)
                .background(SecondaryCard, RoundedCornerShape(14.dp))
                .border(1.dp, BorderGray, RoundedCornerShape(14.dp))
                .padding(horizontal = 12.dp, vertical = 6.dp),
            verticalAlignment = Alignment.CenterVertically
        ) {
            BasicTextField(
                value = prompt,
                onValueChange = { prompt = it },
                enabled = !isLoading,
                textStyle = TextStyle(color = TextLight, fontSize = 14.sp),
                singleLine = false,
                keyboardOptions = KeyboardOptions(imeAction = ImeAction.Send),
                keyboardActions = KeyboardActions(onSend = { submitPrompt() }),
                modifier = Modifier.weight(1f).padding(vertical = 10.dp),
                cursorBrush = SolidColor(ElectricCyan),
                decorationBox = { inner ->
                    Box {
                        if (prompt.isEmpty()) {
                            Text("Pregunta a Numination AI…", color = TextMuted, fontSize = 14.sp)
                        }
                        inner()
                    }
                }
            )
            IconButton(
                onClick = ::submitPrompt,
                enabled = !isLoading && prompt.isNotBlank()
            ) {
                Icon(Icons.Filled.Send, contentDescription = "Enviar", tint = ElectricCyan)
            }
        }
    }
}

private data class ChatMessage(val role: String, val text: String)

private const val MAX_FILE_CONTEXT_CHARS = 32_000

@Composable
private fun ChatBubble(message: ChatMessage) {
    val isUser = message.role == "user"
    val bg = if (isUser) ElectricCyan.copy(alpha = 0.12f) else SecondaryCard
    val border = if (isUser) ElectricCyan.copy(alpha = 0.35f) else BorderGray

    Column(
        modifier = Modifier
            .fillMaxWidth()
            .clip(RoundedCornerShape(14.dp))
            .background(bg)
            .border(1.dp, border, RoundedCornerShape(14.dp))
            .padding(12.dp)
    ) {
        Text(
            text = if (isUser) "Tú" else "Numination",
            color = if (isUser) ElectricCyan else EditorYellow,
            fontSize = 10.sp,
            fontWeight = FontWeight.Bold,
            letterSpacing = 0.6.sp
        )
        Spacer(Modifier.height(6.dp))
        Text(
            text = message.text,
            color = TextLight,
            fontSize = 13.sp,
            lineHeight = 19.sp,
            fontFamily = if (!isUser) FontFamily.Monospace else FontFamily.Default
        )
    }
}
