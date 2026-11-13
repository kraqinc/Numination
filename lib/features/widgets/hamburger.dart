import 'package:flutter/material.dart';
import 'package:lucide_flutter/lucide_flutter.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../core/api.dart';
import '../../core/error_messages.dart';
import '../../core/auth_controller.dart';
import '../../core/l10n_extensions.dart';
import '../../core/models.dart' show AiModeConfig, ChatSession, Project;
import '../../core/theme_controller.dart';
import '../screens/artifacts_screen.dart';
import '../screens/connectors_screen.dart';
import '../screens/credits_hub_screen.dart';
import '../screens/notification_screen.dart';
import '../screens/projects_screen.dart';
import '../screens/settings_screen.dart';
import 'package:numination/core/numi_icons.dart';
import 'numi_loading_animation.dart';

class AppDrawer extends ConsumerStatefulWidget {
  const AppDrawer({
    super.key,
    required this.email,
    required this.avatarUrl,
    required this.chatRevision,
    required this.modeId,
    required this.availableModes,
    required this.onSelectMode,
    required this.onSelectChat,
    required this.onNewChat,
    required this.onChatDeleted,
  });

  final String email;
  final String? avatarUrl;
  final int chatRevision;
  final String modeId;
  final List<AiModeConfig> availableModes;
  final ValueChanged<String> onSelectMode;
  final ValueChanged<ChatSession> onSelectChat;
  final VoidCallback onNewChat;
  final ValueChanged<ChatSession> onChatDeleted;

  @override
  ConsumerState<AppDrawer> createState() => _AppDrawerState();
}

class _AppDrawerState extends ConsumerState<AppDrawer> {
  bool _isLoading = true;
  List<ChatSession> _chats = [];
  String? _resolvedAvatarUrl;
  int? _creditBalance;
  bool _creditsLoading = true;

  @override
  void initState() {
    super.initState();
    _resolvedAvatarUrl = widget.avatarUrl;
    _loadProfile();
    _loadChats();
    _loadCredits();
  }

  Future<void> _loadCredits() async {
    try {
      final response = await ApiClient.get('/credits');
      final data = ApiClient.decode(response);
      final raw = data is Map ? data['balance'] : null;
      if (raw is! num || !raw.isFinite || raw < 0) {
        throw const FormatException('Invalid credits balance');
      }
      if (!mounted) return;
      setState(() {
        _creditBalance = raw.toInt();
        _creditsLoading = false;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _creditBalance = null;
        _creditsLoading = false;
      });
    }
  }

  String _formatCreditBalance(int value) {
    final separator = AppErrorMessages.isEnglish ? ',' : '.';
    return value.toString().replaceAllMapped(
      RegExp(r'\B(?=(\d{3})+(?!\d))'),
      (_) => separator,
    );
  }

  @override
  void didUpdateWidget(covariant AppDrawer oldWidget) {
    super.didUpdateWidget(oldWidget);

    if (oldWidget.chatRevision != widget.chatRevision) {
      _loadChats();
    }

    if (oldWidget.avatarUrl != widget.avatarUrl) {
      _resolvedAvatarUrl = widget.avatarUrl;
    }
  }

  Future<void> _loadProfile() async {
    String? avatarUrl;

    try {
      final response = await ApiClient.get('/auth/me');
      final data = ApiClient.decode(response) as Map<String, dynamic>;
      final user = data['user'];

      if (user is Map) {
        avatarUrl = user['avatarUrl']?.toString();
      }
    } catch (_) {}

    final metadata =
        Supabase.instance.client.auth.currentUser?.userMetadata ?? {};

    avatarUrl ??=
        metadata['avatarUrl']?.toString() ?? metadata['avatar_url']?.toString();

    avatarUrl ??= widget.avatarUrl;

    if (!mounted) return;

    setState(() {
      _resolvedAvatarUrl = avatarUrl;
    });
  }

  Future<void> _loadChats() async {
    try {
      final response = await ApiClient.get('/chats');
      final data = ApiClient.decode(response) as Map<String, dynamic>;
      final list = (data['chats'] as List? ?? [])
          .map((e) => ChatSession.fromJson(Map<String, dynamic>.from(e as Map)))
          .toList();
      if (mounted) {
        setState(() {
          _chats = list;
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _showChatActions(ChatSession chat) async {
    final palette = ref.read(appPaletteProvider);

    final action = await showModalBottomSheet<String>(
      context: context,
      backgroundColor: palette.surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (sheetContext) {
        return SafeArea(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(8, 12, 8, 12),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  width: 40,
                  height: 4,
                  decoration: BoxDecoration(
                    color: palette.border,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
                const SizedBox(height: 10),
                ListTile(
                  leading: Icon(NumiIcons.pencil, color: palette.textPrimary),
                  title: Text(
                    'Cambiar nombre',
                    style: TextStyle(color: palette.textPrimary),
                  ),
                  onTap: () => Navigator.of(sheetContext).pop('rename'),
                ),
                ListTile(
                  leading: Icon(NumiIcons.folder, color: palette.textPrimary),
                  title: Text(
                    'Mover a proyecto',
                    style: TextStyle(color: palette.textPrimary),
                  ),
                  onTap: () => Navigator.of(sheetContext).pop('move'),
                ),
                ListTile(
                  leading: Icon(
                    NumiIcons.delete_outline,
                    color: Colors.redAccent,
                  ),
                  title: const Text(
                    'Eliminar',
                    style: TextStyle(color: Colors.redAccent),
                  ),
                  onTap: () => Navigator.of(sheetContext).pop('delete'),
                ),
              ],
            ),
          ),
        );
      },
    );

    if (!mounted || action == null) return;

    switch (action) {
      case 'rename':
        await _renameChat(chat);
        break;
      case 'move':
        await _moveChat(chat);
        break;
      case 'delete':
        await _deleteChat(chat);
        break;
    }
  }

  Future<void> _renameChat(ChatSession chat) async {
    final palette = ref.read(appPaletteProvider);
    final controller = TextEditingController(text: chat.title);

    final title = await showDialog<String>(
      context: context,
      builder: (dialogContext) {
        return AlertDialog(
          backgroundColor: palette.surface,
          title: Text(
            'Cambiar nombre',
            style: TextStyle(color: palette.textPrimary),
          ),
          content: TextField(
            controller: controller,
            autofocus: true,
            maxLength: 100,
            style: TextStyle(color: palette.textPrimary),
            decoration: InputDecoration(
              hintText: 'Nombre del chat',
              hintStyle: TextStyle(color: palette.textSecondary),
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(dialogContext).pop(),
              child: Text(
                'Cancelar',
                style: TextStyle(color: palette.textSecondary),
              ),
            ),
            TextButton(
              onPressed: () =>
                  Navigator.of(dialogContext).pop(controller.text.trim()),
              child: Text('Guardar', style: TextStyle(color: palette.accent)),
            ),
          ],
        );
      },
    );

    controller.dispose();

    if (!mounted || title == null || title.isEmpty) return;

    try {
      final encodedId = Uri.encodeComponent(chat.id);

      await ApiClient.patch('/chats/$encodedId', {'title': title});

      await _loadChats();
    } catch (e) {
      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            e is ApiException
                ? e.message
                : 'No se pudo cambiar el nombre del chat',
          ),
        ),
      );
    }
  }

  Future<void> _moveChat(ChatSession chat) async {
    final palette = ref.read(appPaletteProvider);

    try {
      final response = await ApiClient.get('/projects');
      final data = ApiClient.decode(response) as Map<String, dynamic>;

      final projects = (data['projects'] as List? ?? [])
          .map((e) => Project.fromJson(Map<String, dynamic>.from(e as Map)))
          .toList();

      if (!mounted) return;

      final selected = await showModalBottomSheet<String?>(
        context: context,
        backgroundColor: palette.surface,
        shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
        ),
        builder: (sheetContext) {
          return SafeArea(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Padding(
                  padding: const EdgeInsets.fromLTRB(20, 18, 20, 12),
                  child: Align(
                    alignment: Alignment.centerLeft,
                    child: Text(
                      'Mover a proyecto',
                      style: TextStyle(
                        color: palette.textPrimary,
                        fontSize: 18,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                ),
                ListTile(
                  leading: Icon(NumiIcons.close, color: palette.textSecondary),
                  title: Text(
                    'Sin proyecto',
                    style: TextStyle(color: palette.textPrimary),
                  ),
                  onTap: () => Navigator.of(sheetContext).pop(''),
                ),
                ...projects.map(
                  (project) => ListTile(
                    leading: Icon(NumiIcons.folder, color: palette.accent),
                    title: Text(
                      project.name,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(color: palette.textPrimary),
                    ),
                    onTap: () => Navigator.of(sheetContext).pop(project.id),
                  ),
                ),
                const SizedBox(height: 8),
              ],
            ),
          );
        },
      );

      if (!mounted || selected == null) return;

      final encodedId = Uri.encodeComponent(chat.id);

      await ApiClient.patch('/chats/$encodedId', {
        'projectId': selected.isEmpty ? null : selected,
      });

      await _loadChats();
    } catch (e) {
      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            e is ApiException ? e.message : 'No se pudo mover el chat',
          ),
        ),
      );
    }
  }

  Future<void> _deleteChat(ChatSession chat) async {
    final palette = ref.read(appPaletteProvider);

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) {
        return AlertDialog(
          backgroundColor: palette.surface,
          title: Text(
            'Eliminar chat',
            style: TextStyle(color: palette.textPrimary),
          ),
          content: Text(
            'Esta conversación y sus mensajes se eliminarán permanentemente.',
            style: TextStyle(color: palette.textSecondary, height: 1.4),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(dialogContext).pop(false),
              child: Text(
                'Cancelar',
                style: TextStyle(color: palette.textSecondary),
              ),
            ),
            TextButton(
              onPressed: () => Navigator.of(dialogContext).pop(true),
              child: const Text(
                'Eliminar',
                style: TextStyle(
                  color: Colors.redAccent,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
          ],
        );
      },
    );

    if (confirmed != true || !mounted) return;

    try {
      final encodedId = Uri.encodeComponent(chat.id);

      await ApiClient.delete('/chats/$encodedId');

      widget.onChatDeleted(chat);

      await _loadChats();
    } catch (e) {
      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            e is ApiException ? e.message : 'No se pudo eliminar el chat',
          ),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final palette = ref.watch(appPaletteProvider);
    final english = AppErrorMessages.isEnglish;
    final username = widget.email.isNotEmpty
        ? widget.email.split('@').first
        : 'Usuario';

    return Drawer(
      backgroundColor: palette.surface,
      child: SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(14, 12, 14, 14),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                padding: const EdgeInsets.fromLTRB(10, 10, 6, 10),
                decoration: BoxDecoration(
                  color: palette.surfaceAlt,
                  borderRadius: BorderRadius.circular(18),
                  border: Border.all(color: palette.border),
                ),
                child: Row(
                  children: [
                    InkWell(
                      borderRadius: BorderRadius.circular(22),
                      onTap: () {
                        Navigator.of(context).pop();
                        Navigator.of(context).push(
                          MaterialPageRoute(builder: (_) => const SettingsScreen()),
                        );
                      },
                      child: CircleAvatar(
                        radius: 20,
                        backgroundColor: palette.surface,
                        backgroundImage: _resolvedAvatarUrl != null
                            ? NetworkImage(_resolvedAvatarUrl!)
                            : null,
                        child: _resolvedAvatarUrl == null
                            ? Icon(NumiIcons.person, size: 19, color: palette.textSecondary)
                            : null,
                      ),
                    ),
                    const SizedBox(width: 11),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            username,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                              color: palette.textPrimary,
                              fontSize: 15,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                          if (widget.email.isNotEmpty)
                            Text(
                              widget.email,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: TextStyle(
                                color: palette.textSecondary,
                                fontSize: 11,
                              ),
                            ),
                        ],
                      ),
                    ),
                    IconButton(
                      tooltip: english ? 'Sign out' : 'Cerrar sesión',
                      onPressed: () async {
                        await ref.read(authControllerProvider.notifier).signOut();
                      },
                      icon: Icon(NumiIcons.logout, color: palette.textSecondary, size: 19),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 11),

              Material(
                color: palette.surfaceAlt,
                borderRadius: BorderRadius.circular(14),
                child: InkWell(
                  borderRadius: BorderRadius.circular(14),
                  onTap: () {
                    Navigator.of(context).pop();
                    widget.onNewChat();
                  },
                  child: Padding(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 9,
                    ),
                    child: Row(
                      children: [
                        Container(
                          width: 32,
                          height: 32,
                          decoration: BoxDecoration(
                            color: palette.accent.withValues(alpha: 0.13),
                            borderRadius: BorderRadius.circular(10),
                          ),
                          child: Icon(
                            NumiIcons.add,
                            color: palette.accent,
                            size: 19,
                          ),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Text(
                            english ? 'New chat' : 'Nuevo chat',
                            style: TextStyle(
                              color: palette.textPrimary,
                              fontSize: 13,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
                        Icon(
                          LucideIcons.chevronRight,
                          size: 16,
                          color: palette.textSecondary,
                        ),
                      ],
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 8),
              _DrawerItem(
                icon: NumiIcons.folder_copy_outlined,
                label: context.l10n.projects,
                color: palette.textPrimary,
                onTap: () {
                  Navigator.of(context).pop();
                  Navigator.of(context).push(
                    MaterialPageRoute(builder: (_) => ProjectsScreen(onOpenChat: widget.onSelectChat)),
                  );
                },
              ),
              const SizedBox(height: 4),
              _DrawerItem(
                icon: NumiIcons.description_outlined,
                label: context.l10n.artifacts,
                color: palette.textPrimary,
                onTap: () {
                  Navigator.of(context).pop();
                  Navigator.of(context).push(MaterialPageRoute(builder: (_) => const ArtifactsScreen()));
                },
              ),
              const SizedBox(height: 4),
              _DrawerItem(
                icon: NumiIcons.power_off_outlined,
                label: context.l10n.connectors,
                color: palette.textPrimary,
                onTap: () {
                  Navigator.of(context).pop();
                  Navigator.of(context).push(MaterialPageRoute(builder: (_) => const ConnectorsScreen()));
                },
              ),
              const SizedBox(height: 4),
              _DrawerItem(
                icon: NumiIcons.notifications_outlined,
                label: context.l10n.notifications,
                color: palette.textPrimary,
                onTap: () {
                  Navigator.of(context).pop();
                  Navigator.of(context).push(MaterialPageRoute(builder: (_) => const NotificationScreen()));
                },
              ),
              const SizedBox(height: 4),
              _DrawerItem(
                icon: LucideIcons.creditCard,
                label: english ? 'Credits' : 'Créditos',
                color: palette.textPrimary,
                trailing: _creditsLoading
                    ? const SizedBox(width: 15, height: 15, child: CircularProgressIndicator(strokeWidth: 2))
                    : _creditBalance == null
                        ? null
                        : Text(
                            _formatCreditBalance(_creditBalance!),
                            style: TextStyle(color: palette.accent, fontSize: 13, fontWeight: FontWeight.w700),
                          ),
                onTap: () {
                  final navigator = Navigator.of(context);
                  navigator.pop();
                  navigator.push(MaterialPageRoute(builder: (_) => const CreditsHubScreen()));
                },
              ),
              Padding(
                padding: const EdgeInsets.only(top: 8, bottom: 8),
                child: Divider(color: palette.border, height: 1),
              ),
              Row(
                children: [
                  Expanded(
                    child: Text(
                      english ? 'Chats' : 'Chats',
                      style: TextStyle(color: palette.textPrimary, fontSize: 16, fontWeight: FontWeight.w700),
                    ),
                  ),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    decoration: BoxDecoration(color: palette.surfaceAlt, borderRadius: BorderRadius.circular(20)),
                    child: Text('${_chats.length}', style: TextStyle(color: palette.textSecondary, fontSize: 11, fontWeight: FontWeight.w700)),
                  ),
                  const SizedBox(width: 8),
                  ModePillDropdown(
                    modeId: widget.modeId,
                    availableModes: widget.availableModes,
                    onSelectMode: widget.onSelectMode,
                  ),
                ],
              ),
              const SizedBox(height: 9),
              Expanded(
                child: _isLoading
                    ? Center(child: NumiLoadingAnimation())
                    : _chats.isEmpty
                        ? Center(
                            child: Text(
                              context.l10n.noResults,
                              style: TextStyle(color: palette.textSecondary, fontSize: 13),
                            ),
                          )
                        : ListView.separated(
                            padding: const EdgeInsets.only(bottom: 8),
                            itemCount: _chats.length,
                            separatorBuilder: (_, _) => const SizedBox(height: 4),
                            itemBuilder: (context, index) {
                              final chat = _chats[index];
                              return Material(
                                color: palette.surfaceAlt.withValues(alpha: 0.48),
                                borderRadius: BorderRadius.circular(12),
                                child: InkWell(
                                  borderRadius: BorderRadius.circular(12),
                                  onTap: () {
                                    Navigator.of(context).pop();
                                    widget.onSelectChat(chat);
                                  },
                                  onLongPress: () => _showChatActions(chat),
                                  child: Padding(
                                    padding: const EdgeInsets.symmetric(horizontal: 11, vertical: 10),
                                    child: Row(
                                      children: [
                                        Icon(
                                          chat.mode == 'coder' ? NumiIcons.code_rounded : NumiIcons.chat_bubble_outline,
                                          color: palette.textSecondary,
                                          size: 18,
                                        ),
                                        const SizedBox(width: 10),
                                        Expanded(
                                          child: Text(
                                            chat.title,
                                            maxLines: 1,
                                            overflow: TextOverflow.ellipsis,
                                            style: TextStyle(color: palette.textPrimary, fontSize: 13, fontWeight: FontWeight.w500),
                                          ),
                                        ),
                                        Icon(LucideIcons.chevronRight, size: 15, color: palette.textSecondary.withValues(alpha: 0.7)),
                                      ],
                                    ),
                                  ),
                                ),
                              );
                            },
                          ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _DrawerItem extends StatelessWidget {
  const _DrawerItem({
    required this.icon,
    required this.label,
    required this.color,
    required this.onTap,
    this.trailing,
  });
  final IconData icon;
  final String label;
  final Color color;
  final VoidCallback onTap;
  final Widget? trailing;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      borderRadius: BorderRadius.circular(12),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 9),
          child: Row(
            children: [
              Icon(icon, color: color.withValues(alpha: 0.88), size: 19),
              const SizedBox(width: 13),
              Expanded(
                child: Text(
                  label,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(color: color, fontSize: 14, fontWeight: FontWeight.w500),
                ),
              ),
              if (trailing != null) ...[const SizedBox(width: 8), trailing!],
            ],
          ),
        ),
      ),
    );
  }
}

/// Dropdown pill usado tanto en el drawer ("Sesiones") como espejado
/// visualmente por los chips Chat/Coder de la barra inferior. Ambos
/// llaman el mismo callback [onSelectMode] de HomeScreen.
class ModePillDropdown extends ConsumerWidget {
  const ModePillDropdown({
    super.key,
    required this.modeId,
    required this.availableModes,
    required this.onSelectMode,
  });
  final String modeId;
  final List<AiModeConfig> availableModes;
  final ValueChanged<String> onSelectMode;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final palette = ref.watch(appPaletteProvider);
    final current = availableModes.where((m) => m.id == modeId);
    final currentLabel = current.isNotEmpty ? current.first.label : 'Chat';
    return PopupMenuButton<String>(
      color: palette.surfaceAlt,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
      onSelected: onSelectMode,
      // Los items del menú son los modos que devuelve GET /modes, así que
      // agregar un modo nuevo en Supabase lo hace aparecer aquí también,
      // sin recompilar la app.
      itemBuilder: (context) => availableModes
          .map(
            (m) => PopupMenuItem(
              value: m.id,
              child: Text(
                m.label,
                style: TextStyle(color: palette.textPrimary),
              ),
            ),
          )
          .toList(),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: palette.border),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              currentLabel,
              style: TextStyle(color: palette.textPrimary, fontSize: 15),
            ),
            const SizedBox(width: 6),
            Icon(
              NumiIcons.keyboard_arrow_down,
              color: palette.textPrimary,
              size: 18,
            ),
          ],
        ),
      ),
    );
  }
}
