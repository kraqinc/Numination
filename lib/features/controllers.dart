import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../core/api.dart';
import '../core/models.dart';
import '../core/workspace_store.dart';

final projectsProvider = AsyncNotifierProvider<ProjectsController, List<Project>>(ProjectsController.new);
class ProjectsController extends AsyncNotifier<List<Project>> {
  @override Future<List<Project>> build() async => _load();
  Future<List<Project>> _load() async {
    try {
      final data = ApiClient.decode(await ApiClient.get('/projects')) as Map;
      final projects = ((data['projects'] as List?) ?? const []).map((e) => Project.fromJson(Map<String, dynamic>.from(e))).toList();
      await WorkspaceStore.saveProjects(projects);
      return projects;
    } catch (e) {
      final cached = await WorkspaceStore.getCachedProjects();
      if (cached.isNotEmpty) return cached;
      rethrow;
    }
  }
  Future<void> refresh() async { state = const AsyncLoading(); state = await AsyncValue.guard(_load); }
  Future<Project?> create(String name, String description) async {
    final data = ApiClient.decode(await ApiClient.post('/projects', {'name': name, 'description': description})) as Map;
    await refresh();
    final p = data['project'];
    return p is Map ? Project.fromJson(Map<String, dynamic>.from(p)) : null;
  }
}

final fileControllerProvider = AsyncNotifierProvider<FileController, List<FileItem>>(FileController.new);
class FileController extends AsyncNotifier<List<FileItem>> {
  String? _projectId;
  @override Future<List<FileItem>> build() async => const [];
  Future<void> setProject(Project? project) async {
    _projectId = project?.id;
    if (project == null) { state = const AsyncData([]); return; }
    await load(project);
  }
  Future<List<FileItem>> _fetch(Project project) async {
    final data = ApiClient.decode(await ApiClient.get('/projects/${project.id}/files')) as Map;
    return ((data['files'] as List?) ?? const []).map((e) => FileItem.fromJson(Map<String, dynamic>.from(e))).toList();
  }
  Future<void> load(Project project) async {
    _projectId = project.id;
    state = const AsyncLoading();
    state = await AsyncValue.guard(() => _fetch(project));
  }
  Future<void> create(String name, {bool directory=false, String path='', String content=''}) async {
    final id=_projectId; if(id==null)return;
    final normalized=path.trim().isEmpty?name:'${path.replaceAll(RegExp(r'/$'),'')}/$name';
    ApiClient.decode(await ApiClient.post('/projects/$id/files', {'name':name,'path':normalized,'isDirectory':directory,'content':content}));
    final fake=Project(id:id,name:'',description:'',createdAt:'',updatedAt:''); await load(fake);
  }
  Future<void> save(FileItem file, String content) async {
    final id=_projectId; if(id==null)return;
    ApiClient.decode(await ApiClient.put('/projects/$id/files/${file.id}', {'content':content}));
    final current=state.valueOrNull ?? const <FileItem>[];
    state=AsyncData(current.map((f)=>f.id==file.id?FileItem(id:f.id,projectId:f.projectId,name:f.name,path:f.path,isDirectory:f.isDirectory,content:content,parentId:f.parentId):f).toList());
  }
  Future<void> remove(FileItem file) async {
    final id=_projectId; if(id==null)return;
    ApiClient.decode(await ApiClient.delete('/projects/$id/files/${file.id}'));
    state=AsyncData((state.valueOrNull??const <FileItem>[]).where((f)=>f.id!=file.id).toList());
  }
}
