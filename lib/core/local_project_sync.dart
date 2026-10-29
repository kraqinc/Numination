import 'dart:io';

import 'api.dart';
import 'models.dart';

class LocalProjectImportResult {
  const LocalProjectImportResult({
    required this.importedFiles,
    required this.skippedFiles,
  });

  final int importedFiles;
  final int skippedFiles;
}

class LocalProjectSyncResult {
  const LocalProjectSyncResult({
    required this.writtenFiles,
    required this.deletedFiles,
    required this.skippedPaths,
  });

  final int writtenFiles;
  final int deletedFiles;
  final int skippedPaths;
}

class _LocalFile {
  const _LocalFile(this.file, this.relativePath);

  final File file;
  final String relativePath;
}

/// Imports text/source files into the existing cloud sandbox and mirrors the
/// Coder response back to the explicitly selected local directory.
class LocalProjectSyncService {
  LocalProjectSyncService._();

  static const int _maxFiles = 500;
  static const int _maxFileBytes = 1024 * 1024;
  static const int _maxTotalBytes = 20 * 1024 * 1024;

  static const Set<String> _excludedDirectories = {
    '.git',
    'node_modules',
    'build',
    '.dart_tool',
    '.gradle',
    '.idea',
    '.vscode',
    'dist',
    'coverage',
    '.next',
    '.venv',
    'venv',
    'Pods',
    '.symlinks',
    '__pycache__',
    '.cache',
    '.turbo',
  };

  static const Set<String> _textExtensions = {
    'txt',
    'md',
    'mdx',
    'csv',
    'log',
    'diff',
    'patch',
    'ini',
    'conf',
    'dart',
    'py',
    'js',
    'jsx',
    'ts',
    'tsx',
    'json',
    'jsonc',
    'yaml',
    'yml',
    'html',
    'css',
    'scss',
    'sass',
    'less',
    'xml',
    'sql',
    'sh',
    'bash',
    'zsh',
    'kt',
    'kts',
    'java',
    'go',
    'rs',
    'swift',
    'toml',
    'gradle',
    'properties',
    'c',
    'h',
    'cc',
    'cpp',
    'hpp',
    'php',
    'rb',
    'vue',
    'svelte',
    'r',
    'ex',
    'exs',
    'pl',
    'lock',
    'gitignore',
    'dockerignore',
    'editorconfig',
    'makefile',
    'dockerfile',
    'procfile',
    'license',
    'readme',
    'gitattributes',
  };

  static Future<LocalProjectImportResult> importDirectoryToCloud({
    required String projectId,
    required String directoryPath,
    void Function(int current, int total)? onProgress,
  }) async {
    final root = Directory(directoryPath).absolute;
    if (!await root.exists()) {
      throw StateError('La carpeta local ya no está disponible.');
    }

    final rootPath = root.path;
    final prefix = rootPath.endsWith(Platform.pathSeparator)
        ? rootPath
        : '$rootPath${Platform.pathSeparator}';
    final candidates = <_LocalFile>[];
    var skipped = 0;
    var totalBytes = 0;

    final pendingDirectories = <Directory>[root];
    while (pendingDirectories.isNotEmpty) {
      final currentDirectory = pendingDirectories.removeLast();
      await for (final entity in currentDirectory.list(followLinks: false)) {
        if (entity is Directory) {
          final directoryName = entity.path
              .replaceAll('\\', '/')
              .split('/')
              .last;
          if (_excludedDirectories.contains(directoryName)) continue;
          pendingDirectories.add(entity);
          continue;
        }
        if (entity is! File) continue;
        final absolutePath = entity.absolute.path;
        if (!absolutePath.startsWith(prefix)) {
          skipped++;
          continue;
        }

        final relativePath = absolutePath
            .substring(prefix.length)
            .replaceAll(Platform.pathSeparator, '/');
        final segments = relativePath.split('/');
        final fileName = segments.isEmpty ? '' : segments.last;

        if (segments.any(_excludedDirectories.contains) ||
            _isSensitive(fileName)) {
          skipped++;
          continue;
        }
        if (!_isTextFile(fileName)) {
          skipped++;
          continue;
        }

        final length = await entity.length();
        if (length <= 0 || length > _maxFileBytes) {
          skipped++;
          continue;
        }
        totalBytes += length;
        if (totalBytes > _maxTotalBytes) {
          throw StateError(
            'La carpeta supera el límite de 20 MB de texto. Reduce los archivos importados.',
          );
        }
        candidates.add(_LocalFile(entity, relativePath));
        if (candidates.length > _maxFiles) {
          throw StateError(
            'La carpeta contiene más de $_maxFiles archivos compatibles. Reduce la selección.',
          );
        }
      }
    }

    var imported = 0;
    onProgress?.call(0, candidates.length);
    for (final candidate in candidates) {
      String content;
      try {
        content = await candidate.file.readAsString();
      } on FormatException {
        skipped++;
        continue;
      }

      final response = await ApiClient.post(
        '/projects/${Uri.encodeComponent(projectId)}/files',
        {
          'name': candidate.relativePath.split('/').last,
          'path': candidate.relativePath,
          'content': content,
          'isDirectory': false,
          'parentId': null,
        },
      );
      ApiClient.decode(response);
      imported++;
      onProgress?.call(imported, candidates.length);
    }

    return LocalProjectImportResult(
      importedFiles: imported,
      skippedFiles: skipped,
    );
  }

  static Future<LocalProjectSyncResult> syncChangesToLocal({
    required String directoryPath,
    required List<FileItem> cloudFiles,
    required List<String> changedPaths,
    required List<String> deletedPaths,
  }) async {
    final root = Directory(directoryPath).absolute;
    if (!await root.exists()) {
      throw StateError('La carpeta local ya no existe o no está accesible.');
    }

    final byPath = <String, FileItem>{};
    for (final item in cloudFiles) {
      if (item.isDirectory) continue;
      final normalized = _normalizeRelativePath(item.path);
      if (normalized != null) byPath[normalized] = item;
    }

    var written = 0;
    var deleted = 0;
    var skipped = 0;

    for (final rawPath in changedPaths) {
      final relative = _normalizeRelativePath(rawPath);
      if (relative == null) {
        skipped++;
        continue;
      }
      final cloudFile = byPath[relative];
      final targetPath = await _safeTargetPath(root.path, relative);
      if (cloudFile == null || targetPath == null) {
        skipped++;
        continue;
      }
      final target = File(targetPath);
      await target.parent.create(recursive: true);
      await target.writeAsString(cloudFile.content, flush: true);
      written++;
    }

    for (final rawPath in deletedPaths) {
      final relative = _normalizeRelativePath(rawPath);
      if (relative == null) {
        skipped++;
        continue;
      }
      final targetPath = await _safeTargetPath(root.path, relative);
      if (targetPath == null) {
        skipped++;
        continue;
      }
      final target = File(targetPath);
      if (await target.exists()) {
        await target.delete();
        deleted++;
      }
    }

    return LocalProjectSyncResult(
      writtenFiles: written,
      deletedFiles: deleted,
      skippedPaths: skipped,
    );
  }

  static bool _isTextFile(String fileName) {
    final lower = fileName.toLowerCase();
    if (lower == '.env.example' || lower == '.env.sample') return true;
    if (lower == 'dockerfile' ||
        lower == 'makefile' ||
        lower == 'procfile' ||
        lower == 'license' ||
        lower == 'readme' ||
        lower == 'justfile') {
      return true;
    }
    final dot = lower.lastIndexOf('.');
    final extension = dot >= 0 ? lower.substring(dot + 1) : lower;
    return _textExtensions.contains(extension);
  }

  static bool _isSensitive(String fileName) {
    final lower = fileName.toLowerCase();
    if (lower == '.env' ||
        lower == 'credentials.json' ||
        lower == 'service-account.json' ||
        lower == 'secrets.json' ||
        lower == 'id_rsa' ||
        lower == 'id_ed25519') {
      return true;
    }
    if (lower.startsWith('.env.') &&
        !lower.endsWith('.example') &&
        !lower.endsWith('.sample')) {
      return true;
    }
    return lower.endsWith('.pem') ||
        lower.endsWith('.p12') ||
        lower.endsWith('.pfx') ||
        lower.endsWith('.jks') ||
        lower.endsWith('.keystore') ||
        lower.endsWith('.key');
  }

  static String? _normalizeRelativePath(String input) {
    var path = input.trim().replaceAll('\\', '/');
    while (path.startsWith('./')) {
      path = path.substring(2);
    }
    if (path.isEmpty ||
        path.startsWith('/') ||
        RegExp(r'^[A-Za-z]:').hasMatch(path)) {
      return null;
    }
    final parts = path.split('/');
    if (parts.any((part) => part.isEmpty || part == '.' || part == '..')) {
      return null;
    }
    return parts.join('/');
  }

  static Future<String?> _safeTargetPath(
    String rootPath,
    String relativePath,
  ) async {
    final normalized = _normalizeRelativePath(relativePath);
    if (normalized == null) return null;
    final root = Directory(rootPath).absolute.path;
    final parts = normalized.split('/');
    var current = root;
    // Don't write through a symlink planted inside the selected local folder.
    for (final part in parts) {
      current = '$current${Platform.pathSeparator}$part';
      final type = await FileSystemEntity.type(current, followLinks: false);
      if (type == FileSystemEntityType.link) return null;
    }
    return current;
  }
}
