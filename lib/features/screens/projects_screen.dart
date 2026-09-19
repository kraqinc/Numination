import 'package:flutter/material.dart';

import '../../core/api.dart';
import '../../core/models.dart';
import '../../core/theme.dart';

class ProjectsScreen extends StatefulWidget {
  const ProjectsScreen({super.key});

  @override
  State<ProjectsScreen> createState() => _ProjectsScreenState();
}

class _ProjectsScreenState extends State<ProjectsScreen> {
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
    final controller = TextEditingController();
    final name = await showDialog<String>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        backgroundColor: Colors.white,
        title: const Text('Nuevo proyecto', style: TextStyle(color: Colors.black)),
        content: TextField(
          controller: controller,
          autofocus: true,
          style: const TextStyle(color: Colors.black),
          decoration: const InputDecoration(
            hintText: 'Nombre del proyecto',
            hintStyle: TextStyle(color: Color(0xFF8A8A8A)),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(),
            child: const Text('Cancelar', style: TextStyle(color: Color(0xFF8A8A8A))),
          ),
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(controller.text.trim()),
            child: const Text('Crear', style: TextStyle(color: Color(0xFF6ED7FF))),
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
    return Scaffold(
      backgroundColor: AppColors.screenBackground,
      appBar: AppBar(
        backgroundColor: AppColors.screenBackground,
        elevation: 0,
        iconTheme: const IconThemeData(color: Colors.black),
        title: const Text('Proyectos', style: TextStyle(color: Colors.black)),
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: _createProject,
        backgroundColor: const Color(0xFF6ED7FF),
        child: const Icon(Icons.add, color: Colors.black),
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator(color: Colors.black))
          : _projects.isEmpty
              ? _EmptyProjectsState(errorText: _errorText)
              : ListView.separated(
                  padding: const EdgeInsets.all(16),
                  itemCount: _projects.length,
                  separatorBuilder: (_, _) => const SizedBox(height: 10),
                  itemBuilder: (context, index) {
                    final project = _projects[index];
                    return Container(
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(14),
                        border: Border.all(color: const Color(0xFFD8D8D8)),
                      ),
                      child: Row(
                        children: [
                          const Icon(Icons.folder_copy_outlined, color: Color(0xFF1E88C7)),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(project.name, style: const TextStyle(color: Colors.black, fontSize: 16, fontWeight: FontWeight.w600)),
                                if (project.description.isNotEmpty) ...[
                                  const SizedBox(height: 2),
                                  Text(
                                    project.description,
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                    style: const TextStyle(color: Color(0xFF8A8A8A), fontSize: 13),
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
  const _EmptyProjectsState({this.errorText});
  final String? errorText;

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
                color: Colors.white,
                borderRadius: BorderRadius.circular(20),
                border: Border.all(color: const Color(0xFFD8D8D8)),
              ),
              child: const Icon(Icons.add_rounded, color: Color(0xFF1E88C7), size: 36),
            ),
            const SizedBox(height: 20),
            const Text(
              'No tienes proyectos',
              style: TextStyle(color: Colors.black, fontSize: 18, fontWeight: FontWeight.w600),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 6),
            const Text(
              'Crea uno y empieza a chatear',
              style: TextStyle(color: Color(0xFF8A8A8A), fontSize: 14),
              textAlign: TextAlign.center,
            ),
            if (errorText != null) ...[
              const SizedBox(height: 16),
              Text(errorText!, style: const TextStyle(color: Colors.redAccent, fontSize: 13)),
            ],
          ],
        ),
      ),
    );
  }
}