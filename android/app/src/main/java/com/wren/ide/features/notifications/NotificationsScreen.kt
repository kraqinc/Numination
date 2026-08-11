package com.wren.ide.features.notifications

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
fun NotificationsScreen(
    sessionManager: SessionManager,
    onBack: () -> Unit
) {
    var notifications by remember {
        mutableStateOf<List<Map<String, Any?>>>(emptyList())
    }

    val scope = rememberCoroutineScope()

    fun load() = scope.launch(Dispatchers.IO) {

        runCatching {

            NetworkClient.get("/notifications")
                .use { response ->

                    if (response.isSuccessful) {

                        val json = Gson().fromJson(
                            response.body?.string().orEmpty(),
                            Map::class.java
                        )

                        @Suppress("UNCHECKED_CAST")
                        val list =
                            json["notifications"]
                                as? List<Map<String, Any?>>
                                ?: emptyList()

                        withContext(
                            Dispatchers.Main
                        ) {
                            notifications = list
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
                        "Notificaciones",
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

                    TextButton(
                        onClick = {

                            scope.launch(
                                Dispatchers.IO
                            ) {

                                NetworkClient.post(
                                    "/notifications",
                                    mapOf(
                                        "action" to "mark_all_read"
                                    )
                                ).use { }

                                load()
                            }
                        }
                    ) {
                        Text("Marcar todo")
                    }
                },

                colors =
                    TopAppBarDefaults
                        .topAppBarColors(
                            containerColor =
                                Color.Transparent
                        )
            )
        }
    ) { padding ->

        LazyColumn(
            Modifier
                .fillMaxSize()
                .padding(padding)
                .padding(16.dp),
            verticalArrangement =
                Arrangement.spacedBy(10.dp)
        ) {

            if (notifications.isEmpty()) {

                item {
                    Text(
                        "Estás al día.",
                        color = TextMuted
                    )
                }

            } else {

                items(
                    notifications
                ) { item ->

                    val read =
                        item["read"] as? Boolean
                            ?: false

                    Column(

                        Modifier
                            .fillMaxWidth()
                            .clip(
                                RoundedCornerShape(18.dp)
                            )
                            .background(
                                if (read)
                                    SecondaryCard.copy(
                                        alpha = .65f
                                    )
                                else
                                    SecondaryCard
                            )
                            .border(
                                1.dp,
                                if (read)
                                    BorderGray
                                else
                                    ElectricCyan.copy(
                                        alpha = .35f
                                    ),
                                RoundedCornerShape(18.dp)
                            )
                            .padding(16.dp)
                    ) {

                        Row {

                            Icon(
                                if (read)
                                    Icons.Default.NotificationsNone
                                else
                                    Icons.Default.NotificationsActive,
                                null,
                                tint = ElectricCyan
                            )

                            Spacer(
                                Modifier.width(10.dp)
                            )

                            Text(
                                item["title"]
                                    ?.toString()
                                    .orEmpty(),
                                fontWeight = FontWeight.Bold
                            )
                        }

                        Spacer(
                            Modifier.height(6.dp)
                        )

                        Text(
                            item["message"]
                                ?.toString()
                                .orEmpty(),
                            color = TextMuted
                        )

                        val id =
                            item["id"]
                                ?.toString()

                        if (!read &&
                            !id.isNullOrBlank()
                        ) {

                            TextButton(

                                onClick = {

                                    scope.launch(
                                        Dispatchers.IO
                                    ) {

                                        NetworkClient.post(
                                            "/notifications",
                                            mapOf(
                                                "action" to "mark_read",
                                                "id" to id
                                            )
                                        ).use { }

                                        load()
                                    }
                                }
                            ) {

                                Text(
                                    "Marcar como leída"
                                )
                            }
                        }
                    }
                }
            }
        }
    }
}
