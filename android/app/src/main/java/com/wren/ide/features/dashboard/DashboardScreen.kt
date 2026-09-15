@file:OptIn(androidx.compose.material3.ExperimentalMaterial3Api::class)

package com.wren.ide.features.dashboard

import androidx.compose.foundation.background
import androidx.compose.foundation.border
import androidx.compose.foundation.clickable
import androidx.compose.foundation.layout.*
import androidx.compose.foundation.lazy.LazyColumn
import androidx.compose.foundation.lazy.items
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.filled.*
import androidx.compose.material3.*
import androidx.compose.runtime.*
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.draw.clip
import androidx.compose.ui.graphics.Brush
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.unit.dp
import androidx.compose.ui.unit.sp
import com.google.gson.Gson
import com.wren.ide.core.network.*
import com.wren.ide.core.storage.SessionManager
import com.wren.ide.core.theme.*
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.launch
import kotlinx.coroutines.withContext

@Composable
private fun GlassCard(
    modifier: Modifier = Modifier,
    content: @Composable ColumnScope.() -> Unit
) {
    Column(
        modifier = modifier
            .clip(RoundedCornerShape(22.dp))
            .background(
                Brush.verticalGradient(
                    listOf(
                        SecondaryCard.copy(alpha = .96f),
                        SecondaryCard.copy(alpha = .72f)
                    )
                )
            )
            .border(
                1.dp,
                BorderGray.copy(alpha = .9f),
                RoundedCornerShape(22.dp)
            )
            .padding(18.dp),
        content = content
    )
}

@Composable
fun DashboardScreen(
    sessionManager: SessionManager,
    onNewProject: () -> Unit,
    onOpenWorkspace: () -> Unit,
    onOpenCredits: () -> Unit,
    onOpenMemory: () -> Unit,
    onOpenNotifications: () -> Unit,
    onOpenProfile: () -> Unit,
    onOpenAi: () -> Unit,
    onOpenSettings: () -> Unit
) {
    var projects by remember {
        mutableStateOf<List<Project>>(emptyList())
    }

    var activity by remember {
        mutableStateOf<List<Map<String, Any?>>>(emptyList())
    }

    var unread by remember {
        mutableIntStateOf(0)
    }

    var isLoading by remember {
        mutableStateOf(true)
    }

    val scope = rememberCoroutineScope()

    fun refresh() {
        scope.launch {
            isLoading = true

            withContext(Dispatchers.IO) {
                runCatching {
                    NetworkClient.get("/projects").use { response ->
                        if (response.isSuccessful) {
                            val parsed = Gson().fromJson(
                                response.body?.string().orEmpty(),
                                ProjectListResponse::class.java
                            )

                            withContext(Dispatchers.Main) {
                                projects = parsed.projects
                            }
                        }
                    }
                }

                runCatching {
                    NetworkClient.get("/notifications").use { response ->
                        if (response.isSuccessful) {
                            val json = Gson().fromJson(
                                response.body?.string().orEmpty(),
                                Map::class.java
                            )

                            withContext(Dispatchers.Main) {
                                unread =
                                    (json["unread"] as? Double)?.toInt() ?: 0
                            }
                        }
                    }
                }

                runCatching {
                    NetworkClient.get("/activity").use { response ->
                        if (response.isSuccessful) {
                            val json = Gson().fromJson(
                                response.body?.string().orEmpty(),
                                Map::class.java
                            )

                            @Suppress("UNCHECKED_CAST")
                            val items =
                                json["items"] as? List<Map<String, Any?>>
                                    ?: emptyList()

                            withContext(Dispatchers.Main) {
                                activity = items
                            }
                        }
                    }
                }
            }

            isLoading = false
        }
    }

    LaunchedEffect(Unit) {
        refresh()
    }

    Scaffold(
        containerColor = PrimaryObsidian,
        topBar = {
            TopAppBar(
                title = {
                    Column {
                        Text(
                            "Numination",
                            fontWeight = FontWeight.Bold
                        )

                        Text(
                            "AI development workspace",
                            fontSize = 12.sp,
                            color = TextMuted
                        )
                    }
                },
                actions = {
                    BadgedBox(
                        badge = {
                            if (unread > 0) {
                                Badge {
                                    Text(unread.toString())
                                }
                            }
                        }
                    ) {
                        IconButton(
                            onClick = onOpenNotifications
                        ) {
                            Icon(
                                Icons.Default.Notifications,
                                contentDescription = "Notificaciones"
                            )
                        }
                    }

                    IconButton(
                        onClick = onOpenProfile
                    ) {
                        Icon(
                            Icons.Default.AccountCircle,
                            contentDescription = "Perfil"
                        )
                    }
                },
                colors = TopAppBarDefaults.topAppBarColors(
                    containerColor = Color.Transparent,
                    titleContentColor = TextLight
                )
            )
        }
    ) { padding ->

        LazyColumn(
            modifier = Modifier
                .fillMaxSize()
                .padding(padding)
                .padding(horizontal = 16.dp),
            verticalArrangement = Arrangement.spacedBy(14.dp),
            contentPadding = PaddingValues(bottom = 28.dp)
        ) {

            item {
                GlassCard(
                    Modifier.fillMaxWidth()
                ) {
                    Text(
                        "¿Qué estás construyendo hoy?",
                        style = MaterialTheme.typography.headlineSmall,
                        fontWeight = FontWeight.Bold
                    )

                    Spacer(Modifier.height(8.dp))

                    Text(
                        "Tu workspace, memoria y asistente en un solo lugar.",
                        color = TextMuted
                    )

                    Spacer(Modifier.height(16.dp))

                    Row(
                        horizontalArrangement = Arrangement.spacedBy(10.dp),
                        modifier = Modifier.fillMaxWidth()
                    ) {
                        Button(
                            onClick = onNewProject,
                            modifier = Modifier.weight(1f)
                        ) {
                            Icon(Icons.Default.Add, null)

                            Spacer(
                                Modifier.width(6.dp)
                            )

                            Text("Nuevo proyecto")
                        }

                        OutlinedButton(
                            onClick = onOpenAi,
                            modifier = Modifier.weight(1f)
                        ) {
                            Icon(Icons.Default.AutoAwesome, null)

                            Spacer(
                                Modifier.width(6.dp)
                            )

                            Text("Preguntar a AI")
                        }
                    }
                }
            }

            item {
                Row(
                    horizontalArrangement = Arrangement.spacedBy(12.dp),
                    modifier = Modifier.fillMaxWidth()
                ) {

                    GlassCard(
                        Modifier.weight(1f)
                    ) {
                        Text(
                            "Créditos",
                            color = TextMuted
                        )

                        Text(
                            sessionManager.userCredits.toString(),
                            style = MaterialTheme.typography.headlineMedium,
                            fontWeight = FontWeight.Bold
                        )

                        Text(
                            sessionManager.userTier ?: "FREE",
                            color = ElectricCyan,
                            fontSize = 12.sp
                        )

                        TextButton(
                            onClick = onOpenCredits,
                            contentPadding = PaddingValues(0.dp)
                        ) {
                            Text("Ver uso")
                        }
                    }

                    GlassCard(
                        Modifier.weight(1f)
                    ) {
                        Text(
                            "Memoria",
                            color = TextMuted
                        )

                        Text(
                            "Contexto persistente",
                            fontWeight = FontWeight.SemiBold
                        )

                        Text(
                            "NUMINATION.md + recuerdos",
                            color = TextMuted,
                            fontSize = 12.sp
                        )

                        TextButton(
                            onClick = onOpenMemory,
                            contentPadding = PaddingValues(0.dp)
                        ) {
                            Text("Abrir")
                        }
                    }
                }
            }

            item {
                Row(
                    horizontalArrangement = Arrangement.SpaceBetween,
                    modifier = Modifier.fillMaxWidth(),
                    verticalAlignment = Alignment.CenterVertically
                ) {
                    Text(
                        "Proyectos recientes",
                        style = MaterialTheme.typography.titleLarge,
                        fontWeight = FontWeight.Bold
                    )

                    TextButton(
                        onClick = onOpenWorkspace
                    ) {
                        Text("Workspace")
                    }
                }
            }

            if (isLoading && projects.isEmpty()) {

                item {
                    LinearProgressIndicator(
                        Modifier.fillMaxWidth()
                    )
                }

            } else if (projects.isEmpty()) {

                item {
                    GlassCard(
                        Modifier.fillMaxWidth()
                    ) {
                        Icon(
                            Icons.Default.FolderOpen,
                            null,
                            tint = ElectricCyan,
                            modifier = Modifier.size(38.dp)
                        )

                        Spacer(
                            Modifier.height(8.dp)
                        )

                        Text(
                            "Aún no tienes proyectos",
                            fontWeight = FontWeight.Bold
                        )

                        Text(
                            "Crea uno y Numination preparará su memoria inicial.",
                            color = TextMuted
                        )
                    }
                }

            } else {

                items(
                    projects.take(8)
                ) { project ->

                    GlassCard(
                        Modifier
                            .fillMaxWidth()
                            .clickable(
                                onClick = onOpenWorkspace
                            )
                    ) {

                        Row(
                            verticalAlignment = Alignment.CenterVertically
                        ) {

                            Surface(
                                shape = RoundedCornerShape(14.dp),
                                color = ElectricCyan.copy(alpha = .13f)
                            ) {

                                Icon(
                                    Icons.Default.Folder,
                                    null,
                                    tint = ElectricCyan,
                                    modifier = Modifier.padding(12.dp)
                                )
                            }

                            Spacer(
                                Modifier.width(12.dp)
                            )

                            Column(
                                Modifier.weight(1f)
                            ) {

                                Text(
                                    project.name,
                                    fontWeight = FontWeight.Bold
                                )

                                Text(
                                    project.description?.ifBlank {
                                        "Proyecto Numination"
                                    } ?: "Proyecto Numination",
                                    color = TextMuted,
                                    maxLines = 2
                                )
                            }

                            Icon(
                                Icons.Default.ChevronRight,
                                null,
                                tint = TextMuted
                            )
                        }
                    }
                }
            }

            item {

                Row(
                    horizontalArrangement = Arrangement.SpaceBetween,
                    modifier = Modifier.fillMaxWidth(),
                    verticalAlignment = Alignment.CenterVertically
                ) {

                    Text(
                        "Actividad reciente",
                        style = MaterialTheme.typography.titleLarge,
                        fontWeight = FontWeight.Bold
                    )

                    IconButton(
                        onClick = { refresh() }
                    ) {
                        Icon(
                            Icons.Default.Refresh,
                            contentDescription = "Actualizar"
                        )
                    }
                }
            }

            if (activity.isEmpty()) {

                item {
                    Text(
                        "No hay actividad todavía.",
                        color = TextMuted,
                        modifier = Modifier.padding(vertical = 6.dp)
                    )
                }

            } else {

                items(
                    activity.take(8)
                ) { item ->

                    val description =
                        item["description"]?.toString().orEmpty()

                    Row(
                        Modifier
                            .fillMaxWidth()
                            .padding(vertical = 4.dp),
                        verticalAlignment = Alignment.CenterVertically
                    ) {

                        Icon(
                            Icons.Default.Bolt,
                            null,
                            tint = ElectricCyan,
                            modifier = Modifier.size(20.dp)
                        )

                        Spacer(
                            Modifier.width(10.dp)
                        )

                        Text(
                            description,
                            color = TextLight,
                            fontSize = 14.sp
                        )
                    }
                }
            }

            item {

                TextButton(
                    onClick = onOpenSettings,
                    modifier = Modifier.fillMaxWidth()
                ) {

                    Icon(
                        Icons.Default.Settings,
                        null
                    )

                    Spacer(
                        Modifier.width(8.dp)
                    )

                    Text("Configuración")
                }
            }
        }
    }
}
