import 'package:flutter/material.dart';

class AppUser {
  final String id;
  final String email;
  final String role;
  final String tier;
  final int balance;
  final String? proExpiresAt;
  final String? displayName;
  final String? pronouns;
  final String? avatarUrl;
  const AppUser({
    required this.id,
    required this.email,
    required this.role,
    required this.tier,
    required this.balance,
    this.proExpiresAt,
    this.displayName,
    this.pronouns,
    this.avatarUrl,
  });

  factory AppUser.fromJson(Map<String, dynamic> json) => AppUser(
    id: '${json['id'] ?? ''}',
    email: '${json['email'] ?? ''}',
    role: '${json['role'] ?? 'USER'}',
    tier: '${json['tier'] ?? 'FREE'}',
    balance: (json['balance'] as num?)?.toInt() ?? 0,
    proExpiresAt: json['proExpiresAt']?.toString(),
    displayName: json['displayName']?.toString(),
    pronouns: json['pronouns']?.toString(),
    avatarUrl: json['avatarUrl']?.toString(),
  );
}

class Project {
  final String id;
  final String name;
  final String description;
  final String createdAt;
  final String updatedAt;
  const Project({
    required this.id,
    required this.name,
    required this.description,
    required this.createdAt,
    required this.updatedAt,
  });
  factory Project.fromJson(Map<String, dynamic> json) => Project(
    id: '${json['id'] ?? ''}',
    name: '${json['name'] ?? ''}',
    description: '${json['description'] ?? ''}',
    createdAt: '${json['created_at'] ?? json['createdAt'] ?? ''}',
    updatedAt: '${json['updated_at'] ?? json['updatedAt'] ?? ''}',
  );
}

class ArtifactItem {
  final String id;
  final String? chatId;
  final String title;
  final String kind; // 'snippet' (código/texto) o 'file' (archivo adjunto)
  final String language;
  final String content;
  final String? storagePath;
  final String? mimeType;
  final int? sizeBytes;
  final String createdAt;
  const ArtifactItem({
    required this.id,
    this.chatId,
    required this.title,
    required this.kind,
    required this.language,
    required this.content,
    this.storagePath,
    this.mimeType,
    this.sizeBytes,
    required this.createdAt,
  });
  factory ArtifactItem.fromJson(Map<String, dynamic> json) => ArtifactItem(
    id: '${json['id'] ?? ''}',
    chatId: json['chatId']?.toString(),
    title: '${json['title'] ?? 'Sin título'}',
    kind: '${json['kind'] ?? 'snippet'}',
    language: '${json['language'] ?? 'plaintext'}',
    content: '${json['content'] ?? ''}',
    storagePath: json['storagePath']?.toString(),
    mimeType: json['mimeType']?.toString(),
    sizeBytes: (json['sizeBytes'] as num?)?.toInt(),
    createdAt: '${json['createdAt'] ?? ''}',
  );

  bool get isFile => kind == 'file';
}

/// Un modo de IA (Chat, Coder, o cualquiera que agregues después) tal como
/// lo define el backend en la tabla AiMode. La app YA NO tiene una lista
/// hardcodeada de modos: los pide con GET /modes al iniciar, así que un modo
/// nuevo agregado en Supabase aparece en la app sin recompilar ni publicar
/// una nueva versión.
class AiModeConfig {
  final String id;
  final String label;
  final String iconName;
  final String description;
  final bool requiresPro;
  final int sortOrder;
  const AiModeConfig({
    required this.id,
    required this.label,
    required this.iconName,
    required this.description,
    required this.requiresPro,
    required this.sortOrder,
  });
  factory AiModeConfig.fromJson(Map<String, dynamic> json) => AiModeConfig(
    id: '${json['id'] ?? 'chat'}',
    label: '${json['label'] ?? json['id'] ?? 'Chat'}',
    iconName: '${json['iconName'] ?? 'chat_bubble_outline'}',
    description: '${json['description'] ?? ''}',
    requiresPro: json['requiresPro'] == true,
    sortOrder: (json['sortOrder'] as num?)?.toInt() ?? 0,
  );

  /// Íconos conocidos por nombre. Si el backend manda un iconName que no
  /// está en este mapa (porque agregaste un modo nuevo y no actualizaste
  /// la app), cae de vuelta a un ícono genérico en vez de romper.
  IconData get icon => _iconByName[iconName] ?? Icons.auto_awesome;

  static const Map<String, IconData> _iconByName = {
    'chat_bubble_outline': Icons.chat_bubble_outline,
    'code': Icons.code_rounded,
    'search': Icons.search_rounded,
    'bug_report': Icons.bug_report_outlined,
    'auto_awesome': Icons.auto_awesome,
    'lightbulb': Icons.lightbulb_outline,
  };
}

class FileItem {
  final String id;
  final String projectId;
  final String name;
  final String path;
  final bool isDirectory;
  final String content;
  final String? parentId;
  const FileItem({
    required this.id,
    required this.projectId,
    required this.name,
    required this.path,
    required this.isDirectory,
    required this.content,
    this.parentId,
  });
  factory FileItem.fromJson(Map<String, dynamic> json) => FileItem(
    id: '${json['id'] ?? ''}',
    projectId: '${json['project_id'] ?? json['projectId'] ?? ''}',
    name: '${json['name'] ?? ''}',
    path: '${json['path'] ?? ''}',
    isDirectory:
        json['is_directory'] == 1 ||
        json['is_directory'] == true ||
        json['isDirectory'] == true,
    content: '${json['content'] ?? ''}',
    parentId: json['parent_id']?.toString() ?? json['parentId']?.toString(),
  );
}

class ChatAction {
  final String type;
  final String? path;
  final String? content;
  final String? command;
  final String description;
  const ChatAction({
    required this.type,
    this.path,
    this.content,
    this.command,
    required this.description,
  });
  factory ChatAction.fromJson(Map<String, dynamic> json) => ChatAction(
    type: '${json['type'] ?? ''}',
    path: json['path']?.toString(),
    content: json['content']?.toString(),
    command: json['command']?.toString(),
    description: '${json['description'] ?? ''}',
  );
}

class ChatResponse {
  final bool success;
  final String mode;
  final String response;
  final List<ChatAction> actions;
  final int remainingCredits;
  final String timestamp;
  const ChatResponse({
    required this.success,
    required this.mode,
    required this.response,
    required this.actions,
    required this.remainingCredits,
    required this.timestamp,
  });
  factory ChatResponse.fromJson(Map<String, dynamic> json) => ChatResponse(
    success: json['success'] == true,
    mode: '${json['mode'] ?? 'chat'}',
    response: '${json['response'] ?? ''}',
    actions: ((json['actions'] as List?) ?? const [])
        .map((e) => ChatAction.fromJson(Map<String, dynamic>.from(e as Map)))
        .toList(),
    remainingCredits: (json['remainingCredits'] as num?)?.toInt() ?? 0,
    timestamp: '${json['timestamp'] ?? ''}',
  );
}

class BillingPlan {
  final String id;
  final String title;
  final int credits;
  final String priceUsd;
  final String priceLabel;
  final bool bestValue;
  final String? tier;
  final int? tierDurationDays;
  const BillingPlan({
    required this.id,
    required this.title,
    required this.credits,
    required this.priceUsd,
    required this.priceLabel,
    this.bestValue = false,
    this.tier,
    this.tierDurationDays,
  });
  factory BillingPlan.fromJson(Map<String, dynamic> json) => BillingPlan(
    id: '${json['id'] ?? ''}',
    title: '${json['title'] ?? ''}',
    credits: (json['credits'] as num?)?.toInt() ?? 0,
    priceUsd: '${json['priceUsd'] ?? ''}',
    priceLabel: '${json['priceLabel'] ?? ''}',
    bestValue: json['bestValue'] == true,
    tier: json['tier']?.toString(),
    tierDurationDays: (json['tierDurationDays'] as num?)?.toInt(),
  );
}

class CreditLog {
  final String id;
  final int amount;
  final String reason;
  final String timestamp;
  const CreditLog({
    required this.id,
    required this.amount,
    required this.reason,
    required this.timestamp,
  });
  factory CreditLog.fromJson(Map<String, dynamic> json) => CreditLog(
    id: '${json['id'] ?? ''}',
    amount: (json['amount'] as num?)?.toInt() ?? 0,
    reason: '${json['reason'] ?? ''}',
    timestamp: '${json['timestamp'] ?? ''}',
  );
}

/// Shared enum for the app's assistant mode. Lives here (instead of inside
/// home_screen.dart) so both home_screen.dart and hamburger.dart can use it
/// without importing each other.
// ChatMode (enum fijo chat/coder) fue reemplazado por AiModeConfig, que se
// carga dinámicamente desde GET /modes. Ver la clase AiModeConfig arriba.

class ChatSession {
  final String id;
  final String title;
  final String mode;
  final bool isGhost;
  final String createdAt;
  final String updatedAt;
  const ChatSession({
    required this.id,
    required this.title,
    required this.mode,
    required this.isGhost,
    required this.createdAt,
    required this.updatedAt,
  });
  factory ChatSession.fromJson(Map<String, dynamic> json) => ChatSession(
    id: '${json['id'] ?? ''}',
    title: '${json['title'] ?? 'Nuevo chat'}',
    mode: '${json['mode'] ?? 'chat'}',
    isGhost: json['isGhost'] == true,
    createdAt: '${json['createdAt'] ?? ''}',
    updatedAt: '${json['updatedAt'] ?? ''}',
  );
}

class ChatMessageDto {
  final String id;
  final String chatId;
  final String role;
  final String content;
  final String createdAt;
  const ChatMessageDto({
    required this.id,
    required this.chatId,
    required this.role,
    required this.content,
    required this.createdAt,
  });
  factory ChatMessageDto.fromJson(Map<String, dynamic> json) => ChatMessageDto(
    id: '${json['id'] ?? ''}',
    chatId: '${json['chatId'] ?? ''}',
    role: '${json['role'] ?? 'user'}',
    content: '${json['content'] ?? ''}',
    createdAt: '${json['createdAt'] ?? ''}',
  );
}

class MemoryItem {
  final String id;
  final String title;
  final String content;
  final String type;
  final String? projectId;
  final bool pinned;
  final String createdAt;
  const MemoryItem({
    required this.id,
    required this.title,
    required this.content,
    required this.type,
    this.projectId,
    required this.pinned,
    required this.createdAt,
  });
  factory MemoryItem.fromJson(Map<String, dynamic> json) => MemoryItem(
    id: '${json['id'] ?? ''}',
    title: '${json['title'] ?? ''}',
    content: '${json['content'] ?? ''}',
    type: '${json['type'] ?? 'PROJECT'}',
    projectId: json['projectId']?.toString(),
    pinned: json['pinned'] == true,
    createdAt: '${json['createdAt'] ?? ''}',
  );
}
