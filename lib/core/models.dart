class AppUser {
  final String id;
  final String email;
  final String role;
  final String tier;
  final int balance;
  final String? proExpiresAt;
  const AppUser({required this.id, required this.email, required this.role, required this.tier, required this.balance, this.proExpiresAt});

  factory AppUser.fromJson(Map<String, dynamic> json) => AppUser(
        id: '${json['id'] ?? ''}',
        email: '${json['email'] ?? ''}',
        role: '${json['role'] ?? 'USER'}',
        tier: '${json['tier'] ?? 'FREE'}',
        balance: (json['balance'] as num?)?.toInt() ?? 0,
        proExpiresAt: json['proExpiresAt']?.toString(),
      );
}

class Project {
  final String id;
  final String name;
  final String description;
  final String createdAt;
  final String updatedAt;
  const Project({required this.id, required this.name, required this.description, required this.createdAt, required this.updatedAt});
  factory Project.fromJson(Map<String, dynamic> json) => Project(
        id: '${json['id'] ?? ''}', name: '${json['name'] ?? ''}', description: '${json['description'] ?? ''}',
        createdAt: '${json['created_at'] ?? json['createdAt'] ?? ''}', updatedAt: '${json['updated_at'] ?? json['updatedAt'] ?? ''}',
      );
}

class FileItem {
  final String id;
  final String projectId;
  final String name;
  final String path;
  final bool isDirectory;
  final String content;
  final String? parentId;
  const FileItem({required this.id, required this.projectId, required this.name, required this.path, required this.isDirectory, required this.content, this.parentId});
  factory FileItem.fromJson(Map<String, dynamic> json) => FileItem(
        id: '${json['id'] ?? ''}', projectId: '${json['project_id'] ?? json['projectId'] ?? ''}', name: '${json['name'] ?? ''}',
        path: '${json['path'] ?? ''}', isDirectory: json['is_directory'] == 1 || json['is_directory'] == true || json['isDirectory'] == true,
        content: '${json['content'] ?? ''}', parentId: json['parent_id']?.toString() ?? json['parentId']?.toString(),
      );
}

class ChatAction {
  final String type;
  final String? path;
  final String? content;
  final String? command;
  final String description;
  const ChatAction({required this.type, this.path, this.content, this.command, required this.description});
  factory ChatAction.fromJson(Map<String, dynamic> json) => ChatAction(
        type: '${json['type'] ?? ''}', path: json['path']?.toString(), content: json['content']?.toString(), command: json['command']?.toString(), description: '${json['description'] ?? ''}',
      );
}

class ChatResponse {
  final bool success;
  final String mode;
  final String response;
  final List<ChatAction> actions;
  final int remainingCredits;
  final String timestamp;
  const ChatResponse({required this.success, required this.mode, required this.response, required this.actions, required this.remainingCredits, required this.timestamp});
  factory ChatResponse.fromJson(Map<String, dynamic> json) => ChatResponse(
        success: json['success'] == true, mode: '${json['mode'] ?? 'chat'}', response: '${json['response'] ?? ''}',
        actions: ((json['actions'] as List?) ?? const []).map((e) => ChatAction.fromJson(Map<String, dynamic>.from(e as Map))).toList(),
        remainingCredits: (json['remainingCredits'] as num?)?.toInt() ?? 0, timestamp: '${json['timestamp'] ?? ''}',
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
  const BillingPlan({required this.id, required this.title, required this.credits, required this.priceUsd, required this.priceLabel, this.bestValue = false, this.tier, this.tierDurationDays});
  factory BillingPlan.fromJson(Map<String, dynamic> json) => BillingPlan(
        id: '${json['id'] ?? ''}', title: '${json['title'] ?? ''}', credits: (json['credits'] as num?)?.toInt() ?? 0,
        priceUsd: '${json['priceUsd'] ?? ''}', priceLabel: '${json['priceLabel'] ?? ''}', bestValue: json['bestValue'] == true,
        tier: json['tier']?.toString(), tierDurationDays: (json['tierDurationDays'] as num?)?.toInt(),
      );
}

class CreditLog {
  final String id;
  final int amount;
  final String reason;
  final String timestamp;
  const CreditLog({required this.id, required this.amount, required this.reason, required this.timestamp});
  factory CreditLog.fromJson(Map<String, dynamic> json) => CreditLog(id: '${json['id'] ?? ''}', amount: (json['amount'] as num?)?.toInt() ?? 0, reason: '${json['reason'] ?? ''}', timestamp: '${json['timestamp'] ?? ''}');
}

class MemoryItem {
  final String id;
  final String title;
  final String content;
  final String type;
  final String? projectId;
  final bool pinned;
  final String createdAt;
  const MemoryItem({required this.id, required this.title, required this.content, required this.type, this.projectId, required this.pinned, required this.createdAt});
  factory MemoryItem.fromJson(Map<String, dynamic> json) => MemoryItem(id: '${json['id'] ?? ''}', title: '${json['title'] ?? ''}', content: '${json['content'] ?? ''}', type: '${json['type'] ?? 'PROJECT'}', projectId: json['projectId']?.toString(), pinned: json['pinned'] == true, createdAt: '${json['createdAt'] ?? ''}');
}
