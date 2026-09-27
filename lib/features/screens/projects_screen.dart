import 'package:flutter/material.dart';
import 'package:flutter_morphing_icons/flutter_morphing_icons.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/api.dart';
import '../../core/i18n.dart';
import '../../core/models.dart';
import '../../core/theme.dart';
import '../../core/theme_controller.dart';

class ProjectsScreen extends ConsumerStatefulWidget {
  const ProjectsScreen({super.key});

  @override
  ConsumerState<ProjectsScreen> createState() => _ProjectsScreenState();
}

class _ProjectsScreenState extends ConsumerState<ProjectsScreen> {
  bool _isLoading = true;
  List<Project> _projects = [];
  List<ChatSession> _chats = [];
  final Set<String> _expandedProjects = <String>{};
  String? _errorText;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    if (mounted) {
      setState(() {
        _isLoading = true;
        _errorText = null;
      });
    }

    try {
      final responses = await Future.wait([
        ApiClient.get('/projects'),
        ApiClient.get('/chats'),
      ]);

      final projectsData =
          ApiClient.decode(responses[0]) as Map<String, dynamic>;
      final chatsData =
          ApiClient.decode(responses[1]) as Map<String, dynamic>;

      final projects = (projectsData['projects'] as List? ?? [])
          .whereType<Map>()
          .map(
            (e) => Project.fromJson(
              Map<String, dynamic>.from(e),
            ),
          )
          .toList();

      final chats = (chatsData['chats'] as List? ?? [])
          .whereType<Map>()
          .map(
            (e) => ChatSession.fromJson(
              Map<String, dynamic>.from(e),
            ),
          )
          .where((chat) => !chat.isGhost)
          .toList();

      if (!mounted) return;

      setState(() {
        _projects = projects;
        _chats = chats;
        _isLoading = false;
      });
    } catch (_) {
      if (!mounted) return;

      setState(() {
        _isLoading = false;
        _errorText = 'No se pudieron cargar tus proyectos';
      });
    }
  }

  Future<void> _createProject() async {
    final palette = ref.read(appPaletteProvider);
    final controller = TextEditingController();

    final name = await showDialog<String>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        backgroundColor: palette.surface,
        title: Text(
          AppLocale.t('create'),
          style: TextStyle(color: palette.textPrimary),
        ),
        content: TextField(
          controller: controller,
          autofocus: true,
          maxLength: 80,
          style: TextStyle(color: palette.textPrimary),
          decoration: InputDecoration(
            hintText: 'Nombre del proyecto',
            hintStyle: TextStyle(color: palette.textSecondary),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(),
            child: Text(
              AppLocale.t('cancel'),
              style: TextStyle(color: palette.textSecondary),
            ),
          ),
          TextButton(
            onPressed: () {
              final value = controller.text.trim();

              if (value.isEmpty) {
                return;
              }

              Navigator.of(dialogContext).pop(value);
            },
            child: Text(
              AppLocale.t('create'),
              style: TextStyle(color: palette.accent),
            ),
          ),
        ],
      ),
    );

    controller.dispose();

    if (name == null || name.isEmpty) return;

    try {
      await ApiClient.post('/projects', {
        'name': name,
      });

      await _load();
    } on ApiException catch (e) {
      if (!mounted) return;
      setState(() => _errorText = e.message);
    } catch (_) {
      if (!mounted) return;
      setState(() => _errorText = 'No se pudo crear el proyecto');
    }
  }

  List<ChatSession> _chatsForProject(Project project) {
    return _chats
        .where((chat) => chat.projectId == project.id)
        .toList();
  }

  void _toggleProject(String projectId) {
    setState(() {
      if (_expandedProjects.contains(projectId)) {
        _expandedProjects.remove(projectId);
      } else {
        _expandedProjects.add(projectId);
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final palette = ref.watch(appPaletteProvider);

    return Scaffold(
      backgroundColor: palette.background,
      appBar: AppBar(
        backgroundColor: palette.background,
        elevation: 0,
        iconTheme: IconThemeData(color: palette.textPrimary),
        title: Text(
          AppLocale.t('projects'),
          style: TextStyle(
            color: palette.textPrimary,
          ),
        ),
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: _createProject,
        backgroundColor: palette.accent,
        child: const Icon(
          Icons.add,
          color: Colors.black,
        ),
      ),
      body: RefreshIndicator(
        onRefresh: _load,
        child: _isLoading
            ? ListView(
                physics: const AlwaysScrollableScrollPhysics(),
                children: [
                  SizedBox(
                    height: MediaQuery.sizeOf(context).height * 0.35,
                  ),
                  Center(
                    child: CircularProgressIndicator(
                      color: palette.textPrimary,
                    ),
                  ),
                ],
              )
            : _projects.isEmpty
                ? ListView(
                    physics: const AlwaysScrollableScrollPhysics(),
                    children: [
                      SizedBox(
                        height: MediaQuery.sizeOf(context).height * 0.28,
                      ),
                      _EmptyProjectsState(
                        errorText: _errorText,
                        palette: palette,
                      ),
                    ],
                  )
                : ListView.separated(
                    physics: const AlwaysScrollableScrollPhysics(),
                    padding: const EdgeInsets.fromLTRB(
                      16,
                      12,
                      16,
                      90,
                    ),
                    itemCount: _projects.length,
                    separatorBuilder: (_, _) =>
                        const SizedBox(height: 10),
                    itemBuilder: (context, index) {
                      final project = _projects[index];
                      final expanded =
                          _expandedProjects.contains(project.id);
                      final chats = _chatsForProject(project);

                      return _ProjectCard(
                        project: project,
                        chats: chats,
                        expanded: expanded,
                        palette: palette,
                        onToggle: () => _toggleProject(project.id),
                      );
                    },
                  ),
      ),
    );
  }
}

class _ProjectCard extends StatelessWidget {
  const _ProjectCard({
    required this.project,
    required this.chats,
    required this.expanded,
    required this.palette,
    required this.onToggle,
  });

  final Project project;
  final List<ChatSession> chats;
  final bool expanded;
  final AppPalette palette;
  final VoidCallback onToggle;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: palette.surface,
      borderRadius: BorderRadius.circular(18),
      child: Container(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(18),
          border: Border.all(
            color: expanded
                ? palette.accent.withValues(alpha: 0.45)
                : palette.border,
          ),
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(18),
          child: Column(
            children: [
              InkWell(
                onTap: onToggle,
                child: Padding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 14,
                  ),
                  child: Row(
                    children: [
                      MorphingIcon.icons(
                        icons: const [
                          Icons.folder_outlined,
                          Icons.folder_open_outlined,
                        ],
                        initialState: expanded ? 1 : 0,
                        size: 25,
                        color: palette.accent,
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment:
                              CrossAxisAlignment.start,
                          children: [
                            Text(
                              project.name,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: TextStyle(
                                color: palette.textPrimary,
                                fontSize: 16,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                            if (project.description.isNotEmpty) ...[
                              const SizedBox(height: 3),
                              Text(
                                project.description,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: TextStyle(
                                  color: palette.textSecondary,
                                  fontSize: 12,
                                ),
                              ),
                            ],
                            const SizedBox(height: 4),
                            Text(
                              '${chats.length} ${chats.length == 1 ? 'chat' : 'chats'}',
                              style: TextStyle(
                                color: palette.textSecondary,
                                fontSize: 11,
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(width: 8),
                      MorphingIcon.icons(
                        icons: const [
                          Icons.keyboard_arrow_down_rounded,
                          Icons.keyboard_arrow_up_rounded,
                        ],
                        initialState: expanded ? 1 : 0,
                        size: 25,
                        color: palette.textSecondary,
                      ),
                    ],
                  ),
                ),
              ),
              AnimatedCrossFade(
                firstChild: const SizedBox.shrink(),
                secondChild: _ProjectChats(
                  chats: chats,
                  palette: palette,
                ),
                crossFadeState: expanded
                    ? CrossFadeState.showSecond
                    : CrossFadeState.showFirst,
                duration: const Duration(milliseconds: 220),
                sizeCurve: Curves.easeOutCubic,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _ProjectChats extends StatelessWidget {
  const _ProjectChats({
    required this.chats,
    required this.palette,
  });

  final List<ChatSession> chats;
  final AppPalette palette;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(
        16,
        0,
        16,
        14,
      ),
      child: chats.isEmpty
          ? Container(
              margin: const EdgeInsets.only(top: 2),
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: palette.surfaceAlt,
                borderRadius: BorderRadius.circular(12),
              ),
              child: Row(
                children: [
                  Icon(
                    Icons.chat_bubble_outline_rounded,
                    color: palette.textSecondary,
                    size: 18,
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      'Este proyecto todavía no tiene chats.',
                      style: TextStyle(
                        color: palette.textSecondary,
                        fontSize: 13,
                      ),
                    ),
                  ),
                ],
              ),
            )
          : Column(
              children: [
                Divider(
                  color: palette.border,
                  height: 1,
                ),
                const SizedBox(height: 6),
                ...chats.map(
                  (chat) => _ProjectChatTile(
                    chat: chat,
                    palette: palette,
                  ),
                ),
              ],
            ),
    );
  }
}

class _ProjectChatTile extends StatelessWidget {
  const _ProjectChatTile({
    required this.chat,
    required this.palette,
  });

  final ChatSession chat;
  final AppPalette palette;

  @override
  Widget build(BuildContext context) {
    final isCoder = chat.mode == 'coder';

    return Padding(
      padding: const EdgeInsets.only(top: 3),
      child: Material(
        color: Colors.transparent,
        borderRadius: BorderRadius.circular(12),
        child: InkWell(
          borderRadius: BorderRadius.circular(12),
          onTap: () {
            // El chat ya se visualiza aquí. La apertura seguirá usando
            // el mismo flujo del Home/Drawer.
          },
          child: Padding(
            padding: const EdgeInsets.symmetric(
              horizontal: 8,
              vertical: 11,
            ),
            child: Row(
              children: [
                Icon(
                  isCoder
                      ? Icons.code_rounded
                      : Icons.chat_bubble_outline_rounded,
                  color: palette.accent,
                  size: 19,
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    chat.title,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      color: palette.textPrimary,
                      fontSize: 14,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ),
                Icon(
                  Icons.chevron_right_rounded,
                  color: palette.textSecondary,
                  size: 19,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _EmptyProjectsState extends StatelessWidget {
  const _EmptyProjectsState({
    this.errorText,
    required this.palette,
  });

  final String? errorText;
  final AppPalette palette;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 72,
              height: 72,
              decoration: BoxDecoration(
                color: palette.surface,
                borderRadius: BorderRadius.circular(20),
                border: Border.all(
                  color: palette.border,
                ),
              ),
              child: Icon(
                Icons.folder_copy_outlined,
                color: palette.accent,
                size: 36,
              ),
            ),
            const SizedBox(height: 20),
            Text(
              AppLocale.t('no_projects_title'),
              style: TextStyle(
                color: palette.textPrimary,
                fontSize: 18,
                fontWeight: FontWeight.w600,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 6),
            Text(
              AppLocale.t('no_projects_subtitle'),
              style: TextStyle(
                color: palette.textSecondary,
                fontSize: 14,
              ),
              textAlign: TextAlign.center,
            ),
            if (errorText != null) ...[
              const SizedBox(height: 16),
              Text(
                errorText!,
                style: const TextStyle(
                  color: Colors.redAccent,
                  fontSize: 13,
                ),
                textAlign: TextAlign.center,
              ),
            ],
          ],
        ),
      ),
    );
  }
}
