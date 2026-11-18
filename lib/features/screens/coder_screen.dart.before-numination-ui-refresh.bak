import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lucide_flutter/lucide_flutter.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../core/api.dart';
import '../../core/local_project_sync.dart';
import '../../core/theme.dart';
import '../../core/theme_controller.dart';
import 'coder_chat_screen.dart';
import '../widgets/numi_loading_animation.dart';

class CoderScreen extends ConsumerStatefulWidget {
  const CoderScreen({super.key});

  @override
  ConsumerState<CoderScreen> createState() => _CoderScreenState();
}

class _CoderScreenState extends ConsumerState<CoderScreen> {
  final _nameController = TextEditingController();

  int _step = 0;
  String _projectType = 'cloud';
  String? _localDirectoryPath;
  bool _isCreating = false;
  int _importProgress = 0;
  String? _errorText;

  @override
  void dispose() {
    _nameController.dispose();
    super.dispose();
  }

  void _nextStep() {
    if (_nameController.text.trim().isEmpty) {
      setState(() => _errorText = 'Escribe un nombre para el proyecto.');
      return;
    }
    FocusManager.instance.primaryFocus?.unfocus();
    setState(() {
      _step = 1;
      _errorText = null;
    });
  }

  Future<void> _chooseLocalFolder() async {
    try {
      final path = await FilePicker.getDirectoryPath(
        dialogTitle: 'Selecciona la carpeta del proyecto',
      );
      if (!mounted || path == null || path.trim().isEmpty) return;
      setState(() {
        _localDirectoryPath = path;
        _errorText = null;
      });
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _errorText = 'No se pudo abrir la carpeta seleccionada: $error';
      });
    }
  }

  Future<void> _createProject() async {
    final name = _nameController.text.trim();
    if (name.isEmpty || _isCreating) return;
    if (_projectType == 'local' && _localDirectoryPath == null) {
      setState(() => _errorText = 'Selecciona primero la carpeta local.');
      return;
    }

    setState(() {
      _isCreating = true;
      _importProgress = 0;
      _errorText = null;
    });

    try {
      // Keep the existing backend contract: project creation accepts a name.
      // Local folder contents are then imported through POST /projects/:id/files.
      final response = await ApiClient.post('/projects', {'name': name});
      final data = ApiClient.decode(response) as Map<String, dynamic>;
      final project = Map<String, dynamic>.from(data['project'] as Map);
      final projectId = '${project['id']}';
      final projectName = '${project['name'] ?? name}';
      final sourcePath = _projectType == 'local' ? _localDirectoryPath : null;

      LocalProjectImportResult? importResult;
      String? importError;
      if (sourcePath != null) {
        try {
          importResult = await LocalProjectSyncService.importDirectoryToCloud(
            projectId: projectId,
            directoryPath: sourcePath,
            onProgress: (current, total) {
              if (mounted) setState(() => _importProgress = current);
            },
          );
        } catch (error) {
          // Keep the created project accessible even if the import is partial.
          importError = error.toString();
        }

        try {
          final prefs = await SharedPreferences.getInstance();
          await prefs.setString(
            'numination.coder.localDirectory.$projectId',
            sourcePath,
          );
        } catch (_) {
          // The current route still receives sourcePath; persistence is optional.
        }
      }

      if (!mounted) return;
      final messenger = ScaffoldMessenger.maybeOf(context);
      Navigator.of(context).pushReplacement(
        MaterialPageRoute<void>(
          builder: (_) => CoderChatScreen(
            projectId: projectId,
            projectName: projectName,
            localDirectoryPath: sourcePath,
          ),
        ),
      );

      if (importError != null) {
        messenger?.showSnackBar(
          SnackBar(
            content: Text(
              'El proyecto se creó, pero la importación quedó incompleta. '
              'Revisa la conexión y vuelve a importar los archivos necesarios. '
              'Detalle: $importError',
            ),
            duration: const Duration(seconds: 7),
          ),
        );
      } else if (importResult != null && importResult.skippedFiles > 0) {
        messenger?.showSnackBar(
          SnackBar(
            content: Text(
              'Se importaron ${importResult.importedFiles} archivos. '
              'Se omitieron ${importResult.skippedFiles} archivos binarios, '
              'sensibles o fuera de los límites de tamaño.',
            ),
            duration: const Duration(seconds: 6),
          ),
        );
      }
    } on ApiException catch (error) {
      if (!mounted) return;
      setState(() {
        _isCreating = false;
        _errorText = error.message;
      });
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _isCreating = false;
        _errorText = 'No se pudo crear el proyecto: $error';
      });
    }
  }

  String _folderDisplayName(String path) {
    final parts = path
        .replaceAll('\\', '/')
        .split('/')
        .where((part) => part.isNotEmpty)
        .toList();
    return parts.isEmpty ? path : parts.last;
  }

  @override
  Widget build(BuildContext context) {
    final palette = ref.watch(appPaletteProvider);
    final isLocal = _projectType == 'local';
    final canCreate = !isLocal || _localDirectoryPath != null;

    Widget projectTypeCard({
      required String value,
      required IconData icon,
      required String title,
      required String description,
    }) {
      final selected = _projectType == value;
      return Material(
        color: selected
            ? palette.accent.withValues(alpha: 0.09)
            : palette.surface,
        borderRadius: BorderRadius.circular(18),
        child: InkWell(
          borderRadius: BorderRadius.circular(18),
          onTap: () => setState(() {
            _projectType = value;
            _errorText = null;
          }),
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 180),
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(18),
              border: Border.all(
                color: selected ? palette.accent : palette.border,
                width: selected ? 1.5 : 1,
              ),
            ),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  width: 44,
                  height: 44,
                  decoration: BoxDecoration(
                    color: selected
                        ? palette.accent.withValues(alpha: 0.15)
                        : palette.surfaceAlt,
                    borderRadius: BorderRadius.circular(13),
                  ),
                  child: Icon(
                    icon,
                    color: selected ? palette.accent : palette.textSecondary,
                  ),
                ),
                const SizedBox(width: 13),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        title,
                        style: TextStyle(
                          color: palette.textPrimary,
                          fontSize: 16,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        description,
                        style: TextStyle(
                          color: palette.textSecondary,
                          fontSize: 13,
                          height: 1.4,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 8),
                Icon(
                  selected ? LucideIcons.circleCheck : LucideIcons.circle,
                  color: selected ? palette.accent : palette.textSecondary,
                  size: 21,
                ),
              ],
            ),
          ),
        ),
      );
    }

    return Scaffold(
      backgroundColor: palette.background,
      appBar: AppBar(
        backgroundColor: palette.background,
        elevation: 0,
        leading: IconButton(
          tooltip: _step == 0 ? 'Volver' : 'Paso anterior',
          onPressed: () {
            if (_step == 1) {
              setState(() => _step = 0);
            } else {
              Navigator.maybePop(context);
            }
          },
          icon: Icon(LucideIcons.arrowLeft, color: palette.textPrimary),
        ),
        title: Text(
          'Coder · Nuevo proyecto',
          style: TextStyle(
            color: palette.textPrimary,
            fontWeight: FontWeight.w700,
          ),
        ),
      ),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.fromLTRB(20, 12, 20, 32),
          children: [
            Row(
              children: [
                _stepIndicator(
                  palette,
                  number: '1',
                  label: 'Nombre',
                  selected: _step == 0,
                  complete: _step > 0,
                ),
                Expanded(child: Container(height: 1, color: palette.border)),
                _stepIndicator(
                  palette,
                  number: '2',
                  label: 'Tipo',
                  selected: _step == 1,
                  complete: false,
                ),
              ],
            ),
            const SizedBox(height: 22),
            Container(
              padding: const EdgeInsets.all(22),
              decoration: BoxDecoration(
                color: palette.surface,
                borderRadius: BorderRadius.circular(24),
                border: Border.all(color: palette.border),
              ),
              child: AnimatedSwitcher(
                duration: const Duration(milliseconds: 200),
                child: _step == 0
                    ? Column(
                        key: const ValueKey('project-name'),
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Container(
                            width: 54,
                            height: 54,
                            decoration: BoxDecoration(
                              color: palette.accent.withValues(alpha: 0.14),
                              borderRadius: BorderRadius.circular(16),
                            ),
                            child: Icon(
                              LucideIcons.code2,
                              color: palette.accent,
                              size: 28,
                            ),
                          ),
                          const SizedBox(height: 20),
                          Text(
                            'Nombre del proyecto',
                            style: TextStyle(
                              color: palette.textPrimary,
                              fontSize: 22,
                              fontWeight: FontWeight.w800,
                            ),
                          ),
                          const SizedBox(height: 8),
                          Text(
                            'Elige un nombre. Después selecciona dónde trabajará Coder.',
                            style: TextStyle(
                              color: palette.textSecondary,
                              fontSize: 14,
                              height: 1.45,
                            ),
                          ),
                          const SizedBox(height: 24),
                          TextField(
                            controller: _nameController,
                            autofocus: true,
                            maxLength: 80,
                            textInputAction: TextInputAction.next,
                            onSubmitted: (_) => _nextStep(),
                            cursorColor: palette.accent,
                            style: TextStyle(color: palette.textPrimary),
                            decoration: InputDecoration(
                              hintText: 'XX',
                              labelText: 'Nombre',
                              hintStyle: TextStyle(
                                color: palette.textSecondary,
                              ),
                              labelStyle: TextStyle(
                                color: palette.textSecondary,
                              ),
                              filled: true,
                              fillColor: palette.surfaceAlt,
                              prefixIcon: Icon(
                                LucideIcons.folder,
                                color: palette.textSecondary,
                              ),
                              border: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(14),
                                borderSide: BorderSide.none,
                              ),
                            ),
                          ),
                        ],
                      )
                    : Column(
                        key: const ValueKey('project-type'),
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Tipo de proyecto',
                            style: TextStyle(
                              color: palette.textPrimary,
                              fontSize: 22,
                              fontWeight: FontWeight.w800,
                            ),
                          ),
                          const SizedBox(height: 8),
                          Text(
                            'Selecciona cómo quieres trabajar en ${_nameController.text.trim()}.',
                            style: TextStyle(
                              color: palette.textSecondary,
                              fontSize: 14,
                              height: 1.45,
                            ),
                          ),
                          const SizedBox(height: 20),
                          projectTypeCard(
                            value: 'cloud',
                            icon: LucideIcons.cloud,
                            title: 'En la nube',
                            description:
                                'Lo crearás desde cero con Coder en Numination.',
                          ),
                          const SizedBox(height: 12),
                          projectTypeCard(
                            value: 'local',
                            icon: LucideIcons.folderOpen,
                            title: 'Local',
                            description:
                                'Coder trabajará en la nube con tu proyecto local.',
                          ),
                          if (isLocal) ...[
                            const SizedBox(height: 14),
                            OutlinedButton.icon(
                              onPressed: _isCreating
                                  ? null
                                  : _chooseLocalFolder,
                              icon: const Icon(LucideIcons.folderOpen),
                              label: Text(
                                _localDirectoryPath == null
                                    ? 'Elegir carpeta local'
                                    : 'Cambiar carpeta',
                              ),
                            ),
                            if (_localDirectoryPath != null) ...[
                              const SizedBox(height: 8),
                              Container(
                                padding: const EdgeInsets.all(11),
                                decoration: BoxDecoration(
                                  color: palette.surfaceAlt,
                                  borderRadius: BorderRadius.circular(12),
                                ),
                                child: Row(
                                  children: [
                                    Icon(
                                      LucideIcons.folderCheck,
                                      color: palette.accent,
                                      size: 18,
                                    ),
                                    const SizedBox(width: 8),
                                    Expanded(
                                      child: Text(
                                        _folderDisplayName(
                                          _localDirectoryPath!,
                                        ),
                                        maxLines: 1,
                                        overflow: TextOverflow.ellipsis,
                                        style: TextStyle(
                                          color: palette.textPrimary,
                                          fontSize: 13,
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ],
                            const SizedBox(height: 14),
                            Container(
                              padding: const EdgeInsets.all(13),
                              decoration: BoxDecoration(
                                color: const Color(
                                  0xFFFFB020,
                                ).withValues(alpha: 0.09),
                                border: Border.all(
                                  color: const Color(
                                    0xFFFFB020,
                                  ).withValues(alpha: 0.42),
                                ),
                                borderRadius: BorderRadius.circular(14),
                              ),
                              child: Row(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  const Icon(
                                    LucideIcons.triangleAlert,
                                    color: Color(0xFFFFB020),
                                    size: 21,
                                  ),
                                  const SizedBox(width: 10),
                                  Expanded(
                                    child: Text(
                                      'Los cambios se integrarán inmediatamente. Revisa lo importante.',
                                      style: TextStyle(
                                        color: palette.textPrimary,
                                        fontSize: 13,
                                        height: 1.45,
                                        fontWeight: FontWeight.w600,
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            const SizedBox(height: 8),
                            Text(
                              'Los archivos seleccionados se copiarán al sandbox en la nube. Al responder Coder, los archivos modificados y eliminados se sincronizarán con esta carpeta.',
                              style: TextStyle(
                                color: palette.textSecondary,
                                fontSize: 12,
                                height: 1.4,
                              ),
                            ),
                          ],
                        ],
                      ),
              ),
            ),
            if (_errorText != null) ...[
              const SizedBox(height: 12),
              Text(
                _errorText!,
                style: const TextStyle(color: Colors.redAccent, fontSize: 13),
              ),
            ],
            const SizedBox(height: 18),
            SizedBox(
              width: double.infinity,
              height: 52,
              child: ElevatedButton(
                onPressed: _isCreating
                    ? null
                    : (_step == 0
                          ? _nextStep
                          : (canCreate ? _createProject : null)),
                style: ElevatedButton.styleFrom(
                  backgroundColor: palette.accent,
                  foregroundColor: Colors.black,
                  disabledBackgroundColor: palette.accent.withValues(
                    alpha: 0.35,
                  ),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(14),
                  ),
                ),
                child: _isCreating
                    ? Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          const SizedBox(
                            width: 20,
                            height: 20,
                            child: NumiLoadingAnimation(),
                          ),
                          const SizedBox(width: 10),
                          Text(
                            _projectType == 'local'
                                ? 'Importando $_importProgress archivos…'
                                : 'Creando proyecto…',
                            style: const TextStyle(
                              fontWeight: FontWeight.w800,
                              fontSize: 14,
                            ),
                          ),
                        ],
                      )
                    : Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Text(
                            _step == 0 ? 'Siguiente' : 'Crear proyecto',
                            style: const TextStyle(
                              fontWeight: FontWeight.w800,
                              fontSize: 15,
                            ),
                          ),
                          const SizedBox(width: 8),
                          Icon(
                            _step == 0
                                ? LucideIcons.arrowRight
                                : LucideIcons.check,
                            size: 18,
                          ),
                        ],
                      ),
              ),
            ),
            const SizedBox(height: 12),
            Text(
              'No se mostrarán los árboles de dependencias ni arquitectura en este flujo. Coder trabajará con los archivos que tenga el sandbox.',
              textAlign: TextAlign.center,
              style: TextStyle(
                color: palette.textSecondary,
                fontSize: 12,
                height: 1.4,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _stepIndicator(
    AppPalette palette, {
    required String number,
    required String label,
    required bool selected,
    required bool complete,
  }) {
    final color = selected || complete ? palette.accent : palette.textSecondary;
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 28,
            height: 28,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: selected || complete
                  ? palette.accent.withValues(alpha: 0.15)
                  : palette.surface,
              border: Border.all(color: color.withValues(alpha: 0.75)),
            ),
            child: Text(
              number,
              style: TextStyle(
                color: color,
                fontSize: 12,
                fontWeight: FontWeight.w800,
              ),
            ),
          ),
          const SizedBox(width: 7),
          Text(
            label,
            style: TextStyle(
              color: color,
              fontSize: 12,
              fontWeight: FontWeight.w700,
            ),
          ),
        ],
      ),
    );
  }
}
