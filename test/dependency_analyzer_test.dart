import 'package:flutter_test/flutter_test.dart';
import 'package:numination/core/dependency_analyzer.dart';
import 'package:numination/core/models.dart';

void main() {
  group('analyzeDependencies', () {
    test('detects a relative import and a probable function call', () {
      final files = <FileItem>[
        const FileItem(
          id: 'source',
          projectId: 'project',
          name: 'source.dart',
          path: 'lib/source.dart',
          isDirectory: false,
          content:
              "import 'target.dart';\nvoid openTarget() { renderTarget(); }",
        ),
        const FileItem(
          id: 'target',
          projectId: 'project',
          name: 'target.dart',
          path: 'lib/target.dart',
          isDirectory: false,
          // Method on its own line so _functionNames (line-anchored regex) picks it up.
          content: 'class Target {\n  void renderTarget() {}\n}',
        ),
      ];

      final edges = analyzeDependencies(files);
      expect(edges, hasLength(1));
      expect(edges.single.sourcePath, 'lib/source.dart');
      expect(edges.single.targetPath, 'lib/target.dart');
      expect(edges.single.reason, contains('renderTarget'));
    });

    test('ignores directories and unresolved external imports', () {
      final files = <FileItem>[
        const FileItem(
          id: 'folder',
          projectId: 'project',
          name: 'lib',
          path: 'lib',
          isDirectory: true,
          content: '',
        ),
        const FileItem(
          id: 'source',
          projectId: 'project',
          name: 'source.py',
          path: 'src/source.py',
          isDirectory: false,
          content: 'import requests\nfrom external_sdk import Client',
        ),
      ];

      expect(analyzeDependencies(files), isEmpty);
    });
  });
}
