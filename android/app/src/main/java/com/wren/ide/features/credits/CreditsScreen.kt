package com.wren.ide.features.credits

import android.content.Intent
import android.content.ClipData
import android.content.ClipboardManager
import android.content.Context
import android.net.Uri
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
import androidx.compose.ui.platform.LocalContext
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.text.style.TextAlign
import androidx.compose.ui.unit.dp
import androidx.compose.ui.unit.sp
import com.google.gson.Gson
import com.wren.ide.core.network.*
import com.wren.ide.core.storage.SessionManager
import com.wren.ide.core.theme.*
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.launch
import kotlinx.coroutines.withContext

data class PaymentPackage(
    val id: String,
    val title: String,
    val points: Int,
    val priceUsd: String,
    val priceLabel: String,
    val isSubscription: Boolean = false,
    val isBestValue: Boolean = false,
    val planTier: String? = null,
    val tierDurationDays: Int? = null
)

private data class PendingPayment(
    val referenceCode: String,
    val priceLabel: String,
    val planTier: String? = null
)

private data class PaymentInstructions(
    val payment: PendingPayment,
    val paypalUrl: String
)

/** Same glass-panel language used across Auth / Workspace / AI Agent. */
@Composable
private fun GlassPanel(
    modifier: Modifier = Modifier,
    accent: Color = ElectricCyan,
    content: @Composable ColumnScope.() -> Unit
) {
    Column(
        modifier = modifier
            .clip(RoundedCornerShape(18.dp))
            .background(Brush.verticalGradient(listOf(SecondaryCard.copy(alpha = 0.55f), SecondaryCard.copy(alpha = 0.30f))))
            .border(1.dp, accent.copy(alpha = 0.25f), RoundedCornerShape(18.dp)),
        content = content
    )
}

@OptIn(ExperimentalMaterial3Api::class)
@Composable
fun CreditsScreen(
    sessionManager: SessionManager,
    onNavBack: () -> Unit
) {
    val scope = rememberCoroutineScope()
    val context = LocalContext.current

    var historyLogs by remember { mutableStateOf<List<CreditLog>>(emptyList()) }
    var isLoading by remember { mutableStateOf(false) }
    var actionMessage by remember { mutableStateOf<String?>(null) }
    var errorMessage by remember { mutableStateOf<String?>(null) }
    var selectedPackage by remember { mutableStateOf<PaymentPackage?>(null) }
    var showPaymentDialog by remember { mutableStateOf(false) }
    var activePendingPayment by remember { mutableStateOf<PendingPayment?>(null) }
    var paymentInstructions by remember { mutableStateOf<PaymentInstructions?>(null) }
    var packages by remember { mutableStateOf<List<PaymentPackage>>(emptyList()) }
    var proExpiresAt by remember { mutableStateOf<String?>(null) }

    LaunchedEffect(Unit) {
        isLoading = true
        scope.launch(Dispatchers.IO) {
            try {
                val history = NetworkClient.get("/credits/history").use { response ->
                    if (response.isSuccessful) {
                        Gson().fromJson(response.body?.string(), CreditHistoryResponse::class.java)
                    } else null
                }
                val overview = NetworkClient.get("/credits").use { response ->
                    if (response.isSuccessful) {
                        Gson().fromJson(response.body?.string(), CreditsOverviewResponse::class.java)
                    } else null
                }
                withContext(Dispatchers.Main) {
                    historyLogs = history?.logs.orEmpty()
                    overview?.let { data ->
                        sessionManager.userCredits = data.balance
                        sessionManager.userTier = data.tier
                        proExpiresAt = data.proExpiresAt
                        packages = data.plans.map { it.toPaymentPackage() }
                        activePendingPayment = data.pending.firstOrNull()?.toPendingPayment()
                    } ?: run {
                        errorMessage = "No se pudieron cargar los planes de pago."
                    }
                    isLoading = false
                }
            } catch (_: Exception) {
                withContext(Dispatchers.Main) {
                    errorMessage = "No se pudo conectar con la billetera de Numination."
                    isLoading = false
                }
            }
        }
    }

    Box(
        modifier = Modifier
            .fillMaxSize()
            .background(Brush.verticalGradient(listOf(PrimaryObsidian, Color(0xFF0B1020), PrimaryObsidian)))
    ) {
        Box(
            modifier = Modifier
                .size(240.dp)
                .align(Alignment.TopEnd)
                .offset(x = 60.dp, y = (-30).dp)
                .background(Brush.radialGradient(listOf(EditorYellow.copy(alpha = 0.10f), Color.Transparent)), RoundedCornerShape(120.dp))
        )

        Scaffold(
            containerColor = Color.Transparent,
            topBar = {
                TopAppBar(
                    title = { Text("Mi Billetera Numination", color = TextLight, fontSize = 16.sp) },
                    navigationIcon = {
                        IconButton(onClick = onNavBack) {
                            Icon(Icons.Filled.ArrowBack, contentDescription = "Regresar", tint = TextLight)
                        }
                    },
                    colors = TopAppBarDefaults.topAppBarColors(containerColor = Color.Transparent)
                )
            }
        ) { innerPadding ->
            LazyColumn(
                modifier = Modifier.fillMaxSize().padding(innerPadding).padding(horizontal = 16.dp),
                verticalArrangement = Arrangement.spacedBy(16.dp),
                contentPadding = PaddingValues(vertical = 16.dp)
            ) {
                // Bento tile 1: balance, full width, hero-sized
                item {
                    GlassPanel(modifier = Modifier.fillMaxWidth(), accent = EditorYellow) {
                        Column(
                            modifier = Modifier.padding(24.dp).fillMaxWidth(),
                            horizontalAlignment = Alignment.CenterHorizontally
                        ) {
                            Icon(Icons.Filled.MonetizationOn, contentDescription = null, tint = EditorYellow, modifier = Modifier.size(48.dp))
                            Spacer(modifier = Modifier.height(8.dp))
                            Text("BALANCE DE PUNTOS", color = TextMuted, fontSize = 11.sp, fontWeight = FontWeight.Bold, letterSpacing = 1.sp)
                            Text("${sessionManager.userCredits} Pts", color = EditorYellow, fontSize = 34.sp, fontWeight = FontWeight.Black)
                            Spacer(modifier = Modifier.height(4.dp))
                            Row(verticalAlignment = Alignment.CenterVertically) {
                                Icon(Icons.Filled.Star, contentDescription = null, tint = ElectricCyan, modifier = Modifier.size(14.dp))
                                Spacer(modifier = Modifier.width(4.dp))
                                Text("Plan ${sessionManager.userTier}", color = ElectricCyan, fontSize = 12.sp, fontWeight = FontWeight.Bold)
                            }
                        }
                    }
                }

                if (sessionManager.userTier == "PRO") {
                    item {
                        GlassPanel(modifier = Modifier.fillMaxWidth(), accent = TerminalGreen) {
                            Row(
                                modifier = Modifier.padding(16.dp).fillMaxWidth(),
                                verticalAlignment = Alignment.CenterVertically
                            ) {
                                Icon(Icons.Filled.Verified, contentDescription = null, tint = TerminalGreen)
                                Spacer(modifier = Modifier.width(10.dp))
                                Column {
                                    Text("NUMINATION PRO ACTIVO", color = TerminalGreen, fontWeight = FontWeight.Black, fontSize = 13.sp)
                                    Text(
                                        proExpiresAt?.let { "Vence: ${it.take(10)}" } ?: "Acceso activado tras pago verificado",
                                        color = TextMuted,
                                        fontSize = 11.sp
                                    )
                                }
                            }
                        }
                    }
                }

                activePendingPayment?.let { payment ->
                    item {
                        GlassPanel(modifier = Modifier.fillMaxWidth(), accent = EditorYellow) {
                            Column(modifier = Modifier.padding(18.dp)) {
                                Row(verticalAlignment = Alignment.CenterVertically) {
                                    Icon(Icons.Filled.HourglassTop, contentDescription = null, tint = EditorYellow, modifier = Modifier.size(18.dp))
                                    Spacer(modifier = Modifier.width(8.dp))
                                    Text("Recarga pendiente de verificación", color = EditorYellow, fontWeight = FontWeight.Bold, fontSize = 14.sp)
                                }
                                Spacer(modifier = Modifier.height(10.dp))
                                Text(
                                    if (payment.planTier == "PRO") {
                                        "Tu acceso Pro se activa al confirmar este pago. Incluye este código en la nota de PayPal:"
                                    } else {
                                        "Incluye este código en la nota del pago de PayPal. Los créditos se añaden al confirmar:"
                                    },
                                    color = TextMuted, fontSize = 12.sp, lineHeight = 16.sp
                                )
                                Spacer(modifier = Modifier.height(10.dp))
                                Box(
                                    modifier = Modifier
                                        .fillMaxWidth()
                                        .clip(RoundedCornerShape(10.dp))
                                        .background(PrimaryObsidian.copy(alpha = 0.6f))
                                        .border(1.dp, EditorYellow.copy(alpha = 0.4f), RoundedCornerShape(10.dp))
                                        .padding(12.dp),
                                    contentAlignment = Alignment.Center
                                ) {
                                    Text(payment.referenceCode, color = EditorYellow, fontSize = 18.sp, fontWeight = FontWeight.Black, letterSpacing = 2.sp)
                                }
                            }
                        }
                    }
                }

                errorMessage?.let { msg ->
                    item { Text(msg, color = ErrorRed, fontSize = 12.5.sp, fontWeight = FontWeight.Medium) }
                }
                actionMessage?.let { msg ->
                    item { Text(msg, color = TerminalGreen, fontSize = 12.5.sp, fontWeight = FontWeight.Bold) }
                }

                item { SectionLabel("MÉTODOS DE PAGO") }

                item {
                    GlassPanel(modifier = Modifier.fillMaxWidth(), accent = Color(0xFF0070BA)) {
                        Row(modifier = Modifier.padding(16.dp).fillMaxWidth(), verticalAlignment = Alignment.CenterVertically) {
                            Icon(Icons.Filled.Payment, contentDescription = null, tint = Color(0xFF0070BA), modifier = Modifier.size(22.dp))
                            Spacer(modifier = Modifier.width(8.dp))
                            Text("PayPal", color = Color(0xFF0070BA), fontSize = 15.sp, fontWeight = FontWeight.Bold)
                            Spacer(modifier = Modifier.fillMaxWidth(0.65f))
                            Text("paypal.me/KraqPro · verificación manual", color = TextMuted, fontSize = 11.sp)
                        }
                    }
                }

                item { SectionLabel("PLANES Y CRÉDITOS") }

                // Bento tile: 2-column grid for the four one-time packs, full-width for the subscription
                item {
                    Column(verticalArrangement = Arrangement.spacedBy(10.dp)) {
                        packages.filter { !it.isSubscription }.chunked(2).forEach { row ->
                            Row(horizontalArrangement = Arrangement.spacedBy(10.dp)) {
                                row.forEach { pkg ->
                                    PackageBentoTile(
                                        pkg = pkg,
                                        modifier = Modifier.fillMaxWidth(0.49f),
                                        onClick = { selectedPackage = pkg; showPaymentDialog = true }
                                    )
                                }
                                if (row.size == 1) Spacer(modifier = Modifier.fillMaxWidth(0.65f))
                            }
                        }
                        packages.find { it.isSubscription }?.let { sub ->
                            PackageBentoTile(
                                pkg = sub,
                                modifier = Modifier.fillMaxWidth(),
                                onClick = { selectedPackage = sub; showPaymentDialog = true },
                                wide = true
                            )
                        }
                        if (!isLoading && packages.isEmpty()) {
                            Text("No hay planes disponibles ahora mismo.", color = TextMuted, fontSize = 13.sp)
                        }
                    }
                }

                item { SectionLabel("HISTORIAL DE TRANSACCIONES") }

                if (isLoading && historyLogs.isEmpty()) {
                    item {
                        Box(modifier = Modifier.fillMaxWidth(), contentAlignment = Alignment.Center) {
                            Text("Cargando…", color = ElectricCyan, fontSize = 14.sp, fontWeight = FontWeight.SemiBold)
                        }
                    }
                } else if (historyLogs.isEmpty()) {
                    item { Text("No se registran movimientos en tu cuenta.", color = TextMuted, fontSize = 13.sp) }
                } else {
                    items(historyLogs) { log ->
                        GlassPanel(modifier = Modifier.fillMaxWidth(), accent = if (log.amount > 0) TerminalGreen else ErrorRed) {
                            Row(
                                modifier = Modifier.padding(12.dp).fillMaxWidth(),
                                horizontalArrangement = Arrangement.SpaceBetween,
                                verticalAlignment = Alignment.CenterVertically
                            ) {
                                Column {
                                    Text(log.reason, color = TextLight, fontSize = 13.sp, fontWeight = FontWeight.SemiBold)
                                    Text(log.timestamp.take(16).replace("T", " "), color = TextMuted, fontSize = 10.sp)
                                }
                                Text(
                                    text = if (log.amount > 0) "+${log.amount} Pts" else "${log.amount} Pts",
                                    color = if (log.amount > 0) TerminalGreen else ErrorRed,
                                    fontWeight = FontWeight.Black,
                                    fontSize = 13.sp
                                )
                            }
                        }
                    }
                }
            }
        }
    }

    if (showPaymentDialog && selectedPackage != null) {
        val pkg = selectedPackage!!
        AlertDialog(
            onDismissRequest = { showPaymentDialog = false; selectedPackage = null },
            title = { Text("Confirmar Compra", color = TextLight, fontWeight = FontWeight.Bold) },
            text = {
                Column {
                    Text(pkg.title, color = ElectricCyan, fontSize = 18.sp, fontWeight = FontWeight.Bold, modifier = Modifier.padding(bottom = 8.dp))
                    Divider(color = BorderGray)
                    Spacer(modifier = Modifier.height(8.dp))
                    Row(modifier = Modifier.fillMaxWidth(), horizontalArrangement = Arrangement.SpaceBetween) {
                        Text("Puntos:", color = TextMuted)
                        Text("+${pkg.points} Pts", color = EditorYellow, fontWeight = FontWeight.Bold)
                    }
                    Spacer(modifier = Modifier.height(4.dp))
                    Row(modifier = Modifier.fillMaxWidth(), horizontalArrangement = Arrangement.SpaceBetween) {
                        Text("Precio:", color = TextMuted)
                        Text(pkg.priceLabel, color = ElectricCyan, fontWeight = FontWeight.Bold)
                    }
                    Spacer(modifier = Modifier.height(12.dp))
                    Text(
                        if (pkg.planTier == "PRO") {
                            "Crearemos tu referencia de pago. Tras verificar el pago, Numination activará Pro durante ${pkg.tierDurationDays} días y añadirá los créditos incluidos."
                        } else {
                            "Crearemos tu referencia de pago antes de abrir PayPal. Debes incluirla en la nota; un administrador confirma el pago antes de añadir créditos."
                        },
                        color = TextMuted, fontSize = 11.sp, textAlign = TextAlign.Center, modifier = Modifier.fillMaxWidth()
                    )
                }
            },
            confirmButton = {
                Button(
                    onClick = {
                        isLoading = true
                        showPaymentDialog = false
                        errorMessage = null
                        scope.launch(Dispatchers.IO) {
                            try {
                                val body = mapOf("packageId" to pkg.id)
                                val data = NetworkClient.post("/credits/recharge", body).use { response ->
                                    if (response.isSuccessful) {
                                        Gson().fromJson(response.body?.string(), RechargeRequestResponse::class.java)
                                    } else null
                                }
                                if (data != null) {
                                    withContext(Dispatchers.Main) {
                                        val pending = PendingPayment(
                                            referenceCode = data.referenceCode,
                                            priceLabel = data.priceLabel,
                                            planTier = data.planTier
                                        )
                                        activePendingPayment = pending
                                        paymentInstructions = PaymentInstructions(
                                            payment = pending,
                                            paypalUrl = data.paypalUrl ?: "https://paypal.me/KraqPro/${pkg.priceUsd}"
                                        )
                                        actionMessage = "Referencia creada. Copia el código antes de pagar."
                                        isLoading = false
                                    }
                                } else {
                                    withContext(Dispatchers.Main) {
                                        errorMessage = "No se pudo crear la solicitud de recarga. Inténtalo de nuevo."
                                        isLoading = false
                                    }
                                }
                            } catch (_: Exception) {
                                withContext(Dispatchers.Main) {
                                    errorMessage = "Error de red al crear la solicitud de recarga."
                                    isLoading = false
                                }
                            }
                        }
                        selectedPackage = null
                    },
                    colors = ButtonDefaults.buttonColors(containerColor = Color(0xFF0070BA)),
                    modifier = Modifier.fillMaxWidth()
                ) {
                    Icon(Icons.Filled.Payment, contentDescription = null, tint = Color.White, modifier = Modifier.size(18.dp))
                    Spacer(modifier = Modifier.width(8.dp))
                    Text("Pagar con PayPal", color = Color.White, fontWeight = FontWeight.Bold)
                }
            },
            dismissButton = {
                TextButton(onClick = { showPaymentDialog = false; selectedPackage = null }) {
                    Text("Cancelar", color = TextMuted)
                }
            },
            containerColor = SecondaryCard
        )
    }

    paymentInstructions?.let { instructions ->
        AlertDialog(
            onDismissRequest = { paymentInstructions = null },
            title = { Text("Paso final: pago PayPal", color = TextLight, fontWeight = FontWeight.Bold) },
            text = {
                Column(horizontalAlignment = Alignment.CenterHorizontally) {
                    Text("Incluye este código en la nota del pago:", color = TextMuted, fontSize = 12.sp)
                    Spacer(Modifier.height(12.dp))
                    Text(
                        instructions.payment.referenceCode,
                        color = EditorYellow,
                        fontSize = 22.sp,
                        fontWeight = FontWeight.Black,
                        letterSpacing = 2.sp
                    )
                    Spacer(Modifier.height(10.dp))
                    Text(
                        if (instructions.payment.planTier == "PRO") {
                            "Pro se activa después de que el pago sea verificado manualmente."
                        } else {
                            "Los créditos se añaden después de que el pago sea verificado manualmente."
                        },
                        color = TextMuted,
                        fontSize = 11.sp,
                        textAlign = TextAlign.Center
                    )
                }
            },
            confirmButton = {
                Button(
                    onClick = {
                        runCatching {
                            context.startActivity(Intent(Intent.ACTION_VIEW, Uri.parse(instructions.paypalUrl)))
                        }.onFailure {
                            errorMessage = "No se pudo abrir PayPal en este dispositivo."
                        }
                    },
                    colors = ButtonDefaults.buttonColors(containerColor = Color(0xFF0070BA))
                ) {
                    Icon(Icons.Filled.OpenInNew, contentDescription = null, modifier = Modifier.size(16.dp))
                    Spacer(Modifier.width(6.dp))
                    Text("Abrir PayPal")
                }
            },
            dismissButton = {
                Row {
                    TextButton(onClick = {
                        val clipboard = context.getSystemService(Context.CLIPBOARD_SERVICE) as ClipboardManager
                        clipboard.setPrimaryClip(ClipData.newPlainText("Código PayPal Numination", instructions.payment.referenceCode))
                        actionMessage = "Código de pago copiado."
                    }) {
                        Text("Copiar código", color = ElectricCyan)
                    }
                    TextButton(onClick = { paymentInstructions = null }) {
                        Text("Cerrar", color = TextMuted)
                    }
                }
            },
            containerColor = SecondaryCard
        )
    }
}

@Composable
private fun SectionLabel(text: String) {
    Text(text, color = TextLight, fontSize = 14.sp, fontWeight = FontWeight.Bold, letterSpacing = 0.5.sp)
}

private fun BillingPlan.toPaymentPackage() = PaymentPackage(
    id = id,
    title = title,
    points = credits,
    priceUsd = priceUsd,
    priceLabel = priceLabel,
    isSubscription = tier == "PRO",
    isBestValue = bestValue,
    planTier = tier,
    tierDurationDays = tierDurationDays
)

private fun PendingRecharge.toPendingPayment() = PendingPayment(
    referenceCode = reference_code,
    priceLabel = price_label,
    planTier = plan_tier
)

@Composable
private fun PackageBentoTile(
    pkg: PaymentPackage,
    modifier: Modifier = Modifier,
    onClick: () -> Unit,
    wide: Boolean = false
) {
    GlassPanel(
        modifier = modifier.clickable { onClick() },
        accent = if (pkg.isBestValue) EditorYellow else ElectricCyan
    ) {
        Column(modifier = Modifier.padding(14.dp).fillMaxWidth()) {
            if (pkg.isBestValue) {
                Box(
                    modifier = Modifier
                        .clip(RoundedCornerShape(6.dp))
                        .background(EditorYellow.copy(alpha = 0.18f))
                        .padding(horizontal = 6.dp, vertical = 2.dp)
                ) {
                    Text("MEJOR VALOR", color = EditorYellow, fontSize = 9.sp, fontWeight = FontWeight.Bold)
                }
                Spacer(modifier = Modifier.height(6.dp))
            }
            Text(pkg.title, color = TextLight, fontWeight = FontWeight.Bold, fontSize = 14.sp)
            Text(
                if (pkg.planTier == "PRO") {
                    "PRO · ${pkg.tierDurationDays ?: 30} días · +${pkg.points} Pts"
                } else {
                    "+${pkg.points} Pts"
                },
                color = TextMuted,
                fontSize = 11.sp
            )
            Spacer(modifier = Modifier.height(if (wide) 4.dp else 12.dp))
            Row(
                modifier = Modifier.fillMaxWidth(),
                horizontalArrangement = Arrangement.SpaceBetween,
                verticalAlignment = Alignment.CenterVertically
            ) {
                Text(pkg.priceLabel, color = ElectricCyan, fontWeight = FontWeight.Black, fontSize = 14.sp)
                Icon(Icons.Filled.ShoppingCart, contentDescription = "Comprar", tint = ElectricCyan, modifier = Modifier.size(16.dp))
            }
        }
    }
}
