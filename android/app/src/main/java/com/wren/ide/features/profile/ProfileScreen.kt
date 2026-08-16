@file:OptIn(androidx.compose.material3.ExperimentalMaterial3Api::class)

package com.wren.ide.features.profile

import androidx.compose.foundation.background
import androidx.compose.foundation.border
import androidx.compose.foundation.layout.*
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.filled.*
import androidx.compose.material3.*
import androidx.compose.runtime.Composable
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.draw.clip
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.unit.dp
import com.wren.ide.core.storage.SessionManager
import com.wren.ide.core.theme.*

@Composable
fun ProfileScreen(
    sessionManager: SessionManager,
    onBack: () -> Unit,
    onLogout: () -> Unit,
    onSettings: () -> Unit,
    onCredits: () -> Unit
) {
    Scaffold(

        containerColor = PrimaryObsidian,

        topBar = {

            TopAppBar(

                title = {
                    Text(
                        "Perfil",
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

                colors =
                    TopAppBarDefaults
                        .topAppBarColors(
                            containerColor =
                                Color.Transparent
                        )
            )
        }
    ) { padding ->

        Column(

            Modifier
                .fillMaxSize()
                .padding(padding)
                .padding(20.dp),

            verticalArrangement =
                Arrangement.spacedBy(14.dp)
        ) {

            Row(
                Modifier.fillMaxWidth(),
                verticalAlignment =
                    Alignment.CenterVertically
            ) {

                Surface(
                    shape =
                        RoundedCornerShape(24.dp),
                    color =
                        ElectricCyan.copy(
                            alpha = .13f
                        )
                ) {

                    Icon(
                        Icons.Default.Person,
                        null,
                        tint = ElectricCyan,
                        modifier =
                            Modifier
                                .padding(20.dp)
                                .size(34.dp)
                    )
                }

                Spacer(
                    Modifier.width(14.dp)
                )

                Column {

                    Text(
                        sessionManager.userEmail.ifBlank {
                            "Usuario Numination"
                        },
                        style =
                            MaterialTheme
                                .typography
                                .titleLarge,
                        fontWeight =
                            FontWeight.Bold
                    )
                    Text(
                        "Plan ${sessionManager.userTier}",
                        color = ElectricCyan
                    )
                }
            }

            Column(

                Modifier
                    .fillMaxWidth()
                    .clip(
                        RoundedCornerShape(22.dp)
                    )
                    .background(
                        SecondaryCard
                    )
                    .border(
                        1.dp,
                        BorderGray,
                        RoundedCornerShape(22.dp)
                    )
                    .padding(18.dp),

                verticalArrangement =
                    Arrangement.spacedBy(12.dp)
            ) {

                Text(
                    "Cuenta",
                    style =
                        MaterialTheme
                            .typography
                            .titleMedium,
                    fontWeight =
                        FontWeight.Bold
                )

                Row(
                    Modifier.fillMaxWidth(),
                    horizontalArrangement =
                        Arrangement.SpaceBetween
                ) {

                    Text("Créditos")

                    Text(
                        sessionManager
                            .userCredits
                            .toString(),
                        color =
                            ElectricCyan,
                        fontWeight =
                            FontWeight.Bold
                    )
                }

                Row(
                    Modifier.fillMaxWidth(),
                    horizontalArrangement =
                        Arrangement.SpaceBetween
                ) {

                    Text("Rol")

                    Text(
                        sessionManager.userRole
                    )
                }
            }

            OutlinedButton(
                onClick = onCredits,
                modifier =
                    Modifier.fillMaxWidth()
            ) {

                Icon(
                    Icons.Default.Bolt,
                    null
                )

                Spacer(
                    Modifier.width(8.dp)
                )

                Text(
                    "Ver créditos"
                )
            }

            OutlinedButton(
                onClick = onSettings,
                modifier =
                    Modifier.fillMaxWidth()
            ) {

                Icon(
                    Icons.Default.Settings,
                    null
                )

                Spacer(
                    Modifier.width(8.dp)
                )

                Text(
                    "Configuración"
                )
            }

            Button(
                onClick = onLogout,
                modifier =
                    Modifier.fillMaxWidth(),
                colors =
                    ButtonDefaults
                        .buttonColors(
                            containerColor =
                                ErrorRed
                        )
            ) {

                Icon(
                    Icons.Default.Logout,
                    null
                )

                Spacer(
                    Modifier.width(8.dp)
                )

                Text(
                    "Cerrar sesión"
                )
            }
        }
    }
}
