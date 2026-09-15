package com.wren.ide.features.terminal

import androidx.compose.foundation.background
import androidx.compose.foundation.border
import androidx.compose.foundation.layout.*
import androidx.compose.foundation.lazy.LazyColumn
import androidx.compose.foundation.lazy.items
import androidx.compose.foundation.lazy.rememberLazyListState
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.foundation.text.BasicTextField
import androidx.compose.foundation.text.KeyboardActions
import androidx.compose.foundation.text.KeyboardOptions
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.filled.Refresh
import androidx.compose.material.icons.filled.Send
import androidx.compose.material.icons.filled.Terminal
import androidx.compose.material3.*
import androidx.compose.runtime.*
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.graphics.SolidColor
import androidx.compose.ui.text.TextStyle
import androidx.compose.ui.text.font.FontFamily
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.text.input.ImeAction
import androidx.compose.ui.unit.dp
import androidx.compose.ui.unit.sp
import com.wren.ide.core.terminal.NuminationShellSession
import com.wren.ide.core.terminal.ShellResult
import com.wren.ide.core.theme.*
import java.io.File
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.launch
import kotlinx.coroutines.withContext

private data class TerminalEntry(
    val prompt: String,
    val output: String,
    val isError: Boolean = false
)

/** A real Android shell UI; execution is kept off the Compose main thread. */
@Composable
fun TerminalPanel(
    shell: NuminationShellSession,
    resetDir: File,
    modifier: Modifier = Modifier
) {
    val scope = rememberCoroutineScope()
    val listState = rememberLazyListState()

    var input by remember { mutableStateOf("") }
    var isExecuting by remember { mutableStateOf(false) }
    var entries by remember(shell) {
        mutableStateOf(
            listOf(
                TerminalEntry(
                    prompt = "",
                    output = "Numination Shell v1.0 — real /system/bin/sh\n" +
                        "Workspace: ${shell.cwd.absolutePath}\n" +
                        "Type 'help' for commands."
                )
            )
        )
    }

    fun scrollToBottom() {
        scope.launch {
            if (entries.isNotEmpty()) listState.animateScrollToItem(entries.lastIndex)
        }
    }

    fun runCommand(command: String) {
        if (isExecuting || command.isBlank()) return

        val promptLine = "${shell.cwd.name} $ $command"
        isExecuting = true
        scope.launch {
            val result = withContext(Dispatchers.IO) { shell.execute(command) }
            when (result) {
                ShellResult.Clear -> entries = emptyList()
                is ShellResult.Lines -> {
                    entries = entries + TerminalEntry(
                        prompt = promptLine,
                        output = result.lines.joinToString("\n") { it.text },
                        isError = result.lines.any { it.isError }
                    )
                }
            }
            isExecuting = false
            scrollToBottom()
        }
    }

    Column(
        modifier = modifier
            .fillMaxSize()
            .background(PrimaryObsidian)
            .padding(horizontal = 12.dp, vertical = 8.dp)
    ) {
        Row(
            modifier = Modifier.fillMaxWidth(),
            horizontalArrangement = Arrangement.SpaceBetween,
            verticalAlignment = Alignment.CenterVertically
        ) {
            Row(verticalAlignment = Alignment.CenterVertically) {
                Icon(
                    Icons.Filled.Terminal,
                    contentDescription = null,
                    tint = TerminalGreen,
                    modifier = Modifier.size(16.dp)
                )
                Spacer(Modifier.width(8.dp))
                Text(
                    "TERMINAL",
                    color = TextMuted,
                    fontSize = 11.sp,
                    fontWeight = FontWeight.Bold,
                    letterSpacing = 0.8.sp
                )
            }
            IconButton(
                onClick = {
                    shell.reset(resetDir)
                    entries = listOf(
                        TerminalEntry("", "Session reset.\nWorkspace: ${resetDir.absolutePath}")
                    )
                },
                enabled = !isExecuting,
                modifier = Modifier.size(32.dp)
            ) {
                Icon(
                    Icons.Filled.Refresh,
                    contentDescription = "Reiniciar terminal",
                    tint = TextMuted,
                    modifier = Modifier.size(18.dp)
                )
            }
        }

        Text(
            text = shell.cwd.absolutePath,
            color = TextMuted,
            fontFamily = FontFamily.Monospace,
            fontSize = 10.sp,
            maxLines = 1,
            modifier = Modifier.padding(bottom = 8.dp)
        )

        LazyColumn(
            state = listState,
            modifier = Modifier
                .weight(1f)
                .fillMaxWidth()
                .background(SecondaryCard, RoundedCornerShape(10.dp))
                .padding(12.dp)
        ) {
            items(entries) { entry ->
                if (entry.prompt.isNotEmpty()) {
                    Text(
                        entry.prompt,
                        color = ElectricCyan,
                        fontFamily = FontFamily.Monospace,
                        fontSize = 12.sp,
                        lineHeight = 17.sp
                    )
                }
                if (entry.output.isNotEmpty()) {
                    Text(
                        entry.output,
                        color = if (entry.isError) ErrorRed else TerminalGreen,
                        fontFamily = FontFamily.Monospace,
                        fontSize = 12.sp,
                        lineHeight = 17.sp,
                        modifier = Modifier.padding(bottom = 10.dp)
                    )
                }
            }
            if (isExecuting) {
                item {
                    Text(
                        "Running…",
                        color = TextMuted,
                        fontFamily = FontFamily.Monospace,
                        fontSize = 12.sp
                    )
                }
            }
        }

        Spacer(Modifier.height(8.dp))

        Row(
            modifier = Modifier
                .fillMaxWidth()
                .background(SecondaryCard, RoundedCornerShape(10.dp))
                .border(1.dp, BorderGray, RoundedCornerShape(10.dp))
                .padding(horizontal = 12.dp, vertical = 4.dp),
            verticalAlignment = Alignment.CenterVertically
        ) {
            Text("$ ", color = TerminalGreen, fontFamily = FontFamily.Monospace, fontSize = 13.sp)
            BasicTextField(
                value = input,
                onValueChange = { input = it },
                enabled = !isExecuting,
                textStyle = TextStyle(
                    color = TextLight,
                    fontFamily = FontFamily.Monospace,
                    fontSize = 13.sp
                ),
                singleLine = true,
                keyboardOptions = KeyboardOptions(imeAction = ImeAction.Send),
                keyboardActions = KeyboardActions(onSend = {
                    val command = input.trim()
                    input = ""
                    runCommand(command)
                }),
                cursorBrush = SolidColor(ElectricCyan),
                modifier = Modifier
                    .weight(1f)
                    .padding(vertical = 10.dp)
            )
            IconButton(
                onClick = {
                    val command = input.trim()
                    input = ""
                    runCommand(command)
                },
                enabled = input.isNotBlank() && !isExecuting,
                modifier = Modifier.size(36.dp)
            ) {
                Icon(Icons.Filled.Send, contentDescription = "Ejecutar comando", tint = ElectricCyan)
            }
        }
    }
}
