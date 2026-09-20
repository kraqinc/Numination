import 'package:flutter/material.dart';
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
  String? _errorText;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() => _isLoading = true);
    try {
      final response = await ApiClient.get('/projects');
      final data = ApiClient.decode(response) as Map<String, dynamic>;
      final list = (data['projects'] as List? ?? [])
          .map((e) => Project.fromJson(Map<String, dynamic>.from(e as Map)))
          .toList();
      setState(() {
        _projects = list;
        _isLoading = false;
      });
    } catch (e) {
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
            onPressed: () =>
                Navigator.of(dialogContext).pop(controller.text.trim()),
            child: Text(
              AppLocale.t('create'),
              style: TextStyle(color: palette.accent),
            ),
          ),
        ],
      ),
    );

    if (name == null || name.isEmpty) return;

    try {
      await ApiClient.post('/projects', {'name': name});
      await _load();
    } catch (e) {
      setState(() => _errorText = 'No se pudo crear el proyecto');
    }
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
          style: TextStyle(color: palette.textPrimary),
        ),
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: _createProject,
        backgroundColor: palette.accent,
        child: const Icon(Icons.add, color: Colors.black),
      ),
      body: _isLoading
          ? Center(child: CircularProgressIndicator(color: palette.textPrimary))
          : _projects.isEmpty
          ? _EmptyProjectsState(errorText: _errorText, palette: palette)
          : ListView.separated(
              padding: const EdgeInsets.all(16),
              itemCount: _projects.length,
              separatorBuilder: (_, _) => const SizedBox(height: 10),
              itemBuilder: (context, index) {
                final project = _projects[index];
                return Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: palette.surface,
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(color: palette.border),
                  ),
                  child: Row(
                    children: [
                      Icon(Icons.folder_copy_outlined, color: palette.accent),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              project.name,
                              style: TextStyle(
                                color: palette.textPrimary,
                                fontSize: 16,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                            if (project.description.isNotEmpty) ...[
                              const SizedBox(height: 2),
                              Text(
                                project.description,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: TextStyle(
                                  color: palette.textSecondary,
                                  fontSize: 13,
                                ),
                              ),
                            ],
                          ],
                        ),
                      ),
                    ],
                  ),
                );
              },
            ),
    );
  }
}

class _EmptyProjectsState extends StatelessWidget {
  const _EmptyProjectsState({this.errorText, required this.palette});
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
                border: Border.all(color: palette.border),
              ),
              child: Icon(Icons.add_rounded, color: palette.accent, size: 36),
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
              style: TextStyle(color: palette.textSecondary, fontSize: 14),
              textAlign: TextAlign.center,
            ),
            if (errorText != null) ...[
              const SizedBox(height: 16),
              Text(
                errorText!,
                style: const TextStyle(color: Colors.redAccent, fontSize: 13),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
