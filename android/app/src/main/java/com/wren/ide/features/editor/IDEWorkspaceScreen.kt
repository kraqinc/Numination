package com.wren.ide.features.editor

import androidx.compose.animation.core.tween
import androidx.compose.foundation.background
import androidx.compose.foundation.border
import androidx.compose.foundation.clickable
import androidx.compose.foundation.layout.*
import androidx.compose.foundation.lazy.LazyColumn
import androidx.compose.foundation.lazy.items
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.filled.Add
import androidx.compose.material.icons.filled.AdminPanelSettings
import androidx.compose.material.icons.filled.AutoAwesome
import androidx.compose.material.icons.filled.Code
import androidx.compose.material.icons.filled.CreateNewFolder
import androidx.compose.material.icons.filled.Description
import androidx.compose.material.icons.filled.Folder
import androidx.compose.material.icons.filled.FolderOpen
import androidx.compose.material.icons.filled.Logout
import androidx.compose.material.icons.filled.MonetizationOn
import androidx.compose.material.icons.filled.Settings
import androidx.compose.material.icons.filled.Save
import androidx.compose.material.icons.filled.Terminal
import androidx.compose.material3.*
import com.wren.ide.core.storage.AppLanguage
import com.wren.ide.core.storage.AppLocaleController
import com.wren.ide.core.storage.AppSettingsManager
import androidx.compose.runtime.*
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.draw.clip
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.text.font.FontFamily
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.text.input.TextFieldValue
import androidx.compose.ui.unit.dp
import androidx.compose.ui.unit.sp
import com.google.gson.Gson
import com.google.gson.reflect.TypeToken
import com.wren.ide.core.editor.EditorInput
import com.wren.ide.core.network.FileItem
import com.wren.ide.core.network.NetworkClient
import com.wren.ide.core.network.Project
import com.wren.ide.core.network.ProjectFilesResponse
import com.wren.ide.core.network.ProjectListResponse
import com.wren.ide.core.storage.SessionManager
import com.wren.ide.core.storage.WrenFileStorage
import com.wren.ide.core.theme.BorderGray
import com.wren.ide.core.theme.EditorYellow
import com.wren.ide.core.theme.ElectricCyan
import com.wren.ide.core.theme.ErrorRed
import com.wren.ide.core.theme.PrimaryObsidian
import com.wren.ide.core.theme.SecondaryCard
import com.wren.ide.core.theme.TerminalGreen
import com.wren.ide.core.theme.TextLight
import com.wren.ide.core.theme.TextMuted
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.launch
import kotlinx.coroutines.withContext

@OptIn(ExperimentalMaterial3Api::class)
@Composable
fun IDEWorkspaceScreen(
    sessionManager: SessionManager,
    onNavToAI: () -> Unit,
    onNavToCredits: () -> Unit,
    onNavToOwner: () -> Unit,
    onLogout: () -> Unit,
    onNavToTerminal: () -> Unit,
    onProjectChanged: (Project?) -> Unit = {},
    onFileContentChanged: (String?) -> Unit = {}
) {
    val scope = rememberCoroutineScope()

    var projects by remember { mutableStateOf<List<Project>>(emptyList()) }
    var selectedProject by remember { mutableStateOf<Project?>(null) }
    var files by remember { mutableStateOf<List<FileItem>>(emptyList()) }
    var selectedFile by remember { mutableStateOf<FileItem?>(null) }
    var codeContent by remember { mutableStateOf(TextFieldValue("")) }
    var isDirty by remember { mutableStateOf(false) }

    var showFileExplorer by remember { mutableStateOf(false) }

    var isLoading by remember { mutableStateOf(false) }
    var showNewProjectDialog by remember { mutableStateOf(false) }
    var showNewFileDialog by remember { mutableStateOf(false) }
    var newProjectName by remember { mutableStateOf("") }
    var newFileName by remember { mutableStateOf("") }
    var isNewFileDirectory by remember { mutableStateOf(false) }
    var showSettings by remember { mutableStateOf(false) }

    LaunchedEffect(Unit) {
        isLoading = true
        try {
            withContext(Dispatchers.IO) {
                val response = NetworkClient.get("/projects")
                if (response.isSuccessful) {
                    val body = response.body?.string()
                    val pResponse = Gson().fromJson(body, ProjectListResponse::class.java)
                    withContext(Dispatchers.Main) {
                        projects = pResponse.projects
                        if (projects.isNotEmpty()) {
                            selectedProject = projects.first()
                            onProjectChanged(projects.first())
                        } else {
                            // No projects yet — open the explorer so the user
                            // isn't dropped onto a blank, unexplained screen.
                            showFileExplorer = true
                        }
                        isLoading = false
                    }
                } else {
                    withContext(Dispatchers.Main) { isLoading = false }
                }
            }
        } catch (_: Throwable) {
            isLoading = false
        }
    }

    LaunchedEffect(selectedProject) {
        onProjectChanged(selectedProject)
        if (selectedProject == null) {
            files = emptyList()
            selectedFile = null
            codeContent = TextFieldValue("")
            onFileContentChanged(null)
        }
        selectedProject?.let { project ->
            isLoading = true
            try {
                withContext(Dispatchers.IO) {
                    val response = NetworkClient.get("/projects/${project.id}/files")
                    if (response.isSuccessful) {
                        val body = response.body?.string()
                        val fResponse = Gson().fromJson(body, ProjectFilesResponse::class.java)
                        val syncedFiles = hydrateProjectFiles(project, fResponse.files)
                        withContext(Dispatchers.Main) {
                            files = syncedFiles
                            selectedFile = files.find { it.is_directory == 0 }
                            selectedFile?.let {
                                codeContent = TextFieldValue(it.content ?: "")
                                isDirty = false
                                onFileContentChanged(it.content)
                            } ?: run {
                                codeContent = TextFieldValue("")
                                isDirty = false
                                onFileContentChanged(null)
                            }
                            isLoading = false
                        }
                    } else {
                        withContext(Dispatchers.Main) { isLoading = false }
                    }
                }
            } catch (_: Throwable) {
                isLoading = false
            }
        }
    }

    fun saveActiveFile() {
        val p = selectedProject ?: return
        val activeFile = selectedFile ?: return
        scope.launch(Dispatchers.IO) {
            try {
                val body = mapOf("content" to codeContent.text)
                val res = NetworkClient.put("/projects/${p.id}/files/${activeFile.id}", body)
                if (res.isSuccessful) {
                    WrenFileStorage.writeFile(p.name, activeFile.path, codeContent.text)
                    val updatedFiles = files.map {
                        if (it.id == activeFile.id) it.copy(content = codeContent.text) else it
                    }
                    withContext(Dispatchers.Main) {
                        files = updatedFiles
                        isDirty = false
                    }
                }
            } catch (_: Exception) {
                // Save failures are non-fatal — the user's edits remain in the
                // editor buffer and they can retry.
            }
        }
    }

    Scaffold(
        topBar = {
            WorkspaceTopBar(
                projectName = selectedProject?.name,
                fileName = selectedFile?.name,
                isDirty = isDirty,
                credits = sessionManager.userCredits,
                showOwnerAction = sessionManager.userRole == "OWNER" || sessionManager.userRole == "SUPER_ADMIN",
                onOpenExplorer = { showFileExplorer = true },
                onOpenTerminal = onNavToTerminal,
                onSave = { saveActiveFile() },
                onNavToAI = onNavToAI,
                onNavToCredits = onNavToCredits,
                onNavToOwner = onNavToOwner,
                onLogout = onLogout,
                onOpenSettings = { showSettings = true }
            )
        }
    ) { innerPadding ->
        Box(
            modifier = Modifier
                .fillMaxSize()
                .padding(innerPadding)
                .background(PrimaryObsidian)
        ) {
            // --- Full-screen editor: the primary surface on mobile, not a
            // pane squeezed next to a permanent file tree. ---
            selectedFile?.let {
                EditorInput(
                    value = codeContent,
                    onValueChange = {
                        codeContent = it
                        isDirty = true
                        onFileContentChanged(it.text)
                    },
                    modifier = Modifier
                        .fillMaxSize()
                        .padding(bottom = 72.dp)
                )
            } ?: EmptyEditorState(
                hasProject = selectedProject != null,
                onOpenExplorer = { showFileExplorer = true }
            )

            // --- Persistent "Ask AI" bar, Cursor-style, always reachable
            // without leaving the editor. ---
            AskAiBar(
                modifier = Modifier
                    .align(Alignment.BottomCenter)
                    .padding(16.dp),
                onClick = onNavToAI
            )

            if (isLoading) {
                Text(
                    text = "Cargando…",
                    color = ElectricCyan,
                    fontSize = 12.sp,
                    fontWeight = FontWeight.SemiBold,
                    modifier = Modifier
                        .align(Alignment.TopCenter)
                        .padding(top = 6.dp)
                )
            }
        }
    }

    // --- File explorer as a bottom sheet, not a permanent 35%-width sidebar
    // stealing space from the editor on a phone screen. ---
    if (showFileExplorer) {
        ModalBottomSheet(
            onDismissRequest = { showFileExplorer = false },
            containerColor = SecondaryCard
        ) {
            FileExplorerSheet(
                projects = projects,
                selectedProject = selectedProject,
                files = files,
                selectedFile = selectedFile,
                onSelectProject = { selectedProject = it },
                onSelectFile = { file ->
                    if (file.is_directory == 0) {
                        selectedFile = file
                        val localContent = selectedProject?.let { project ->
                            WrenFileStorage.readFile(project.name, file.path)
                        } ?: file.content
                        codeContent = TextFieldValue(localContent ?: "")
                        isDirty = false
                        onFileContentChanged(localContent)
                        showFileExplorer = false
                    }
                },
                onNewProject = { showNewProjectDialog = true },
                onNewFile = { showNewFileDialog = true }
            )
        }
    }

    if (showNewProjectDialog) {
        AlertDialog(
            onDismissRequest = { showNewProjectDialog = false },
            title = { Text("Nuevo Proyecto", color = TextLight) },
            text = {
                OutlinedTextField(
                    value = newProjectName,
                    onValueChange = { newProjectName = it },
                    label = { Text("Nombre del Proyecto", color = TextMuted) },
                    singleLine = true,
                    colors = OutlinedTextFieldDefaults.colors(
                        focusedTextColor = TextLight,
                        unfocusedTextColor = TextLight,
                        focusedBorderColor = ElectricCyan,
                        unfocusedBorderColor = BorderGray
                    )
                )
            },
            confirmButton = {
                TextButton(
                    onClick = {
                        if (newProjectName.isBlank()) return@TextButton
                        showNewProjectDialog = false
                        isLoading = true
                        scope.launch(Dispatchers.IO) {
                            try {
                                val body = mapOf("name" to newProjectName, "description" to "Proyecto inicial")
                                val response = NetworkClient.post("/projects", body)
                                if (response.isSuccessful) {
                                    val responseBodyStr = response.body?.string()
                                    val mapType = object : TypeToken<Map<String, Any>>() {}.type
                                    val map: Map<String, Any> = Gson().fromJson(responseBodyStr, mapType)
                                    val projectMap = map["project"] as Map<*, *>
                                    val newProj = Project(
                                        id = projectMap["id"] as String,
                                        name = projectMap["name"] as String,
                                        description = projectMap["description"] as String,
                                        created_at = projectMap["created_at"] as String,
                                        updated_at = projectMap["updated_at"] as String
                                    )
                                    withContext(Dispatchers.Main) {
                                        projects = projects + newProj
                                        selectedProject = newProj
                                        newProjectName = ""
                                        isLoading = false
                                    }
                                } else {
                                    withContext(Dispatchers.Main) { isLoading = false }
                                }
                            } catch (_: Exception) {
                                withContext(Dispatchers.Main) { isLoading = false }
                            }
                        }
                    }
                ) {
                    Text("Crear", color = ElectricCyan)
                }
            },
            dismissButton = {
                TextButton(onClick = { showNewProjectDialog = false }) {
                    Text("Cancelar", color = TextMuted)
                }
            },
            containerColor = SecondaryCard
        )
    }

    if (showNewFileDialog) {
        AlertDialog(
            onDismissRequest = { showNewFileDialog = false },
            title = { Text("Crear Elemento", color = TextLight) },
            text = {
                Column {
                    OutlinedTextField(
                        value = newFileName,
                        onValueChange = { newFileName = it },
                        label = { Text("Nombre del Archivo/Directorio", color = TextMuted) },
                        singleLine = true,
                        colors = OutlinedTextFieldDefaults.colors(
                            focusedTextColor = TextLight,
                            unfocusedTextColor = TextLight,
                            focusedBorderColor = ElectricCyan,
                            unfocusedBorderColor = BorderGray
                        ),
                        modifier = Modifier.padding(bottom = 12.dp)
                    )
                    Row(verticalAlignment = Alignment.CenterVertically) {
                        Checkbox(
                            checked = isNewFileDirectory,
                            onCheckedChange = { isNewFileDirectory = it },
                            colors = CheckboxDefaults.colors(checkedColor = ElectricCyan)
                        )
                        Spacer(modifier = Modifier.width(4.dp))
                        Text("¿Es un directorio?", color = TextLight, fontSize = 14.sp)
                    }
                }
            },
            confirmButton = {
                TextButton(
                    onClick = {
                        if (newFileName.isBlank()) return@TextButton
                        showNewFileDialog = false
                        selectedProject?.let { p ->
                            isLoading = true
                            scope.launch(Dispatchers.IO) {
                                try {
                                    val body = mapOf(
                                        "name" to newFileName,
                                        "path" to newFileName,
                                        "isDirectory" to isNewFileDirectory,
                                        "content" to ""
                                    )
                                    val response = NetworkClient.post("/projects/${p.id}/files", body)
                                    if (response.isSuccessful) {
                                        val fResponse = NetworkClient.get("/projects/${p.id}/files")
                                        if (fResponse.isSuccessful) {
                                            val b = fResponse.body?.string()
                                            val filesData = Gson().fromJson(b, ProjectFilesResponse::class.java)
                                            val syncedFiles = hydrateProjectFiles(p, filesData.files)
                                            withContext(Dispatchers.Main) {
                                                files = syncedFiles
                                                newFileName = ""
                                                isNewFileDirectory = false
                                                isLoading = false
                                            }
                                        }
                                    } else {
                                        withContext(Dispatchers.Main) { isLoading = false }
                                    }
                                } catch (_: Exception) {
                                    withContext(Dispatchers.Main) { isLoading = false }
                                }
                            }
                        }
                    }
                ) {
                    Text("Crear", color = ElectricCyan)
                }
            },
            dismissButton = {
                TextButton(onClick = { showNewFileDialog = false }) {
                    Text("Cancelar", color = TextMuted)
                }
            },
            containerColor = SecondaryCard
        )

    if (showSettings) {
        SettingsDialog(onDismiss = { showSettings = false })
    }
    }
}

/**
 * The editor API remains the source of project metadata, while the terminal
 * works on physical files. Existing local content wins to avoid overwriting a
 * terminal edit before the user explicitly saves it through the editor.
 */
private fun hydrateProjectFiles(project: Project, remoteFiles: List<FileItem>): List<FileItem> {
    if (!WrenFileStorage.hasAllFilesAccess()) return remoteFiles

    return try {
        remoteFiles.sortedWith(
            compareBy<FileItem> { it.is_directory == 0 }
                .thenBy { it.path.count { character -> character == '/' } }
        ).map { file ->
            if (file.is_directory == 1) {
                WrenFileStorage.createDirectory(project.name, file.path)
                file
            } else {
                val localContent = WrenFileStorage.readFile(project.name, file.path)
                if (localContent == null) {
                    WrenFileStorage.writeFile(project.name, file.path, file.content.orEmpty())
                }
                file.copy(content = localContent ?: file.content.orEmpty())
            }
        }
    } catch (_: Exception) {
        remoteFiles
    }
}

@OptIn(ExperimentalMaterial3Api::class)
@Composable
private fun WorkspaceTopBar(
    projectName: String?,
    fileName: String?,
    isDirty: Boolean,
    credits: Int,
    showOwnerAction: Boolean,
    onOpenExplorer: () -> Unit,
    onOpenTerminal: () -> Unit,
    onSave: () -> Unit,
    onNavToAI: () -> Unit,
    onNavToCredits: () -> Unit,
    onNavToOwner: () -> Unit,
    onLogout: () -> Unit,
    onOpenSettings: () -> Unit
) {
    Column {
        TopAppBar(
            title = {
                Column {
                    Row(verticalAlignment = Alignment.CenterVertically) {
                        Icon(Icons.Filled.Code, contentDescription = null, tint = ElectricCyan, modifier = Modifier.size(20.dp))
                        Spacer(modifier = Modifier.width(6.dp))
                        Text("NUMINATION", color = TextLight, fontSize = 17.sp, fontWeight = FontWeight.Bold, letterSpacing = 1.sp)
                    }
                    if (fileName != null) {
                        Text(
                            text = (if (isDirty) "• " else "") + fileName,
                            color = if (isDirty) EditorYellow else TextMuted,
                            fontSize = 11.sp,
                            fontFamily = FontFamily.Monospace,
                            maxLines = 1
                        )
                    } else if (projectName != null) {
                        Text(projectName, color = TextMuted, fontSize = 11.sp, maxLines = 1)
                    }
                }
            },
            navigationIcon = {
                IconButton(onClick = onOpenExplorer) {
                    Icon(Icons.Filled.FolderOpen, contentDescription = "Explorador de archivos", tint = TextLight)
                }
            },
            actions = {
                if (fileName != null) {
                    IconButton(onClick = onSave, enabled = isDirty) {
                        Icon(
                            Icons.Filled.Save,
                            contentDescription = "Guardar",
                            tint = if (isDirty) ElectricCyan else TextMuted.copy(alpha = 0.4f)
                        )
                    }
                }
                IconButton(onClick = onOpenTerminal) {
                    Icon(Icons.Filled.Terminal, contentDescription = "Terminal", tint = TextLight)
                }
                IconButton(onClick = onNavToAI) {
                    Icon(Icons.Filled.AutoAwesome, contentDescription = "AI Agent", tint = ElectricCyan)
                }
                IconButton(onClick = onNavToCredits) {
                    Row(verticalAlignment = Alignment.CenterVertically) {
                        Icon(Icons.Filled.MonetizationOn, contentDescription = "Créditos", tint = EditorYellow, modifier = Modifier.size(18.dp))
                        Text("$credits", color = EditorYellow, fontSize = 12.sp, fontWeight = FontWeight.Bold, modifier = Modifier.padding(start = 2.dp))
                    }
                }
                IconButton(onClick = onOpenSettings) {
                    Icon(Icons.Filled.Settings, contentDescription = "Ajustes", tint = TextLight)
                }
                if (showOwnerAction) {
                    IconButton(onClick = onNavToOwner) {
                        Icon(Icons.Filled.AdminPanelSettings, contentDescription = "Panel de administración", tint = TerminalGreen)
                    }
                }
                IconButton(onClick = onLogout) {
                    Icon(Icons.Filled.Logout, contentDescription = "Cerrar sesión", tint = ErrorRed)
                }
            },
            colors = TopAppBarDefaults.topAppBarColors(containerColor = SecondaryCard)
        )
        Divider(color = BorderGray, thickness = 1.dp)
    }
}


@Composable
private fun SettingsDialog(onDismiss: () -> Unit) {
    val context = androidx.compose.ui.platform.LocalContext.current
    val settings = remember { AppSettingsManager(context) }
    var autoUpdate by remember { mutableStateOf(settings.autoUpdateEnabled) }
    var language by remember { mutableStateOf(AppLanguage.fromCode(settings.preferredLanguage)) }

    AlertDialog(
        onDismissRequest = onDismiss,
        confirmButton = {
            TextButton(onClick = {
                settings.autoUpdateEnabled = autoUpdate
                settings.preferredLanguage = language.code
                AppLocaleController.applyLanguage(language.code)
                onDismiss()
            }) { Text("Guardar") }
        },
        dismissButton = {
            TextButton(onClick = onDismiss) { Text("Cerrar") }
        },
        title = { Text("Ajustes de Numination") },
        text = {
            Column {
                Row(verticalAlignment = Alignment.CenterVertically) {
                    Switch(checked = autoUpdate, onCheckedChange = { autoUpdate = it })
                    Spacer(modifier = Modifier.width(10.dp))
                    Text("Actualización automática")
                }
                Spacer(modifier = Modifier.height(12.dp))
                Text("Idioma")
                Spacer(modifier = Modifier.height(8.dp))
                Column {
                    AppLanguage.entries.forEach { lang ->
                        Row(
                            verticalAlignment = Alignment.CenterVertically,
                            modifier = Modifier
                                .fillMaxWidth()
                                .clickable { language = lang }
                                .padding(vertical = 4.dp)
                        ) {
                            RadioButton(selected = language == lang, onClick = { language = lang })
                            Spacer(modifier = Modifier.width(8.dp))
                            Text(lang.label)
                        }
                    }
                }
            }
        }
    )
}

@Composable
private fun AskAiBar(modifier: Modifier = Modifier, onClick: () -> Unit) {
    Row(
        modifier = modifier
            .fillMaxWidth()
            .clickable { onClick() }
            .background(SecondaryCard, RoundedCornerShape(14.dp))
            .border(1.dp, BorderGray, RoundedCornerShape(14.dp))
            .padding(horizontal = 16.dp, vertical = 14.dp),
        verticalAlignment = Alignment.CenterVertically
    ) {
        Icon(Icons.Filled.AutoAwesome, contentDescription = null, tint = ElectricCyan, modifier = Modifier.size(18.dp))
        Spacer(modifier = Modifier.width(10.dp))
        Text("Preguntar a Numination AI sobre este archivo…", color = TextMuted, fontSize = 13.sp)
    }
}

@Composable
private fun EmptyEditorState(hasProject: Boolean, onOpenExplorer: () -> Unit) {
    Box(modifier = Modifier.fillMaxSize(), contentAlignment = Alignment.Center) {
        Column(horizontalAlignment = Alignment.CenterHorizontally) {
            Icon(Icons.Filled.Description, contentDescription = null, tint = TextMuted, modifier = Modifier.size(36.dp))
            Spacer(modifier = Modifier.height(12.dp))
            Text(
                text = if (hasProject) "Selecciona un archivo para empezar a programar" else "Crea o abre un proyecto para empezar",
                color = TextMuted,
                fontSize = 13.sp
            )
            Spacer(modifier = Modifier.height(16.dp))
            TextButton(onClick = onOpenExplorer) {
                Text(if (hasProject) "Abrir explorador de archivos" else "Ir a proyectos", color = ElectricCyan)
            }
        }
    }
}

@Composable
private fun FileExplorerSheet(
    projects: List<Project>,
    selectedProject: Project?,
    files: List<FileItem>,
    selectedFile: FileItem?,
    onSelectProject: (Project) -> Unit,
    onSelectFile: (FileItem) -> Unit,
    onNewProject: () -> Unit,
    onNewFile: () -> Unit
) {
    Column(
        modifier = Modifier
            .fillMaxWidth()
            .heightIn(min = 320.dp, max = 560.dp)
            .padding(horizontal = 16.dp)
    ) {
        Row(
            modifier = Modifier.fillMaxWidth(),
            horizontalArrangement = Arrangement.SpaceBetween,
            verticalAlignment = Alignment.CenterVertically
        ) {
            Text("PROYECTOS", color = TextMuted, fontSize = 11.sp, fontWeight = FontWeight.Bold, letterSpacing = 0.8.sp)
            IconButton(onClick = onNewProject, modifier = Modifier.size(28.dp)) {
                Icon(Icons.Filled.Add, contentDescription = "Nuevo proyecto", tint = ElectricCyan, modifier = Modifier.size(18.dp))
            }
        }
        Spacer(modifier = Modifier.height(8.dp))

        if (projects.isEmpty()) {
            Text("Aún no tienes proyectos.", color = TextMuted, fontSize = 12.sp, modifier = Modifier.padding(bottom = 12.dp))
        } else {
            LazyColumn(modifier = Modifier.heightIn(max = 120.dp)) {
                items(projects) { project ->
                    val isSelected = selectedProject?.id == project.id
                    Row(
                        verticalAlignment = Alignment.CenterVertically,
                        modifier = Modifier
                            .fillMaxWidth()
                            .clickable { onSelectProject(project) }
                            .background(
                                if (isSelected) ElectricCyan.copy(alpha = 0.08f) else Color.Transparent,
                                RoundedCornerShape(8.dp)
                            )
                            .padding(vertical = 8.dp, horizontal = 8.dp)
                    ) {
                        Icon(Icons.Filled.Folder, contentDescription = null, tint = if (isSelected) ElectricCyan else TextMuted, modifier = Modifier.size(16.dp))
                        Spacer(modifier = Modifier.width(8.dp))
                        Text(
                            text = project.name,
                            color = if (isSelected) ElectricCyan else TextLight,
                            fontSize = 13.sp,
                            fontWeight = if (isSelected) FontWeight.Bold else FontWeight.Normal
                        )
                    }
                }
            }
        }

        Divider(color = BorderGray, thickness = 1.dp, modifier = Modifier.padding(vertical = 12.dp))

        Row(
            modifier = Modifier.fillMaxWidth(),
            horizontalArrangement = Arrangement.SpaceBetween,
            verticalAlignment = Alignment.CenterVertically
        ) {
            Text("ARCHIVOS", color = TextMuted, fontSize = 11.sp, fontWeight = FontWeight.Bold, letterSpacing = 0.8.sp)
            if (selectedProject != null) {
                IconButton(onClick = onNewFile, modifier = Modifier.size(28.dp)) {
                    Icon(Icons.Filled.CreateNewFolder, contentDescription = "Nuevo archivo", tint = ElectricCyan, modifier = Modifier.size(18.dp))
                }
            }
        }
        Spacer(modifier = Modifier.height(8.dp))

        if (selectedProject == null) {
            Text("Selecciona un proyecto para ver sus archivos.", color = TextMuted, fontSize = 12.sp)
        } else if (files.isEmpty()) {
            Text("Este proyecto todavía no tiene archivos.", color = TextMuted, fontSize = 12.sp)
        } else {
            LazyColumn(modifier = Modifier.fillMaxWidth().heightIn(max = 280.dp)) {
                items(files) { file ->
                    val isSelected = selectedFile?.id == file.id
                    Row(
                        verticalAlignment = Alignment.CenterVertically,
                        modifier = Modifier
                            .fillMaxWidth()
                            .clickable { onSelectFile(file) }
                            .background(
                                if (isSelected) ElectricCyan.copy(alpha = 0.08f) else Color.Transparent,
                                RoundedCornerShape(8.dp)
                            )
                            .padding(vertical = 9.dp, horizontal = 8.dp)
                    ) {
                        Icon(
                            imageVector = if (file.is_directory == 1) Icons.Filled.Folder else Icons.Filled.Description,
                            contentDescription = null,
                            tint = if (file.is_directory == 1) ElectricCyan else TextMuted,
                            modifier = Modifier.size(16.dp)
                        )
                        Spacer(modifier = Modifier.width(8.dp))
                        Text(text = file.name, color = if (isSelected) ElectricCyan else TextLight, fontSize = 13.sp, maxLines = 1)
                    }
                }
            }
        }
        Spacer(modifier = Modifier.height(12.dp))
    }
}
