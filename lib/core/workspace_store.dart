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
    final list = (jsonDecode(raw) as List).cast<Map<String, dynamic>>();
    return list.map(Project.fromJson).toList();
  }

  static Future<void> saveProjects(List<Project> projects) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_projectsKey, jsonEncode(projects.map((p) => {
          'id': p.id, 'name': p.name, 'description': p.description, 'created_at': p.createdAt, 'updated_at': p.updatedAt,
        }).toList()));
  }

  static Future<void> setActiveProject(String? id) async {
    final prefs = await SharedPreferences.getInstance();
    if (id == null) { await prefs.remove(_activeProjectKey); } else { await prefs.setString(_activeProjectKey, id); }
  }

  static Future<String> localProjectRoot(String projectName) async {
    final base = await getApplicationDocumentsDirectory();
    final safe = projectName.replaceAll(RegExp(r'[^a-zA-Z0-9._-]+'), '_');
    final dir = Directory('${base.path}/NuminationProjects/$safe');
    await dir.create(recursive: true);
    return dir.path;
  }

  static Future<void> mirrorFile(String projectName, FileItem file) async {
    if (file.isDirectory) return;
    final root = await localProjectRoot(projectName);
    final target = File('$root/${file.path.replaceAll('\\', '/')}');
    await target.parent.create(recursive: true);
    await target.writeAsString(file.content);
  }
}
