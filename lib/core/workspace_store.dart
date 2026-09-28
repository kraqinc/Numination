import 'dart:convert';
import 'dart:io';

import 'package:path_provider/path_provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'models.dart';

class WorkspaceStore {
  static const _projectsKey = 'cached_projects';
  static const _activeProjectKey = 'active_project';

  static Future<List<Project>> getCachedProjects() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_projectsKey);

    if (raw == null) return [];

    final decoded = jsonDecode(raw);

    if (decoded is! List) {
      return [];
    }

    return decoded
        .whereType<Map>()
        .map((item) => Project.fromJson(Map<String, dynamic>.from(item)))
        .toList();
  }

  static Future<void> saveProjects(List<Project> projects) async {
    final prefs = await SharedPreferences.getInstance();

    await prefs.setString(
      _projectsKey,
      jsonEncode(
        projects
            .map(
              (p) => {
                'id': p.id,
                'name': p.name,
                'description': p.description,
                'created_at': p.createdAt,
                'updated_at': p.updatedAt,
              },
            )
            .toList(),
      ),
    );
  }

  static Future<void> setActiveProject(String? id) async {
    final prefs = await SharedPreferences.getInstance();

    if (id == null || id.trim().isEmpty) {
      await prefs.remove(_activeProjectKey);
    } else {
      await prefs.setString(_activeProjectKey, id.trim());
    }
  }

  static Future<String> localProjectRoot(String projectName) async {
    final base = await getApplicationDocumentsDirectory();

    final safe = projectName
        .replaceAll(RegExp(r'[^a-zA-Z0-9._-]+'), '_')
        .replaceAll(RegExp(r'_+'), '_')
        .replaceAll(RegExp(r'^_+|_+$'), '');

    final finalName = safe.isEmpty ? 'project' : safe;

    final dir = Directory('${base.path}/NuminationProjects/$finalName');

    await dir.create(recursive: true);

    return dir.path;
  }

  static Future<void> mirrorFile(String projectName, FileItem file) async {
    if (file.isDirectory) return;

    final normalized = file.path.replaceAll('\\', '/').trim();

    if (normalized.isEmpty ||
        normalized.startsWith('/') ||
        normalized.contains('\u0000')) {
      throw const FormatException('Ruta de archivo inválida');
    }

    final segments = normalized.split('/');

    // Nunca permitir salir del workspace mediante ../
    if (segments.any((segment) => segment == '..')) {
      throw const FormatException('Ruta de archivo fuera del proyecto');
    }

    // No aceptar segmentos vacíos extraños.
    final cleanSegments = segments
        .where((segment) => segment.isNotEmpty && segment != '.')
        .toList();

    if (cleanSegments.isEmpty) {
      throw const FormatException('Ruta de archivo inválida');
    }

    final root = Directory(await localProjectRoot(projectName));
    final rootAbsolute = root.absolute.path;

    final target = File(
      '$rootAbsolute/${cleanSegments.join(Platform.pathSeparator)}',
    );

    final targetAbsolute = target.absolute.path;

    final allowedPrefix = rootAbsolute.endsWith(Platform.pathSeparator)
        ? rootAbsolute
        : '$rootAbsolute${Platform.pathSeparator}';

    if (!targetAbsolute.startsWith(allowedPrefix)) {
      throw const FormatException('Ruta de archivo fuera del proyecto');
    }

    await target.parent.create(recursive: true);
    await target.writeAsString(file.content);
  }
}
