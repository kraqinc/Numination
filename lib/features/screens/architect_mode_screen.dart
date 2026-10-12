import 'dart:convert';
import 'dart:math' as math;

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter/services.dart';
import 'package:lucide_flutter/lucide_flutter.dart';

import '../../core/dependency_analyzer.dart';
import '../../core/models.dart';
import '../../core/theme_controller.dart';

class ArchitectModeScreen extends ConsumerStatefulWidget {
  const ArchitectModeScreen({
    super.key,
    required this.projectName,
    required this.projectId,
    required this.files,
  });

  final String projectName;
  final String projectId;
  final List<FileItem> files;

  @override
  ConsumerState<ArchitectModeScreen> createState() =>
      _ArchitectModeScreenState();
}

class _ArchitectModeScreenState extends ConsumerState<ArchitectModeScreen> {
  late final List<FileItem> _files;
  late final List<DependencyEdge> _initialEdges;
  late final Map<String, DependencyEdge> _initialByKey;
  final Map<String, DependencyEdge> _desiredEdges = <String, DependencyEdge>{};
  final TransformationController _transform = TransformationController();
  String? _selectedPath;

  @override
  void initState() {
    super.initState();
    _files = widget.files
        .where((file) => !file.isDirectory)
        .toList(growable: false);
    _initialEdges = analyzeDependencies(_files);
    _initialByKey = {for (final edge in _initialEdges) edge.key: edge};
    _desiredEdges.addAll(_initialByKey);
    _selectedPath = _files.isEmpty ? null : _files.first.path;
  }

  @override
  void dispose() {
    _transform.dispose();
    super.dispose();
  }

  String _nodeId(String path) => 'f${path.hashCode.abs()}';

  String _mermaid() {
    final visibleFiles = _files;
    final out = StringBuffer('flowchart LR\n');
    for (final file in visibleFiles) {
      final label = file.path
          .replaceAll('"', '\\"')
          .replaceAll('[', '(')
          .replaceAll(']', ')');
      out.writeln('  ${_nodeId(file.path)}["$label"]');
    }
    for (final edge in _desiredEdges.values) {
      out.writeln(
        '  ${_nodeId(edge.sourcePath)} -->|${edge.reason.replaceAll('|', '/')}| ${_nodeId(edge.targetPath)}',
      );
    }
    return out.toString();
  }

  String _jsonExport() => const JsonEncoder.withIndent('  ').convert({
    'project': widget.projectName,
    'projectId': widget.projectId,
    'exportedAt': DateTime.now().toUtc().toIso8601String(),
    'analysisNote':
        'File imports are parsed; function-reference edges are heuristic and should be reviewed.',
    'files': _files
        .map(
          (file) => {
            'id': _nodeId(file.path),
            'path': file.path,
            'layer': architectureLayer(file.path),
          },
        )
        .toList(),
    'relationships': _desiredEdges.values
        .map(
          (edge) => {
            'source': edge.sourcePath,
            'target': edge.targetPath,
            'reason': edge.reason,
          },
        )
        .toList(),
  });

  Future<void> _export(String extension) async {
    final content = extension == 'json' ? _jsonExport() : _mermaid();
    final safeName = widget.projectName.toLowerCase().replaceAll(
      RegExp(r'[^a-z0-9_-]+'),
      '-',
    );
    try {
      await FilePicker.saveFile(
        dialogTitle: 'Exportar mapa de arquitectura',
        fileName:
            '${safeName.isEmpty ? 'numination' : safeName}-architecture.$extension',
        type: FileType.custom,
        allowedExtensions: [extension],
        bytes: Uint8List.fromList(utf8.encode(content)),
      );
    } catch (_) {
      if (!mounted) {
        return;
      }
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('No pudimos exportar el diagrama en este dispositivo.'),
        ),
      );
    }
  }

  Future<void> _addRelationship() async {
    if (_files.length < 2) {
      return;
    }
    final edge = await showModalBottomSheet<DependencyEdge>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      builder: (context) => _RelationshipForm(files: _files),
    );
    if (edge == null || !mounted) {
      return;
    }
    setState(() => _desiredEdges[edge.key] = edge);
  }

  void _removeRelationship(DependencyEdge edge) {
    setState(() => _desiredEdges.remove(edge.key));
  }

  Future<void> _copyMermaid() async {
    await Clipboard.setData(ClipboardData(text: _mermaid()));
    if (!mounted) {
      return;
    }
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(const SnackBar(content: Text('Diagrama Mermaid copiado.')));
  }

  String _buildImplementationPrompt() {
    final added = _desiredEdges.values
        .where((edge) => !_initialByKey.containsKey(edge.key))
        .toList();
    final removed = _initialEdges
        .where((edge) => !_desiredEdges.containsKey(edge.key))
        .toList();
    final out = StringBuffer()
      ..writeln('MODO ARQUITECTO — proyecto: ${widget.projectName}')
      ..writeln('Proyecto ID: ${widget.projectId}')
      ..writeln(
        'Analiza el repositorio completo y convierte el diagrama deseado en cambios coherentes de código. No inventes archivos ni funciones: inspecciona el código real antes de modificarlo.',
      )
      ..writeln('\nRELACIONES QUE DEBEN EXISTIR:');
    if (added.isEmpty) {
      out.writeln(
        '- No se añadieron relaciones nuevas al diagrama. Revisa las relaciones actuales y propón correcciones arquitectónicas si detectas inconsistencias.',
      );
    } else {
      for (final edge in added) {
        out.writeln(
          '- ${edge.sourcePath} → ${edge.targetPath} (${edge.reason})',
        );
      }
    }
    out.writeln('\nRELACIONES QUE DEBEN ELIMINARSE O DESACOPLARSE:');
    if (removed.isEmpty) {
      out.writeln('- Ninguna relación fue retirada del diagrama.');
    } else {
      for (final edge in removed) {
        out.writeln(
          '- ${edge.sourcePath} → ${edge.targetPath} (${edge.reason})',
        );
      }
    }
    out
      ..writeln('\nREQUISITOS:')
      ..writeln(
        '- Mantén las capas Core, UI, Datos y Backend separadas cuando corresponda.',
      )
      ..writeln('- Evita ciclos de dependencias y no dupliques lógica.')
      ..writeln(
        '- Respeta autenticación, autorización, RLS, manejo de errores y secretos del proyecto.',
      )
      ..writeln(
        '- Revisa los archivos relacionados antes de editar y explica las consecuencias de cada cambio.',
      )
      ..writeln(
        '- Mantén o actualiza pruebas relevantes y muestra el diff para revisión.',
      )
      ..writeln(
        '- No hagas commit, push ni crees un PR automáticamente. Deja los cambios en el workspace para revisión manual.',
      )
      ..writeln('\nDIAGRAMA DESEADO EN MERMAID:\n${_mermaid()}');
    return out.toString();
  }

  void _sendToCoder() {
    Navigator.of(context).pop(_buildImplementationPrompt());
  }

  @override
  Widget build(BuildContext context) {
    final palette = ref.watch(appPaletteProvider);
    final files = _files;
    const nodeWidth = 215.0;
    const nodeHeight = 70.0;
    const hGap = 28.0;
    const vGap = 26.0;
    const columns = 7;
    final grouped = <String, List<FileItem>>{};
    for (final file in files) {
      grouped
          .putIfAbsent(architectureLayer(file.path), () => <FileItem>[])
          .add(file);
    }
    const layers = [
      'Core',
      'Data',
      'Backend',
      'Modelos',
      'UI',
      'Tests',
      'Otros',
    ];
    final positions = <String, Offset>{};
    var maxRows = 1;
    for (var column = 0; column < layers.length; column++) {
      final layerFiles = grouped[layers[column]] ?? const <FileItem>[];
      maxRows = math.max(maxRows, layerFiles.length);
      for (var row = 0; row < layerFiles.length; row++) {
        positions[layerFiles[row].path] = Offset(
          16 + column * (nodeWidth + hGap),
          48 + row * (nodeHeight + vGap),
        );
      }
    }
    const canvasWidth = 16 + columns * (nodeWidth + hGap);
    final canvasHeight = math.max(520.0, 100 + maxRows * (nodeHeight + vGap));
    final selectedEdges = _desiredEdges.values.toList()
      ..sort((a, b) => a.sourcePath.compareTo(b.sourcePath));
    final addedCount = _desiredEdges.keys
        .where((key) => !_initialByKey.containsKey(key))
        .length;
    final removedCount = _initialEdges
        .where((edge) => !_desiredEdges.containsKey(edge.key))
        .length;

    return Scaffold(
      backgroundColor: palette.background,
      appBar: AppBar(
        backgroundColor: palette.background,
        elevation: 0,
        iconTheme: IconThemeData(color: palette.textPrimary),
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Modo Arquitecto',
              style: TextStyle(
                color: palette.textPrimary,
                fontWeight: FontWeight.w800,
              ),
            ),
            Text(
              widget.projectName,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(color: palette.textSecondary, fontSize: 11),
            ),
          ],
        ),
        actions: [
          PopupMenuButton<String>(
            tooltip: 'Exportar diagrama',
            icon: const Icon(LucideIcons.download),
            onSelected: (value) => _export(value),
            itemBuilder: (_) => const [
              PopupMenuItem(
                value: 'mmd',
                child: Text('Exportar Mermaid (.mmd)'),
              ),
              PopupMenuItem(
                value: 'json',
                child: Text('Exportar JSON (.json)'),
              ),
            ],
          ),
          IconButton(
            tooltip: 'Copiar Mermaid',
            onPressed: _copyMermaid,
            icon: const Icon(LucideIcons.copy),
          ),
        ],
      ),
      body: files.isEmpty
          ? Center(
              child: Text(
                'No hay archivos para construir el diagrama.',
                style: TextStyle(color: palette.textSecondary),
              ),
            )
          : Column(
              children: [
                Padding(
                  padding: const EdgeInsets.fromLTRB(14, 4, 14, 10),
                  child: Container(
                    padding: const EdgeInsets.all(14),
                    decoration: BoxDecoration(
                      color: palette.surface,
                      border: Border.all(color: palette.border),
                      borderRadius: BorderRadius.circular(18),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Icon(LucideIcons.workflow, color: palette.accent),
                            const SizedBox(width: 9),
                            Expanded(
                              child: Text(
                                'Mapa bidireccional del repositorio',
                                style: TextStyle(
                                  color: palette.textPrimary,
                                  fontWeight: FontWeight.w800,
                                ),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 6),
                        Text(
                          'Mueve el lienzo, selecciona componentes y edita relaciones. Las relaciones propuestas se convierten en una instrucción para Coder; el código no cambia hasta que la revises y la envíes.',
                          style: TextStyle(
                            color: palette.textSecondary,
                            fontSize: 12,
                            height: 1.45,
                          ),
                        ),
                        const SizedBox(height: 11),
                        Wrap(
                          spacing: 7,
                          runSpacing: 7,
                          children: [
                            _CountPill(
                              label: '${files.length} archivos',
                              icon: LucideIcons.fileCode2,
                              color: palette.textSecondary,
                            ),
                            _CountPill(
                              label: '${_desiredEdges.length} relaciones',
                              icon: LucideIcons.gitFork,
                              color: palette.accent,
                            ),
                            if (addedCount > 0)
                              _CountPill(
                                label: '+$addedCount nuevas',
                                icon: LucideIcons.plus,
                                color: palette.accent,
                              ),
                            if (removedCount > 0)
                              _CountPill(
                                label: '−$removedCount retiradas',
                                icon: LucideIcons.minus,
                                color: palette.textSecondary,
                              ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ),
                Expanded(
                  child: InteractiveViewer(
                    transformationController: _transform,
                    constrained: false,
                    minScale: .24,
                    maxScale: 2.0,
                    boundaryMargin: const EdgeInsets.all(200),
                    child: SizedBox(
                      width: canvasWidth,
                      height: canvasHeight,
                      child: Stack(
                        children: [
                          Positioned.fill(
                            child: CustomPaint(
                              painter: _ArchitecturePainter(
                                positions: positions,
                                edges: selectedEdges,
                                nodeSize: const Size(nodeWidth, nodeHeight),
                                accent: palette.accent,
                                line: palette.border,
                              ),
                            ),
                          ),
                          for (var column = 0; column < layers.length; column++)
                            Positioned(
                              left: 16 + column * (nodeWidth + hGap),
                              top: 12,
                              width: nodeWidth,
                              child: Text(
                                layers[column],
                                style: TextStyle(
                                  color: palette.textSecondary,
                                  fontSize: 12,
                                  fontWeight: FontWeight.w800,
                                ),
                              ),
                            ),
                          for (final entry in positions.entries)
                            Positioned(
                              left: entry.value.dx,
                              top: entry.value.dy,
                              width: nodeWidth,
                              height: nodeHeight,
                              child: Material(
                                color: Colors.transparent,
                                child: InkWell(
                                  borderRadius: BorderRadius.circular(14),
                                  onTap: () =>
                                      setState(() => _selectedPath = entry.key),
                                  child: AnimatedContainer(
                                    duration: const Duration(milliseconds: 180),
                                    padding: const EdgeInsets.all(10),
                                    decoration: BoxDecoration(
                                      color: _selectedPath == entry.key
                                          ? palette.accent.withValues(
                                              alpha: .16,
                                            )
                                          : palette.surface,
                                      borderRadius: BorderRadius.circular(14),
                                      border: Border.all(
                                        color: _selectedPath == entry.key
                                            ? palette.accent
                                            : palette.border,
                                        width: _selectedPath == entry.key
                                            ? 1.6
                                            : 1,
                                      ),
                                    ),
                                    child: Row(
                                      children: [
                                        Icon(
                                          _selectedPath == entry.key
                                              ? LucideIcons.workflow
                                              : LucideIcons.fileCode2,
                                          size: 17,
                                          color: _selectedPath == entry.key
                                              ? palette.accent
                                              : palette.textSecondary,
                                        ),
                                        const SizedBox(width: 8),
                                        Expanded(
                                          child: Column(
                                            crossAxisAlignment:
                                                CrossAxisAlignment.start,
                                            mainAxisAlignment:
                                                MainAxisAlignment.center,
                                            children: [
                                              Text(
                                                entry.key.split('/').last,
                                                maxLines: 1,
                                                overflow: TextOverflow.ellipsis,
                                                style: TextStyle(
                                                  color: palette.textPrimary,
                                                  fontSize: 12,
                                                  fontWeight: FontWeight.w800,
                                                ),
                                              ),
                                              Text(
                                                entry.key,
                                                maxLines: 1,
                                                overflow: TextOverflow.ellipsis,
                                                style: TextStyle(
                                                  color: palette.textSecondary,
                                                  fontSize: 9,
                                                ),
                                              ),
                                            ],
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                ),
                              ),
                            ),
                        ],
                      ),
                    ),
                  ),
                ),
                Container(
                  constraints: const BoxConstraints(maxHeight: 260),
                  decoration: BoxDecoration(
                    color: palette.surface,
                    border: Border(top: BorderSide(color: palette.border)),
                  ),
                  child: Column(
                    children: [
                      Padding(
                        padding: const EdgeInsets.fromLTRB(16, 10, 16, 4),
                        child: Row(
                          children: [
                            Expanded(
                              child: Text(
                                'Relaciones del diseño',
                                style: TextStyle(
                                  color: palette.textPrimary,
                                  fontWeight: FontWeight.w800,
                                ),
                              ),
                            ),
                            IconButton(
                              tooltip: 'Añadir relación',
                              onPressed: _addRelationship,
                              icon: const Icon(LucideIcons.plus),
                            ),
                          ],
                        ),
                      ),
                      Expanded(
                        child: selectedEdges.isEmpty
                            ? Center(
                                child: Text(
                                  'No hay flechas. Añade una relación para definir la arquitectura.',
                                  style: TextStyle(
                                    color: palette.textSecondary,
                                    fontSize: 12,
                                  ),
                                ),
                              )
                            : ListView.separated(
                                itemCount: selectedEdges.length,
                                separatorBuilder: (_, _) =>
                                    Divider(height: 1, color: palette.border),
                                itemBuilder: (context, index) {
                                  final edge = selectedEdges[index];
                                  final custom = !_initialByKey.containsKey(
                                    edge.key,
                                  );
                                  return ListTile(
                                    dense: true,
                                    leading: Icon(
                                      custom
                                          ? LucideIcons.gitPullRequest
                                          : LucideIcons.arrowRight,
                                      size: 17,
                                      color: custom
                                          ? palette.accent
                                          : palette.textSecondary,
                                    ),
                                    title: Text(
                                      '${edge.sourcePath}  →  ${edge.targetPath}',
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                      style: TextStyle(
                                        color: palette.textPrimary,
                                        fontSize: 11,
                                      ),
                                    ),
                                    subtitle: Text(
                                      edge.reason,
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                      style: TextStyle(
                                        color: palette.textSecondary,
                                        fontSize: 10,
                                      ),
                                    ),
                                    trailing: IconButton(
                                      tooltip: 'Quitar flecha',
                                      visualDensity: VisualDensity.compact,
                                      onPressed: () =>
                                          _removeRelationship(edge),
                                      icon: const Icon(LucideIcons.x, size: 17),
                                    ),
                                  );
                                },
                              ),
                      ),
                    ],
                  ),
                ),
                SafeArea(
                  top: false,
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(14, 10, 14, 12),
                    child: SizedBox(
                      width: double.infinity,
                      child: FilledButton.icon(
                        onPressed: _sendToCoder,
                        icon: const Icon(LucideIcons.sparkles, size: 18),
                        label: const Text('Preparar cambios en Coder'),
                      ),
                    ),
                  ),
                ),
              ],
            ),
    );
  }
}

class _CountPill extends StatelessWidget {
  const _CountPill({
    required this.label,
    required this.icon,
    required this.color,
  });
  final String label;
  final IconData icon;
  final Color color;

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 6),
    decoration: BoxDecoration(
      color: color.withValues(alpha: .1),
      borderRadius: BorderRadius.circular(30),
    ),
    child: Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, color: color, size: 14),
        const SizedBox(width: 5),
        Text(
          label,
          style: TextStyle(
            color: color,
            fontSize: 11,
            fontWeight: FontWeight.w700,
          ),
        ),
      ],
    ),
  );
}

class _RelationshipForm extends StatefulWidget {
  const _RelationshipForm({required this.files});
  final List<FileItem> files;

  @override
  State<_RelationshipForm> createState() => _RelationshipFormState();
}

class _RelationshipFormState extends State<_RelationshipForm> {
  String? _source;
  String? _target;
  final _reasonController = TextEditingController(text: 'relación propuesta');

  @override
  void initState() {
    super.initState();
    _source = widget.files.isEmpty ? null : widget.files.first.path;
    _target = widget.files.length < 2 ? null : widget.files[1].path;
  }

  @override
  void dispose() {
    _reasonController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.fromLTRB(
        18,
        12,
        18,
        MediaQuery.viewInsetsOf(context).bottom + 22,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const Text(
            'Añadir flecha',
            style: TextStyle(fontSize: 19, fontWeight: FontWeight.w800),
          ),
          const SizedBox(height: 14),
          DropdownButtonFormField<String>(
            initialValue: _source,
            isExpanded: true,
            decoration: const InputDecoration(labelText: 'Desde el archivo'),
            items: widget.files
                .map(
                  (file) => DropdownMenuItem(
                    value: file.path,
                    child: Text(file.path, overflow: TextOverflow.ellipsis),
                  ),
                )
                .toList(),
            onChanged: (value) => setState(() => _source = value),
          ),
          const SizedBox(height: 10),
          DropdownButtonFormField<String>(
            initialValue: _target,
            isExpanded: true,
            decoration: const InputDecoration(labelText: 'Hacia el archivo'),
            items: widget.files
                .map(
                  (file) => DropdownMenuItem(
                    value: file.path,
                    child: Text(file.path, overflow: TextOverflow.ellipsis),
                  ),
                )
                .toList(),
            onChanged: (value) => setState(() => _target = value),
          ),
          const SizedBox(height: 10),
          TextField(
            controller: _reasonController,
            maxLength: 100,
            decoration: const InputDecoration(
              labelText: 'Propósito (opcional)',
              hintText: 'p. ej. importa, usa, depende de',
            ),
          ),
          const SizedBox(height: 12),
          FilledButton.icon(
            onPressed: _source == null || _target == null || _source == _target
                ? null
                : () {
                    Navigator.pop(
                      context,
                      DependencyEdge(
                        sourcePath: _source!,
                        targetPath: _target!,
                        reason: _reasonController.text.trim().isEmpty
                            ? 'relación propuesta'
                            : _reasonController.text.trim(),
                      ),
                    );
                  },
            icon: const Icon(LucideIcons.gitBranch),
            label: const Text('Añadir relación'),
          ),
        ],
      ),
    );
  }
}

class _ArchitecturePainter extends CustomPainter {
  const _ArchitecturePainter({
    required this.positions,
    required this.edges,
    required this.nodeSize,
    required this.accent,
    required this.line,
  });
  final Map<String, Offset> positions;
  final List<DependencyEdge> edges;
  final Size nodeSize;
  final Color accent;
  final Color line;

  @override
  void paint(Canvas canvas, Size size) {
    for (final edge in edges) {
      final start = positions[edge.sourcePath];
      final end = positions[edge.targetPath];
      if (start == null || end == null) {
        continue;
      }
      final a = Offset(
        start.dx + nodeSize.width / 2,
        start.dy + nodeSize.height / 2,
      );
      final b = Offset(
        end.dx + nodeSize.width / 2,
        end.dy + nodeSize.height / 2,
      );
      final delta = b - a;
      if (delta.distance < 3) {
        continue;
      }
      final isProposed = edge.reason.contains('propuesta');
      final paint = Paint()
        ..color = isProposed
            ? accent.withValues(alpha: .85)
            : line.withValues(alpha: .85)
        ..style = PaintingStyle.stroke
        ..strokeWidth = isProposed ? 2.0 : 1.2;
      final path = Path()
        ..moveTo(a.dx, a.dy)
        ..cubicTo(
          a.dx + delta.dx * .4,
          a.dy,
          b.dx - delta.dx * .4,
          b.dy,
          b.dx,
          b.dy,
        );
      canvas.drawPath(path, paint);
      final angle = math.atan2(delta.dy, delta.dx);
      final arrowPaint = Paint()
        ..color = isProposed ? accent : line
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.6
        ..strokeCap = StrokeCap.round;
      final arrow = Path()
        ..moveTo(
          b.dx - 8 * math.cos(angle - .5),
          b.dy - 8 * math.sin(angle - .5),
        )
        ..lineTo(b.dx, b.dy)
        ..lineTo(
          b.dx - 8 * math.cos(angle + .5),
          b.dy - 8 * math.sin(angle + .5),
        );
      canvas.drawPath(arrow, arrowPaint);
    }
  }

  @override
  bool shouldRepaint(covariant _ArchitecturePainter oldDelegate) =>
      oldDelegate.positions != positions ||
      oldDelegate.edges != edges ||
      oldDelegate.accent != accent ||
      oldDelegate.line != line;
}
