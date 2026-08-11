package com.wren.ide.features.memory

import androidx.compose.foundation.background
import androidx.compose.foundation.border
import androidx.compose.foundation.layout.*
import androidx.compose.foundation.lazy.LazyColumn
import androidx.compose.foundation.lazy.items
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.filled.*
import androidx.compose.material3.*
import androidx.compose.runtime.*
import androidx.compose.ui.Modifier
import androidx.compose.ui.draw.clip
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.unit.dp
import com.google.gson.Gson
import com.wren.ide.core.network.NetworkClient
import com.wren.ide.core.storage.SessionManager
import com.wren.ide.core.theme.*
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.launch
import kotlinx.coroutines.withContext

@Composable
fun MemoryScreen(
    sessionManager: SessionManager,
    onBack: () -> Unit
) {
    var memories by remember {
        mutableStateOf<List<Map<String, Any?>>>(emptyList())
    }

    var showAdd by remember {
        mutableStateOf(false)
    }

    var title by remember {
        mutableStateOf("")
    }

    var content by remember {
        mutableStateOf("")
    }

    val scope = rememberCoroutineScope()

    fun load() = scope.launch(Dispatchers.IO) {

        runCatching {
            NetworkClient.get("/memory").use { response ->

                if (response.isSuccessful) {

                    val json = Gson().fromJson(
                        response.body?.string().orEmpty(),
                        Map::class.java
                    )

                    @Suppress("UNCHECKED_CAST")
                    val list =
                        json["memories"]
                            as? List<Map<String, Any?>>
                            ?: emptyList()

                    withContext(Dispatchers.Main) {
                        memories = list
                    }
                }
            }
        }
    }

    LaunchedEffect(Unit) {
        load()
    }

    Scaffold(
        containerColor = PrimaryObsidian,
        topBar = {

            TopAppBar(
                title = {
                    Text(
                        "Memoria",
                        fontWeight = FontWeight.Bold
                    )
                },

                navigationIcon = {
                    IconButton(
                        onClick = onBack
                    ) {
                        Icon(
                            Icons.Default.ArrowBack,
                            null
                        )
                    }
                },

                actions = {
                    IconButton(
                        onClick = {
                            showAdd = true
                        }
                    ) {
                        Icon(
                            Icons.Default.Add,
                            null
                        )
                    }
                },

                colors = TopAppBarDefaults.topAppBarColors(
                    containerColor = Color.Transparent
                )
            )
        }
    ) { padding ->

        LazyColumn(
            Modifier
                .fillMaxSize()
                .padding(padding)
                .padding(16.dp),
            verticalArrangement = Arrangement.spacedBy(12.dp)
        ) {

            item {

                Surface(
                    color = ElectricCyan.copy(alpha = .08f),
                    shape = RoundedCornerShape(18.dp)
                ) {

                    Row(
                        Modifier
                            .fillMaxWidth()
                            .padding(16.dp)
                    ) {

                        Icon(
                            Icons.Default.Psychology,
                            null,
                            tint = ElectricCyan
                        )

                        Spacer(
                            Modifier.width(10.dp)
                        )

                        Column {

                            Text(
                                "Memoria de Numination",
                                fontWeight = FontWeight.Bold
                            )

                            Text(
                                "Recuerdos estructurados + NUMINATION.md del proyecto.",
                                color = TextMuted
                            )
                        }
                    }
                }
            }

            item {

                Text(
                    "El asistente puede guardar decisiones, preferencias y contexto importante sin convertir cada archivo en memoria.",
                    color = TextMuted
                )
            }

            if (memories.isEmpty()) {

                item {
                    Text(
                        "Todavía no hay recuerdos.",
                        color = TextMuted
                    )
                }

            } else {

                items(
                    memories
                ) { memory ->

                    Column(
                        Modifier
                            .fillMaxWidth()
                            .clip(
                                RoundedCornerShape(18.dp)
                            )
                            .background(
                                SecondaryCard
                            )
                            .border(
                                1.dp,
                                BorderGray,
                                RoundedCornerShape(18.dp)
                            )
                            .padding(16.dp)
                    ) {

                        Row {

                            Text(
                                memory["title"]
                                    ?.toString()
                                    .orEmpty(),
                                fontWeight = FontWeight.Bold,
                                Modifier.weight(1f)
                            )

                            Text(
                                memory["type"]
                                    ?.toString()
                                    .orEmpty(),
                                color = ElectricCyan,
                                style = MaterialTheme.typography.labelSmall
                            )
                        }

                        Spacer(
                            Modifier.height(6.dp)
                        )

                        Text(
                            memory["content"]
                                ?.toString()
                                .orEmpty(),
                            color = TextMuted
                        )
                    }
                }
            }
        }
    }

    if (showAdd) {

        AlertDialog(
            onDismissRequest = {
                showAdd = false
            },

            title = {
                Text("Nuevo recuerdo")
            },

            text = {
                Column(
                    verticalArrangement = Arrangement.spacedBy(10.dp)
                ) {

                    OutlinedTextField(
                        value = title,
                        onValueChange = {
                            title = it
                        },
                        label = {
                            Text("Título")
                        },
                        singleLine = true
                    )

                    OutlinedTextField(
                        value = content,
                        onValueChange = {
                            content = it
                        },
                        label = {
                            Text("Contenido")
                        },
                        minLines = 4
                    )
                }
            },

            confirmButton = {

                TextButton(
                    onClick = {

                        scope.launch(
                            Dispatchers.IO
                        ) {

                            NetworkClient.post(
                                "/memory",
                                mapOf(
                                    "title" to title,
                                    "content" to content,
                                    "type" to "USER"
                                )
                            ).use { }

                            withContext(
                                Dispatchers.Main
                            ) {
                                title = ""
                                content = ""
                                showAdd = false
                            }

                            load()
                        }
                    },
                    enabled = title.isNotBlank() &&
                            content.isNotBlank()
                ) {
                    Text("Guardar")
                }
            },

            dismissButton = {
                TextButton(
                    onClick = {
                        showAdd = false
                    }
                ) {
                    Text("Cancelar")
                }
            }
        )
    }
}
