package com.wren.ide.features.ide

import androidx.compose.foundation.background
import androidx.compose.foundation.layout.*
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.filled.AutoAwesome
import androidx.compose.material.icons.filled.Code
import androidx.compose.material.icons.filled.Terminal
import androidx.compose.material3.*
import androidx.compose.runtime.*
import androidx.compose.ui.Modifier
import com.wren.ide.core.storage.SessionManager
import com.wren.ide.core.storage.WrenFileStorage
import com.wren.ide.core.terminal.NuminationShellSession
import com.wren.ide.core.theme.PrimaryObsidian
import com.wren.ide.features.chat.ChatPanel
import com.wren.ide.features.editor.IDEWorkspaceScreen
import com.wren.ide.features.terminal.TerminalPanel

enum class IDETab(val label: String) {
    Editor("Editor"),
    Chat("AI Chat"),
    Terminal("Terminal")
}

/**
 * Shell principal estilo Cursor: Login → IDE con Editor | Chat | Terminal.
 */
@Composable
fun NuminationIDEScreen(
    sessionManager: SessionManager,
    onNavToCredits: () -> Unit,
    onNavToOwner: () -> Unit,
    onLogout: () -> Unit
) {
    var tab by remember { mutableStateOf(IDETab.Editor) }
    var activeProjectName by remember { mutableStateOf<String?>(null) }
    var activeFileContent by remember { mutableStateOf<String?>(null) }
    val workspaceDir = remember { WrenFileStorage.workspaceDir() }

    val projectDir = remember(activeProjectName) {
        activeProjectName?.let { WrenFileStorage.projectDir(it) }
    }
    val terminalRoot = projectDir ?: workspaceDir
    val shell = remember { NuminationShellSession(workspaceDir) }

    LaunchedEffect(terminalRoot) {
        shell.reset(terminalRoot)
    }

    Scaffold(
        containerColor = PrimaryObsidian,
        bottomBar = {
            NavigationBar(containerColor = MaterialTheme.colorScheme.surface) {
                IDETab.entries.forEach { item ->
                    NavigationBarItem(
                        selected = tab == item,
                        onClick = { tab = item },
                        icon = {
                            when (item) {
                                IDETab.Editor -> Icon(Icons.Filled.Code, contentDescription = item.label)
                                IDETab.Chat -> Icon(Icons.Filled.AutoAwesome, contentDescription = item.label)
                                IDETab.Terminal -> Icon(Icons.Filled.Terminal, contentDescription = item.label)
                            }
                        },
                        label = { Text(item.label) }
                    )
                }
            }
        }
    ) { innerPadding ->
        Box(
            modifier = Modifier
                .fillMaxSize()
                .padding(innerPadding)
        ) {
            when (tab) {
                IDETab.Editor -> IDEWorkspaceScreen(
                    sessionManager = sessionManager,
                    onNavToAI = { tab = IDETab.Chat },
                    onNavToCredits = onNavToCredits,
                    onNavToOwner = onNavToOwner,
                    onLogout = onLogout,
                    onNavToTerminal = { tab = IDETab.Terminal },
                    onProjectChanged = { activeProjectName = it?.name },
                    onFileContentChanged = { activeFileContent = it }
                )

                IDETab.Chat -> ChatPanel(
                    sessionManager = sessionManager,
                    fileContext = activeFileContent,
                    modifier = Modifier.fillMaxSize()
                )

                IDETab.Terminal -> TerminalPanel(
                    shell = shell,
                    resetDir = terminalRoot,
                    modifier = Modifier.fillMaxSize()
                )
            }
        }
    }
}
