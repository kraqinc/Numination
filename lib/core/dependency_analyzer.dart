import 'models.dart';

class DependencyEdge {
  const DependencyEdge({
    required this.sourcePath,
    required this.targetPath,
    required this.reason,
  });

  final String sourcePath;
  final String targetPath;
  final String reason;

  String get key => '$sourcePath\u0000$targetPath';
}

List<String> _functionNames(String content) {
  final names = <String>{};
  final patterns = <RegExp>[
    RegExp(
      r'\b(?:async\s+)?(?:function|def|class)\s+([A-Za-z_$][\w$]*)',
      multiLine: true,
    ),
    RegExp(
      r'^\s*(?:export\s+)?(?:async\s+)?(?:const|let|var)\s+([A-Za-z_$][\w$]*)\s*=\s*(?:async\s*)?(?:\([^)]*\)|[A-Za-z_$][\w$]*)\s*=>',
      multiLine: true,
    ),
    RegExp(
      r'\b(?:static\s+)?(?:Future<[^>]+>|void|dynamic|String|int|bool|Widget|Response|Map<[^>]+>|List<[^>]+>)\s+([A-Za-z_$][\w$]*)\s*\(',
      multiLine: true,
    ),
  ];
  for (final pattern in patterns) {
    for (final match in pattern.allMatches(content)) {
      final name = match.group(1);
      if (name != null &&
          name.length >= 4 &&
          !_commonFunctionNames.contains(name)) {
        names.add(name);
      }
    }
  }
  return names.toList(growable: false);
}

const _commonFunctionNames = <String>{
  'build',
  'init',
  'main',
  'dispose',
  'copyWith',
  'toJson',
  'fromJson',
  'toString',
  'hashCode',
  'notifyListeners',
  'setState',
  'render',
  'update',
  'create',
  'delete',
  'write',
  'read',
  'test',
  'close',
  'open',
  'get',
  'set',
  'map',
  'where',
  'fold',
  'reduce',
  'listen',
};

String _normalizePath(String input) {
  final output = <String>[];
  for (final part in input.replaceAll('\\', '/').split('/')) {
    if (part.isEmpty || part == '.') {
      continue;
    }
    if (part == '..') {
      if (output.isNotEmpty) {
        output.removeLast();
      }
    } else {
      output.add(part);
    }
  }
  return output.join('/');
}

String? _resolveImport(
  String fromPath,
  String rawImport,
  Map<String, String> knownPaths,
) {
  var specifier = rawImport.trim();
  if (specifier.isEmpty ||
      specifier.startsWith('http:') ||
      specifier.startsWith('https:')) {
    return null;
  }
  if (specifier.startsWith('package:')) {
    final packagePath = specifier.substring('package:'.length);
    final slash = packagePath.indexOf('/');
    if (slash < 0) {
      return null;
    }
    specifier = 'lib/${packagePath.substring(slash + 1)}';
  }
  final isRelative = specifier.startsWith('.') || specifier.startsWith('/');
  if (!isRelative && !rawImport.startsWith('package:')) {
    final pythonPath = specifier.replaceAll('.', '/');
    final candidates = <String>{
      pythonPath,
      '$pythonPath.py',
      '$pythonPath/__init__.py',
    };
    for (final candidate in candidates) {
      final found = knownPaths[candidate];
      if (found != null) {
        return found;
      }
    }
    return null;
  }

  final base = isRelative && !specifier.startsWith('/')
      ? fromPath.substring(
          0,
          fromPath.lastIndexOf('/') < 0 ? 0 : fromPath.lastIndexOf('/') + 1,
        )
      : '';
  final normalized = _normalizePath('$base$specifier');
  final candidates = <String>{normalized};
  if (!RegExp(r'\.[A-Za-z0-9]+$').hasMatch(normalized)) {
    for (final extension in const [
      '.dart',
      '.ts',
      '.tsx',
      '.js',
      '.jsx',
      '.mjs',
      '.cjs',
      '.py',
      '.vue',
      '.css',
      '.json',
      '.html',
    ]) {
      candidates.add('$normalized$extension');
    }
    for (final extension in const [
      '.dart',
      '.ts',
      '.tsx',
      '.js',
      '.jsx',
      '.py',
    ]) {
      candidates.add('$normalized/index$extension');
    }
  }
  for (final candidate in candidates) {
    final found = knownPaths[candidate];
    if (found != null) {
      return found;
    }
  }
  return null;
}

List<DependencyEdge> analyzeDependencies(List<FileItem> input) {
  final files = input
      .where((file) => !file.isDirectory && file.path.trim().isNotEmpty)
      .toList();
  final pathMap = <String, String>{};
  for (final file in files) {
    pathMap[_normalizePath(file.path)] = file.path;
  }

  final edges = <String, DependencyEdge>{};
  final importPatterns = <RegExp>[
    RegExp(
      r'''\b(?:import|export|part)(?:\s+type)?\s+(?:[^'";]*?\s+from\s+)?['"]([^'"]+)['"]''',
    ),
    RegExp(r'''\brequire\s*\(\s*['"]([^'"]+)['"]\s*\)'''),
    RegExp(r'''^\s*from\s+([.\w]+)\s+import\s+''', multiLine: true),
    RegExp(r'''^\s*import\s+([\w.]+)\s*$''', multiLine: true),
  ];

  for (final file in files) {
    for (final pattern in importPatterns) {
      for (final match in pattern.allMatches(file.content)) {
        final raw = match.group(1);
        if (raw == null) {
          continue;
        }
        final target = _resolveImport(file.path, raw, pathMap);
        if (target == null || target == file.path) {
          continue;
        }
        final edge = DependencyEdge(
          sourcePath: file.path,
          targetPath: target,
          reason: 'importa',
        );
        edges[edge.key] = edge;
      }
    }
  }

  // Symbol scanning is heuristic: these edges are hints, not a compiler call graph.
  final symbolsByPath = <String, List<String>>{
    for (final file in files) file.path: _functionNames(file.content),
  };
  for (final source in files) {
    for (final target in files) {
      if (source.path == target.path) {
        continue;
      }
      final matching = (symbolsByPath[target.path] ?? const <String>[])
          .where(
            (name) => RegExp(
              '\\b${RegExp.escape(name)}\\s*\\(',
            ).hasMatch(source.content),
          )
          .take(3)
          .toList();
      if (matching.isEmpty) {
        continue;
      }
      final key = '${source.path}\u0000${target.path}';
      if (edges.containsKey(key)) {
        final previous = edges[key]!;
        edges[key] = DependencyEdge(
          sourcePath: previous.sourcePath,
          targetPath: previous.targetPath,
          reason: 'importa; referencia ${matching.join(', ')}',
        );
      } else {
        final edge = DependencyEdge(
          sourcePath: source.path,
          targetPath: target.path,
          reason: 'referencia probable: ${matching.join(', ')}',
        );
        edges[key] = edge;
      }
    }
  }

  final result = edges.values.toList()
    ..sort((a, b) {
      final bySource = a.sourcePath.compareTo(b.sourcePath);
      return bySource != 0 ? bySource : a.targetPath.compareTo(b.targetPath);
    });
  return result;
}

String architectureLayer(String path) {
  final normalized = path.toLowerCase().replaceAll('\\', '/');
  if (normalized.contains('/test/') || normalized.startsWith('test/')) {
    return 'Tests';
  }
  if (normalized.contains('/api/') ||
      normalized.contains('/backend/') ||
      normalized.contains('/server/')) {
    return 'Backend';
  }
  if (normalized.contains('/core/') || normalized.contains('/lib/core/')) {
    return 'Core';
  }
  if (normalized.contains('/data/') ||
      normalized.contains('/repository') ||
      normalized.contains('/services/')) {
    return 'Data';
  }
  if (normalized.contains('/screens/') ||
      normalized.contains('/widgets/') ||
      normalized.contains('/components/') ||
      normalized.contains('/ui/')) {
    return 'UI';
  }
  if (normalized.contains('/models/') || normalized.contains('/entities/')) {
    return 'Modelos';
  }
  return 'Otros';
}
