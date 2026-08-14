package com.wren.ide.core.network

// User details
data class User(
    val id: String,
    val email: String,
    val role: String,
    val tier: String,
    val balance: Int
)

// Project model
data class Project(
    val id: String,
    val name: String,
    val description: String,
    val created_at: String,
    val updated_at: String
)

// List projects response
data class ProjectListResponse(
    val projects: List<Project>
)

// Files and Directories representation
data class FileItem(
    val id: String,
    val project_id: String,
    val name: String,
    val path: String,
    val is_directory: Int, // 0 for file, 1 for directory
    val content: String?,
    val parent_id: String?
)

// File tree data structure
data class ProjectFilesResponse(
    val project: Project,
    val files: List<FileItem>
)

// AI Action details
data class ChatAction(
    val type: String, // CREATE_FILE, EDIT_FILE, EXECUTE_COMMAND
    val path: String?,
    val content: String?,
    val command: String?,
    val description: String
)

// AI Assistant response payload
data class ChatResponse(
    val success: Boolean,
    val mode: String,
    val response: String,
    val actions: List<ChatAction>?,
    val remainingCredits: Int,
    val timestamp: String
)

// Balance status check
data class CreditBalanceResponse(
    val userId: String,
    val balance: Int,
    val updatedAt: String
)

// Credit transactions statement record
data class CreditLog(
    val id: String,
    val user_id: String,
    val amount: Int,
    val reason: String,
    val timestamp: String
)

data class CreditHistoryResponse(
    val logs: List<CreditLog>
)

// Response from POST /credits/recharge -- a pending request, not an instant credit
data class RechargeRequestResponse(
    val message: String,
    val requestId: String,
    val referenceCode: String,
    val credits: Int,
    val priceLabel: String,
    val planTier: String? = null,
    val tierDurationDays: Int? = null,
    val paypalUrl: String? = null,
    val status: String
)

data class BillingPlan(
    val id: String,
    val title: String,
    val credits: Int,
    val priceUsd: String,
    val priceLabel: String,
    val bestValue: Boolean = false,
    val tier: String? = null,
    val tierDurationDays: Int? = null
)

data class CreditsOverviewResponse(
    val balance: Int = 0,
    val tier: String = "FREE",
    val proExpiresAt: String? = null,
    val paypalMeUrl: String = "",
    val plans: List<BillingPlan> = emptyList(),
    val pending: List<PendingRecharge> = emptyList()
)

// Security auditing record
data class AuditLog(
    val id: String,
    val action: String,
    val details: String?,
    val timestamp: String,
    val actor_email: String
)

data class AuditLogsResponse(
    val logs: List<AuditLog>
)

// Owner server health and metrics
data class ServerMetrics(
    val totalUsers: Int,
    val totalProjects: Int,
    val circulatingCredits: Int,
    val historicalSpentCredits: Int,
    val auditLogsLogged: Int,
    val serverUptime: Double
)

data class ServerStatsResponse(
    val metrics: ServerMetrics
)

// Pending PayPal recharge awaiting owner verification
data class PendingRecharge(
    val id: String,
    val package_id: String,
    val credit_amount: Int,
    val price_label: String,
    val plan_tier: String? = null,
    val tier_duration_days: Int? = null,
    val reference_code: String,
    val status: String,
    val created_at: String,
    val user_email: String,
    val user_id: String
)

data class PendingRechargesResponse(
    val requests: List<PendingRecharge>
)

// GET /owner/users response
data class UsersListResponse(
    val users: List<User>
)


// App version metadata
data class AppVersionResponse(
    val ok: Boolean,
    val platform: String,
    val version: String,
    val downloadUrl: String,
    val notes: String?,
    val mandatory: Boolean,
    val supportedLanguages: List<String> = emptyList()
)
