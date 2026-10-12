import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lucide_flutter/lucide_flutter.dart';

import '../../core/dependency_analyzer.dart';
import '../../core/models.dart';
import '../../core/theme_controller.dart';

class DependencyMapScreen extends ConsumerStatefulWidget {
  const DependencyMapScreen({
    super.key,
    required this.projectId,
    required this.files,
  });

  final String projectId;
  final List<FileItem> files;

  @override
  ConsumerState<DependencyMapScreen> createState() =>
      _DependencyMapScreenState();
}

class _DependencyMapScreenState extends ConsumerState<DependencyMapScreen> {
  late final List<FileItem> _files;
  late final List<DependencyEdge> _edges;
  String? _selectedPath;
  final TransformationController _transform = TransformationController();

  @override
  void initState() {
    super.initState();
    _files = widget.files
        .where((file) => !file.isDirectory)
        .toList(growable: false);
    _edges = analyzeDependencies(_files);
    _selectedPath = _files.isEmpty ? null : _files.first.path;
  }

  @override
  void dispose() {
    _transform.dispose();
    super.dispose();
  }

  FileItem? get _selected {
    for (final file in _files) {
      if (file.path == _selectedPath) {
        return file;
      }
    }
    return null;
  }

  @override
  Widget build(BuildContext context) {
    final palette = ref.watch(appPaletteProvider);
    final selected = _selected;
    final incoming =
        selected == null
              ? <String>[]
              : _edges
                    .where((edge) => edge.targetPath == selected.path)
                    .map((edge) => edge.sourcePath)
                    .toSet()
                    .toList()
          ..sort();
    final outgoing =
        selected == null
              ? <String>[]
              : _edges
                    .where((edge) => edge.sourcePath == selected.path)
                    .map((edge) => edge.targetPath)
                    .toSet()
                    .toList()
          ..sort();
    final nodePositions = <String, Offset>{};
    const canvasWidth = 1060.0;
    const nodeWidth = 225.0;
    const nodeHeight = 76.0;
    const horizontalGap = 25.0;
    const columns = 4;
    final incomingRows = math.max(1, (incoming.length / columns).ceil());
    final outgoingRows = math.max(1, (outgoing.length / columns).ceil());
    final canvasHeight = math.max(
      690.0,
      390 + math.max(incomingRows, outgoingRows) * 118.0,
    );

    nodePositions[selected?.path ?? ''] = const Offset(
      (canvasWidth - nodeWidth) / 2,
      300,
    );
    for (var i = 0; i < incoming.length && i < 16; i++) {
      final col = i % columns;
      final row = i ~/ columns;
      nodePositions[incoming[i]] = Offset(
        20 + col * (nodeWidth + horizontalGap),
        36 + row * 112.0,
      );
    }
    for (var i = 0; i < outgoing.length && i < 16; i++) {
      final path = outgoing[i];
      if (nodePositions.containsKey(path)) {
        continue;
      }
      final col = i % columns;
      final row = i ~/ columns;
      nodePositions[path] = Offset(
        20 + col * (nodeWidth + horizontalGap),
        canvasHeight - 105 - row * 112.0,
      );
    }

    final visiblePaths = nodePositions.keys
        .where((path) => path.isNotEmpty)
        .toSet();
    final visibleEdges = _edges
        .where(
          (edge) =>
              visiblePaths.contains(edge.sourcePath) &&
              visiblePaths.contains(edge.targetPath),
        )
        .toList();

    return Scaffold(
      backgroundColor: palette.background,
      appBar: AppBar(
        backgroundColor: palette.background,
        elevation: 0,
        iconTheme: IconThemeData(color: palette.textPrimary),
        title: Text(
          'Mapa de dependencias',
          style: TextStyle(
            color: palette.textPrimary,
            fontWeight: FontWeight.w700,
          ),
        ),
        actions: [
          IconButton(
            tooltip: 'Restablecer zoom',
            onPressed: () => _transform.value = Matrix4.identity(),
            icon: const Icon(LucideIcons.scan),
          ),
        ],
      ),
      body: _files.isEmpty
          ? Center(
              child: Padding(
                padding: const EdgeInsets.all(28),
                child: Text(
                  'Este proyecto aún no tiene archivos para analizar.',
                  style: TextStyle(color: palette.textSecondary),
                ),
              ),
            )
          : Column(
              children: [
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 4, 16, 10),
                  child: Container(
                    padding: const EdgeInsets.all(13),
                    decoration: BoxDecoration(
                      color: palette.surface,
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(color: palette.border),
                    ),
                    child: Row(
                      children: [
                        Icon(
                          LucideIcons.gitFork,
                          color: palette.accent,
                          size: 20,
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                selected?.path ?? 'Selecciona un archivo',
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: TextStyle(
                                  color: palette.textPrimary,
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                              const SizedBox(height: 3),
                              Text(
                                '${incoming.length} archivo(s) lo referencian · ${outgoing.length} dependencia(s) detectadas',
                                style: TextStyle(
                                  color: palette.textSecondary,
                                  fontSize: 12,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                Expanded(
                  child: InteractiveViewer(
                    transformationController: _transform,
                    constrained: false,
                    minScale: .35,
                    maxScale: 2.2,
                    boundaryMargin: const EdgeInsets.all(180),
                    child: SizedBox(
                      width: canvasWidth,
                      height: canvasHeight,
                      child: Stack(
                        children: [
                          Positioned.fill(
                            child: CustomPaint(
                              painter: _DependencyPainter(
                                positions: nodePositions,
                                edges: visibleEdges,
                                nodeSize: const Size(nodeWidth, nodeHeight),
                                color: palette.accent,
                                lineColor: palette.border,
                              ),
                            ),
                          ),
                          for (final entry in nodePositions.entries)
                            if (entry.key.isNotEmpty)
                              Positioned(
                                left: entry.value.dx,
                                top: entry.value.dy,
                                width: nodeWidth,
                                height: nodeHeight,
                                child: _DependencyNode(
                                  path: entry.key,
                                  selected: entry.key == _selectedPath,
                                  incoming: incoming.contains(entry.key),
                                  palette: palette,
                                  onTap: () =>
                                      setState(() => _selectedPath = entry.key),
                                ),
                              ),
                          if (selected != null &&
                              incoming.isEmpty &&
                              outgoing.isEmpty)
                            Positioned(
                              left: 300,
                              top: 410,
                              width: 460,
                              child: Text(
                                'No se detectaron dependencias directas. Comprueba que el proyecto incluya sus archivos fuente.',
                                textAlign: TextAlign.center,
                                style: TextStyle(color: palette.textSecondary),
                              ),
                            ),
                        ],
                      ),
                    ),
                  ),
                ),
                SafeArea(
                  top: false,
                  child: Container(
                    padding: const EdgeInsets.fromLTRB(16, 10, 16, 12),
                    decoration: BoxDecoration(
                      color: palette.surface,
                      border: Border(top: BorderSide(color: palette.border)),
                    ),
                    child: Row(
                      children: [
                        Expanded(
                          child: Text(
                            'Las llamadas entre funciones se infieren por texto y pueden requerir confirmación.',
                            style: TextStyle(
                              color: palette.textSecondary,
                              fontSize: 11,
                              height: 1.35,
                            ),
                          ),
                        ),
                        const SizedBox(width: 12),
                        FilledButton.icon(
                          onPressed: selected == null
                              ? null
                              : () => Navigator.of(context).pop(selected),
                          icon: const Icon(LucideIcons.fileCode2, size: 17),
                          label: const Text('Abrir archivo'),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
    );
  }
}

class _DependencyNode extends StatelessWidget {
  const _DependencyNode({
    required this.path,
    required this.selected,
    required this.incoming,
    required this.palette,
    required this.onTap,
  });

  final String path;
  final bool selected;
  final bool incoming;
  final dynamic palette;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        borderRadius: BorderRadius.circular(14),
        onTap: onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 180),
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 9),
          decoration: BoxDecoration(
            color: selected
                ? palette.accent.withValues(alpha: .16)
                : palette.surface,
            border: Border.all(
              color: selected ? palette.accent : palette.border,
              width: selected ? 1.5 : 1,
            ),
            borderRadius: BorderRadius.circular(14),
            boxShadow: selected
                ? [
                    BoxShadow(
                      color: palette.accent.withValues(alpha: .12),
                      blurRadius: 18,
                      spreadRadius: 1,
                    ),
                  ]
                : null,
          ),
          child: Row(
            children: [
              Icon(
                selected
                    ? LucideIcons.fileCode2
                    : incoming
                    ? LucideIcons.cornerLeftUp
                    : LucideIcons.cornerRightDown,
                size: 17,
                color: selected ? palette.accent : palette.textSecondary,
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  path,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    color: palette.textPrimary,
                    fontSize: 11,
                    fontWeight: selected ? FontWeight.w800 : FontWeight.w600,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _DependencyPainter extends CustomPainter {
  const _DependencyPainter({
    required this.positions,
    required this.edges,
    required this.nodeSize,
    required this.color,
    required this.lineColor,
  });

  final Map<String, Offset> positions;
  final List<DependencyEdge> edges;
  final Size nodeSize;
  final Color color;
  final Color lineColor;

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.5
      ..color = lineColor.withValues(alpha: .9);
    for (final edge in edges) {
      final source = positions[edge.sourcePath];
      final target = positions[edge.targetPath];
      if (source == null || target == null) {
        continue;
      }
      final a = Offset(
        source.dx + nodeSize.width / 2,
        source.dy + nodeSize.height / 2,
      );
      final b = Offset(
        target.dx + nodeSize.width / 2,
        target.dy + nodeSize.height / 2,
      );
      final delta = b - a;
      if (delta.distance < 4) {
        continue;
      }
      final path = Path()
        ..moveTo(a.dx, a.dy)
        ..cubicTo(
          a.dx,
          a.dy + delta.dy * .35,
          b.dx,
          b.dy - delta.dy * .35,
          b.dx,
          b.dy,
        );
      canvas.drawPath(path, paint);
      final angle = math.atan2(delta.dy, delta.dx);
      final arrowPaint = Paint()
        ..color = color
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.8
        ..strokeCap = StrokeCap.round;
      final arrow = Path()
        ..moveTo(
          b.dx - 9 * math.cos(angle - .45),
          b.dy - 9 * math.sin(angle - .45),
        )
        ..lineTo(b.dx, b.dy)
        ..lineTo(
          b.dx - 9 * math.cos(angle + .45),
          b.dy - 9 * math.sin(angle + .45),
        );
      canvas.drawPath(arrow, arrowPaint);
    }
  }

  @override
  bool shouldRepaint(covariant _DependencyPainter oldDelegate) =>
      oldDelegate.positions != positions ||
      oldDelegate.edges != edges ||
      oldDelegate.color != color ||
      oldDelegate.lineColor != lineColor;
}
