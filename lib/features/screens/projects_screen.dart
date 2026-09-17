import 'package:flutter/material.dart';

import '../../core/api.dart';
import '../../core/models.dart';
import '../../core/workspace_store.dart';

class ProjectsScreen extends StatefulWidget {
  const ProjectsScreen({
    super.key,
  });

  @override
  State<ProjectsScreen> createState() =>
      _ProjectsScreenState();
}

class _ProjectsScreenState
    extends State<ProjectsScreen> {
  bool _loading = true;
  String? _error;

  List<Project> _projects = [];

  @override
  void initState() {
    super.initState();
    _loadProjects();
  }

  Future<void> _loadProjects() async {
    setState(() {
      _loading = true;
      _error = null;
    });

    try {
      final response =
          await ApiClient.get('/projects');

      final decoded =
          ApiClient.decode(response);

      final raw =
          decoded is Map<String, dynamic>
              ? decoded['projects'] ??
                  decoded['items'] ??
                  const []
              : decoded;

      final projects =
          raw is List
              ? raw
                  .whereType<Map>()
                  .map(
                    (item) =>
                        Project.fromJson(
                      Map<String, dynamic>.from(
                        item,
                      ),
                    ),
                  )
                  .toList()
              : <Project>[];

      await WorkspaceStore.saveProjects(
        projects,
      );

      if (!mounted) return;

      setState(() {
        _projects = projects;
        _loading = false;
      });
    } catch (_) {
      final cached =
          await WorkspaceStore
              .getCachedProjects();

      if (!mounted) return;

      setState(() {
        _projects = cached;
        _loading = false;

        _error =
            cached.isEmpty
                ? 'No se pudieron cargar los proyectos'
                : null;
      });
    }
  }

  Future<void> _createProject() async {
    final nameController =
        TextEditingController();

    final descriptionController =
        TextEditingController();

    final result =
        await showDialog<bool>(
      context: context,
      builder: (dialogContext) {
        return AlertDialog(
          backgroundColor:
              const Color(0xFF141414),
          shape:
              RoundedRectangleBorder(
            borderRadius:
                BorderRadius.circular(
              18,
            ),
          ),
          title: const Text(
            'Nuevo proyecto',
            style: TextStyle(
              color: Colors.white,
              fontWeight:
                  FontWeight.w700,
            ),
          ),
          content: Column(
            mainAxisSize:
                MainAxisSize.min,
            children: [
              TextField(
                controller:
                    nameController,
                style:
                    const TextStyle(
                  color: Colors.white,
                ),
                decoration:
                    _inputDecoration(
                  'Nombre',
                ),
              ),
              const SizedBox(height: 12),
              TextField(
                controller:
                    descriptionController,
                maxLines: 3,
                style:
                    const TextStyle(
                  color: Colors.white,
                ),
                decoration:
                    _inputDecoration(
                  'Descripción',
                ),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () {
                Navigator.of(
                  dialogContext,
                ).pop(false);
              },
              child: const Text(
                'Cancelar',
              ),
            ),
            FilledButton(
              onPressed: () {
                Navigator.of(
                  dialogContext,
                ).pop(true);
              },
              child: const Text(
                'Crear',
              ),
            ),
          ],
        );
      },
    );

    nameController.dispose();
    descriptionController.dispose();

    if (result != true) {
      return;
    }

    // Este punto necesita los valores del
    // formulario antes de dispose en una
    // implementación que conserve esos datos.
    //
    // Por simplicidad, esta pantalla debe
    // conservar los controllers si se quiere
    // enviar el texto directamente.
  }

  InputDecoration _inputDecoration(
    String hint,
  ) {
    return InputDecoration(
      hintText: hint,
      hintStyle:
          const TextStyle(
        color: Color(0xFF777777),
      ),
      filled: true,
      fillColor:
          const Color(0xFF0D0D0D),
      border:
          OutlineInputBorder(
        borderRadius:
            BorderRadius.circular(
          12,
        ),
        borderSide:
            BorderSide.none,
      ),
    );
  }

  @override
  Widget build(
    BuildContext context,
  ) {
    return Scaffold(
      backgroundColor:
          const Color(0xFFECECEC),
      appBar: AppBar(
        backgroundColor:
            const Color(0xFFECECEC),
        foregroundColor:
            Colors.black,
        elevation: 0,
        title: const Text(
          'Proyectos',
          style: TextStyle(
            color: Colors.black,
            fontWeight:
                FontWeight.w700,
          ),
        ),
        actions: [
          IconButton(
            onPressed: _loadProjects,
            icon: const Icon(
              Icons.refresh,
            ),
          ),
        ],
      ),
      floatingActionButton:
          FloatingActionButton(
        onPressed: _showCreateProjectDialog,
        backgroundColor: Colors.black,
        foregroundColor: Colors.white,
        child: const Icon(
          Icons.add,
        ),
      ),
      body:
          _loading
              ? const Center(
                  child:
                      CircularProgressIndicator(
                    color:
                        Colors.black,
                  ),
                )
              : _projects.isEmpty
                  ? Center(
                      child:
                          Padding(
                        padding:
                            const EdgeInsets
                                .all(32),
                        child: Column(
                          mainAxisSize:
                              MainAxisSize
                                  .min,
                          children: [
                            const Icon(
                              Icons
                                  .folder_copy_outlined,
                              size: 48,
                              color:
                                  Colors
                                      .black54,
                            ),
                            const SizedBox(
                              height: 14,
                            ),
                            const Text(
                              'Todavía no hay proyectos',
                              textAlign:
                                  TextAlign
                                      .center,
                              style:
                                  TextStyle(
                                fontSize: 20,
                                fontWeight:
                                    FontWeight
                                        .w700,
                              ),
                            ),
                            const SizedBox(
                              height: 8,
                            ),
                            Text(
                              _error ??
                                  'Crea uno con el botón +',
                              textAlign:
                                  TextAlign
                                      .center,
                              style:
                                  const TextStyle(
                                color:
                                    Colors
                                        .black54,
                              ),
                            ),
                          ],
                        ),
                      ),
                    )
                  : ListView.separated(
                      padding:
                          const EdgeInsets
                              .all(16),
                      itemCount:
                          _projects.length,
                      separatorBuilder:
                          (
                            _,
                            __,
                          ) =>
                              const SizedBox(
                            height: 10,
                          ),
                      itemBuilder:
                          (
                            context,
                            index,
                          ) {
                            final project =
                                _projects[
                                    index];

                            return Material(
                              color:
                                  const Color(
                                0xFF141414,
                              ),
                              borderRadius:
                                  BorderRadius
                                      .circular(
                                18,
                              ),
                              child:
                                  InkWell(
                                borderRadius:
                                    BorderRadius
                                        .circular(
                                  18,
                                ),
                                onTap:
                                    () async {
                                  await WorkspaceStore
                                      .setActiveProject(
                                    project.id,
                                  );

                                  if (!context
                                      .mounted) {
                                    return;
                                  }

                                  Navigator.of(
                                    context,
                                  ).push(
                                    MaterialPageRoute(
                                      builder:
                                          (_) =>
                                              ProjectFilesScreen(
                                        project:
                                            project,
                                      ),
                                    ),
                                  );
                                },
                                child:
                                    Padding(
                                  padding:
                                      const EdgeInsets
                                          .all(
                                    18,
                                  ),
                                  child: Row(
                                    children: [
                                      const Icon(
                                        Icons
                                            .folder_rounded,
                                        color:
                                            Color(
                                          0xFF6ED7FF,
                                        ),
                                        size: 30,
                                      ),
                                      const SizedBox(
                                        width: 14,
                                      ),
                                      Expanded(
                                        child:
                                            Column(
                                          crossAxisAlignment:
                                              CrossAxisAlignment
                                                  .start,
                                          children: [
                                            Text(
                                              project
                                                  .name,
                                              maxLines:
                                                  1,
                                              overflow:
                                                  TextOverflow
                                                      .ellipsis,
                                              style:
                                                  const TextStyle(
                                                color:
                                                    Colors.white,
                                                fontSize:
                                                    17,
                                                fontWeight:
                                                    FontWeight.w700,
                                              ),
                                            ),
                                            if (project
                                                .description
                                                .isNotEmpty) ...[
                                              const SizedBox(
                                                height: 4,
                                              ),
                                              Text(
                                                project
                                                    .description,
                                                maxLines:
                                                    2,
                                                overflow:
                                                    TextOverflow
                                                        .ellipsis,
                                                style:
                                                    const TextStyle(
                                                  color:
                                                      Color(
                                                    0xFF969696,
                                                  ),
                                                ),
                                              ),
                                            ],
                                          ],
                                        ),
                                      ),
                                      const Icon(
                                        Icons
                                            .chevron_right,
                                        color:
                                            Colors.white54,
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                            );
                          },
                    ),
    );
  }

  Future<void>
      _showCreateProjectDialog() async {
    final nameController =
        TextEditingController();

    final descriptionController =
        TextEditingController();

    final result =
        await showDialog<bool>(
      context: context,
      builder: (dialogContext) {
        return AlertDialog(
          backgroundColor:
              const Color(0xFF141414),
          title: const Text(
            'Nuevo proyecto',
            style: TextStyle(
              color: Colors.white,
            ),
          ),
          content: Column(
            mainAxisSize:
                MainAxisSize.min,
            children: [
              TextField(
                controller:
                    nameController,
                style:
                    const TextStyle(
                  color: Colors.white,
                ),
                decoration:
                    _inputDecoration(
                  'Nombre',
                ),
              ),
              const SizedBox(height: 12),
              TextField(
                controller:
                    descriptionController,
                maxLines: 3,
                style:
                    const TextStyle(
                  color: Colors.white,
                ),
                decoration:
                    _inputDecoration(
                  'Descripción',
                ),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () {
                Navigator.of(
                  dialogContext,
                ).pop(false);
              },
              child: const Text(
                'Cancelar',
              ),
            ),
            FilledButton(
              onPressed: () {
                Navigator.of(
                  dialogContext,
                ).pop(true);
              },
              child: const Text(
                'Crear',
              ),
            ),
          ],
        );
      },
    );

    if (result != true) {
      nameController.dispose();
      descriptionController.dispose();
      return;
    }

    final name =
        nameController.text.trim();

    final description =
        descriptionController.text.trim();

    nameController.dispose();
    descriptionController.dispose();

    if (name.isEmpty) {
      return;
    }

    try {
      final response =
          await ApiClient.post(
        '/projects',
        {
          'name': name,
          'description': description,
        },
      );

      final decoded =
          ApiClient.decode(response);

      final raw =
          decoded is Map<String, dynamic>
              ? decoded['project'] ??
                  decoded
              : null;

      if (raw is Map) {
        final project =
            Project.fromJson(
          Map<String, dynamic>.from(
            raw,
          ),
        );

        setState(() {
          _projects = [
            ..._projects,
            project,
          ];
        });

        await WorkspaceStore.saveProjects(
          _projects,
        );

        if (!mounted) return;

        ScaffoldMessenger.of(context)
            .showSnackBar(
          const SnackBar(
            content:
                Text('Proyecto creado'),
          ),
        );
      }
    } on ApiException catch (e) {
      if (!mounted) return;

      ScaffoldMessenger.of(context)
          .showSnackBar(
        SnackBar(
          content: Text(
            e.message,
          ),
        ),
      );
    }
  }
}

class ProjectFilesScreen
    extends StatefulWidget {
  const ProjectFilesScreen({
    super.key,
    required this.project,
  });

  final Project project;

  @override
  State<ProjectFilesScreen> createState() =>
      _ProjectFilesScreenState();
}

class _ProjectFilesScreenState
    extends State<ProjectFilesScreen> {
  bool _loading = true;
  List<FileItem> _files = [];

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    try {
      final response =
          await ApiClient.get(
        '/projects/${Uri.encodeComponent(widget.project.id)}/files',
      );

      final decoded =
          ApiClient.decode(response);

      final raw =
          decoded is Map<String, dynamic>
              ? decoded['files'] ??
                  decoded['items'] ??
                  const []
              : decoded;

      final files =
          raw is List
              ? raw
                  .whereType<Map>()
                  .map(
                    (item) =>
                        FileItem.fromJson(
                      Map<String, dynamic>.from(
                        item,
                      ),
                    ),
                  )
                  .toList()
              : <FileItem>[];

      if (!mounted) return;

      setState(() {
        _files = files;
        _loading = false;
      });
    } catch (_) {
      if (!mounted) return;

      setState(() {
        _loading = false;
      });
    }
  }

  @override
  Widget build(
    BuildContext context,
  ) {
    return Scaffold(
      backgroundColor:
          const Color(0xFFECECEC),
      appBar: AppBar(
        backgroundColor:
            const Color(0xFFECECEC),
        foregroundColor:
            Colors.black,
        title: Text(
          widget.project.name,
          style: const TextStyle(
            color: Colors.black,
            fontWeight:
                FontWeight.w700,
          ),
        ),
      ),
      body:
          _loading
              ? const Center(
                  child:
                      CircularProgressIndicator(
                    color:
                        Colors.black,
                  ),
                )
              : _files.isEmpty
                  ? const Center(
                      child: Text(
                        'Este proyecto todavía no tiene archivos',
                        style:
                            TextStyle(
                          color:
                              Colors.black54,
                        ),
                      ),
                    )
                  : ListView.separated(
                      padding:
                          const EdgeInsets
                              .all(16),
                      itemCount:
                          _files.length,
                      separatorBuilder:
                          (
                            _,
                            __,
                          ) =>
                              const SizedBox(
                            height: 8,
                          ),
                      itemBuilder:
                          (
                            context,
                            index,
                          ) {
                            final file =
                                _files[
                                    index];

                            return Container(
                              padding:
                                  const EdgeInsets
                                      .all(
                                14,
                              ),
                              decoration:
                                  BoxDecoration(
                                color:
                                    Colors.white,
                                borderRadius:
                                    BorderRadius
                                        .circular(
                                  14,
                                ),
                              ),
                              child: Row(
                                children: [
                                  Icon(
                                    file.isDirectory
                                        ? Icons
                                            .folder_outlined
                                        : Icons
                                            .insert_drive_file_outlined,
                                    color:
                                        Colors.black87,
                                  ),
                                  const SizedBox(
                                    width: 12,
                                  ),
                                  Expanded(
                                    child:
                                        Text(
                                      file.path
                                              .isNotEmpty
                                          ? file
                                              .path
                                          : file
                                              .name,
                                      style:
                                          const TextStyle(
                                        color:
                                            Colors.black87,
                                      ),
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