import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_code_editor/flutter_code_editor.dart';
import 'package:flutter_highlight/themes/github.dart';
import 'package:flutter_highlight/themes/monokai-sublime.dart';
import 'package:highlight/highlight.dart' show Mode;
import 'package:highlight/languages/css.dart' as lang_css;
import 'package:highlight/languages/dart.dart' as lang_dart;
import 'package:highlight/languages/go.dart' as lang_go;
import 'package:highlight/languages/java.dart' as lang_java;
import 'package:highlight/languages/javascript.dart' as lang_js;
import 'package:highlight/languages/json.dart' as lang_json;
import 'package:highlight/languages/kotlin.dart' as lang_kotlin;
import 'package:highlight/languages/php.dart' as lang_php;
import 'package:highlight/languages/python.dart' as lang_python;
import 'package:highlight/languages/rust.dart' as lang_rust;
import 'package:highlight/languages/shell.dart' as lang_shell;
import 'package:highlight/languages/sql.dart' as lang_sql;
import 'package:highlight/languages/swift.dart' as lang_swift;
import 'package:highlight/languages/typescript.dart' as lang_ts;
import 'package:highlight/languages/xml.dart' as lang_xml;
import 'package:highlight/languages/yaml.dart' as lang_yaml;
import 'package:lucide_flutter/lucide_flutter.dart';

import '../../core/api.dart';
import '../../core/models.dart';
import '../../core/theme_controller.dart';

/// Returned to CoderChatScreen when the editor closes.
class CoderEditorResult {
  const CoderEditorResult({
    required this.file,
    this.requestCoderReview = false,
  });

  final FileItem file;
  final bool requestCoderReview;
}

class CoderEditorScreen extends ConsumerStatefulWidget {
  const CoderEditorScreen({
    super.key,
    required this.projectId,
    required this.projectName,
    required this.file,
    this.onFileChanged,
  });

  final String projectId;
  final String projectName;
  final FileItem file;
  final ValueChanged<FileItem>? onFileChanged;

  @override
  ConsumerState<CoderEditorScreen> createState() => _CoderEditorScreenState();
}

class _CoderEditorScreenState extends ConsumerState<CoderEditorScreen> {
  late final CodeController _controller;
  late final UndoHistoryController _undoController;
  late final FocusNode _editorFocusNode;

  late String _savedContent;
  bool _dirty = false;
  bool _saving = false;
  bool _allowPop = false;
  bool _applyingLocalFix = false;
  bool _fixWasApplied = false;
  String? _lastDiffBefore;
  String? _lastDiffAfter;
  Timer? _autoSaveTimer;
  String? _statusMessage;

  String get _extension {
    final name = widget.file.path.toLowerCase();
    final dot = name.lastIndexOf('.');
    return dot < 0 ? '' : name.substring(dot + 1);
  }

  bool get _isPython => _extension == 'py' || _extension == 'pyw';
  int get _lineCount => '\n'.allMatches(_controller.text).length + 1;
  int get _characterCount => _controller.text.length;

  @override
  void initState() {
    super.initState();
    _savedContent = widget.file.content;
    _undoController = UndoHistoryController();
    _undoController.addListener(_refreshUndoState);
    _editorFocusNode = FocusNode();
    _controller = CodeController(
      text: widget.file.content,
      language: _languageForPath(widget.file.path),
    );
    _controller.addListener(_handleCodeChanged);
  }

  @override
  void dispose() {
    _autoSaveTimer?.cancel();
    _controller.removeListener(_handleCodeChanged);
    _controller.dispose();
    _undoController.removeListener(_refreshUndoState);
    _undoController.dispose();
    _editorFocusNode.dispose();
    super.dispose();
  }

  void _refreshUndoState() {
    if (mounted) setState(() {});
  }

  Mode? _languageForPath(String path) {
    final name = path.toLowerCase();
    final ext = name.contains('.') ? name.split('.').last : '';
    return switch (ext) {
      'dart' => lang_dart.dart,
      'py' || 'pyw' => lang_python.python,
      'js' || 'jsx' || 'mjs' || 'cjs' => lang_js.javascript,
      'ts' || 'tsx' => lang_ts.typescript,
      'json' => lang_json.json,
      'yaml' || 'yml' => lang_yaml.yaml,
      'html' || 'htm' => lang_xml.xml,
      'xml' || 'svg' => lang_xml.xml,
      'css' || 'scss' => lang_css.css,
      'sql' => lang_sql.sql,
      'java' => lang_java.java,
      'kt' || 'kts' => lang_kotlin.kotlin,
      'go' => lang_go.go,
      'rs' => lang_rust.rust,
      'sh' || 'bash' => lang_shell.shell,
      'swift' => lang_swift.swift,
      'php' => lang_php.php,
      _ => null,
    };
  }

  String get _languageLabel => switch (_extension) {
    'dart' => 'Dart',
    'py' || 'pyw' => 'Python',
    'js' || 'jsx' || 'mjs' || 'cjs' => 'JavaScript',
    'ts' || 'tsx' => 'TypeScript',
    'json' => 'JSON',
    'yaml' || 'yml' => 'YAML',
    'html' || 'htm' => 'HTML',
    'xml' || 'svg' => 'XML',
    'css' || 'scss' => 'CSS',
    'sql' => 'SQL',
    'java' => 'Java',
    'kt' || 'kts' => 'Kotlin',
    'go' => 'Go',
    'rs' => 'Rust',
    'sh' || 'bash' => 'Shell',
    'swift' => 'Swift',
    'php' => 'PHP',
    _ => 'Texto plano',
  };

  bool _isPythonCodePosition(String source, int targetOffset) {
    String? quote;
    var escaped = false;
    var inComment = false;
    var index = 0;

    while (index < targetOffset && index < source.length) {
      final char = source[index];
      if (inComment) {
        if (char == '\n') inComment = false;
        index++;
        continue;
      }
      if (quote != null) {
        if (escaped) {
          escaped = false;
          index++;
          continue;
        }
        if (char == '\\') {
          escaped = true;
          index++;
          continue;
        }
        if (source.startsWith(quote, index)) {
          index += quote.length;
          quote = null;
          continue;
        }
        index++;
        continue;
      }
      if (char == '#') {
        inComment = true;
        index++;
        continue;
      }
      if (char == '\'' || char == '"') {
        final triple = '$char$char$char';
        quote = source.startsWith(triple, index) ? triple : char;
        index += quote.length;
        continue;
      }
      index++;
    }
    return quote == null && !inComment;
  }

  void _handleCodeChanged() {
    if (_applyingLocalFix) return;

    // A safe, targeted Python typo fix. It triggers only when the user types
    // the opening parenthesis immediately after `pint`, not on every AI call.
    if (_isPython) {
      final text = _controller.text;
      final match = RegExp(r'\bpint(?=\()').firstMatch(text);
      final cursor = _controller.selection.baseOffset;
      if (match != null &&
          _isPythonCodePosition(text, match.start) &&
          match.end < text.length &&
          text[match.end] == '(' &&
          cursor == match.end + 1) {
        final corrected = text.replaceRange(match.start, match.end, 'print');
        _lastDiffBefore = 'pint';
        _lastDiffAfter = 'print';
        _applyingLocalFix = true;
        _controller.value = _controller.value.copyWith(
          text: corrected,
          selection: TextSelection.collapsed(offset: cursor + 1),
          composing: TextRange.empty,
        );
        _applyingLocalFix = false;
        _fixWasApplied = true;
        _statusMessage = 'Corrección instantánea: pint → print';
      }
    }

    if (!mounted) return;
    setState(() {
      _dirty = _controller.text != _savedContent;
    });
    widget.onFileChanged?.call(_fileWithContent(_controller.text));
    _autoSaveTimer?.cancel();
    if (_dirty) {
      _autoSaveTimer = Timer(const Duration(milliseconds: 850), () {
        if (mounted && _dirty) unawaited(_save(silent: true));
      });
    }
  }

  FileItem _fileWithContent(String content) => FileItem(
    id: widget.file.id,
    projectId: widget.file.projectId,
    name: widget.file.name,
    path: widget.file.path,
    isDirectory: widget.file.isDirectory,
    content: content,
    parentId: widget.file.parentId,
  );

  Future<bool> _save({bool silent = false}) async {
    if (_saving) return false;
    final content = _controller.text;
    if (content == _savedContent) {
      if (!silent && mounted) {
        setState(() => _statusMessage = 'Todos los cambios están guardados.');
      }
      return true;
    }

    setState(() {
      _saving = true;
      _statusMessage = 'Guardando en el proyecto…';
    });

    var saveSucceeded = false;
    try {
      final response = await ApiClient.put(
        '/projects/${Uri.encodeComponent(widget.projectId)}/files/${Uri.encodeComponent(widget.file.id)}',
        {'content': content},
      );
      ApiClient.decode(response);
      if (!mounted) return false;
      saveSucceeded = true;
      setState(() {
        _savedContent = content;
        _dirty = _controller.text != content;
        _statusMessage = _dirty
            ? 'Guardado; hay cambios más recientes pendientes'
            : 'Guardado en el proyecto';
      });
      return true;
    } catch (error) {
      if (!mounted) return false;
      setState(
        () => _statusMessage = silent
            ? 'Autoguardado pendiente; se conservaron tus cambios'
            : 'No se pudo guardar. Revisa la conexión e inténtalo de nuevo.',
      );
      if (!silent) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              error is ApiException
                  ? error.message
                  : 'No se pudo guardar el archivo.',
            ),
          ),
        );
      }
      return false;
    } finally {
      if (mounted) {
        setState(() => _saving = false);
        if (saveSucceeded && _dirty) {
          _autoSaveTimer?.cancel();
          _autoSaveTimer = Timer(const Duration(milliseconds: 850), () {
            if (mounted && _dirty) unawaited(_save(silent: true));
          });
        }
      }
    }
  }

  Future<void> _saveAndStay() async {
    await _save();
  }

  Future<void> _askCoderToRepair() async {
    // Persist the exact buffer first so the server-side Coder and the editor
    // always operate on the same version of the file.
    if (_dirty && !await _save()) return;
    if (!mounted) return;
    setState(() => _allowPop = true);
    await WidgetsBinding.instance.endOfFrame;
    if (!mounted) return;
    Navigator.of(context).pop(
      CoderEditorResult(
        file: _fileWithContent(_savedContent),
        requestCoderReview: true,
      ),
    );
  }

  Future<void> _exitEditor() async {
    if (_saving) return;

    if (_dirty) {
      final action = await showDialog<String>(
        context: context,
        builder: (dialogContext) => AlertDialog(
          title: const Text('Cambios sin guardar'),
          content: const Text(
            'Guarda el archivo antes de salir o descarta los cambios de esta sesión.',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dialogContext, 'stay'),
              child: const Text('Seguir editando'),
            ),
            TextButton(
              onPressed: () => Navigator.pop(dialogContext, 'discard'),
              child: const Text('Descartar'),
            ),
            FilledButton(
              onPressed: () => Navigator.pop(dialogContext, 'save'),
              child: const Text('Guardar y salir'),
            ),
          ],
        ),
      );
      if (!mounted || action == null || action == 'stay') return;
      if (action == 'save' && !await _save()) return;
    }

    if (!mounted) return;
    setState(() => _allowPop = true);
    await WidgetsBinding.instance.endOfFrame;
    if (!mounted) return;
    Navigator.of(
      context,
    ).pop(CoderEditorResult(file: _fileWithContent(_savedContent)));
  }

  void _applyAvailableQuickFixes() {
    if (!_isPython) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'Las correcciones rápidas locales están disponibles para Python. Usa “Corregir con Coder” para revisar otros lenguajes.',
          ),
        ),
      );
      return;
    }
    final source = _controller.text;
    final matches = RegExp(r'\bpint(?=\s*\()').allMatches(source).toList();
    var corrected = source;
    for (final match in matches.reversed) {
      if (_isPythonCodePosition(source, match.start)) {
        corrected = corrected.replaceRange(match.start, match.end, 'print');
      }
    }
    if (corrected == _controller.text) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'No se encontraron errores conocidos para corregir automáticamente.',
          ),
        ),
      );
      return;
    }
    _controller.value = _controller.value.copyWith(
      text: corrected,
      selection: TextSelection.collapsed(offset: corrected.length),
      composing: TextRange.empty,
    );
    _fixWasApplied = true;
    _lastDiffBefore = 'pint';
    _lastDiffAfter = 'print';
    setState(() {
      _dirty = _controller.text != _savedContent;
      _statusMessage = 'Corrección rápida aplicada: pint → print';
    });
    widget.onFileChanged?.call(_fileWithContent(_controller.text));
    _autoSaveTimer?.cancel();
    if (_dirty) {
      _autoSaveTimer = Timer(const Duration(milliseconds: 850), () {
        if (mounted && _dirty) unawaited(_save(silent: true));
      });
    }
  }

  void _copyCurrentFile() {
    Clipboard.setData(ClipboardData(text: _controller.text));
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(const SnackBar(content: Text('Código copiado')));
  }

  @override
  Widget build(BuildContext context) {
    final palette = ref.watch(appPaletteProvider);
    final syntaxTheme = palette.isDark ? monokaiSublimeTheme : githubTheme;

    return PopScope<CoderEditorResult>(
      canPop: _allowPop,
      onPopInvokedWithResult: (didPop, result) {
        if (!didPop) {
          _exitEditor();
        }
      },
      child: Scaffold(
        backgroundColor: palette.background,
        appBar: AppBar(
          backgroundColor: palette.background,
          leading: IconButton(
            tooltip: 'Volver a Coder',
            onPressed: _exitEditor,
            icon: const Icon(LucideIcons.arrowLeft),
          ),
          titleSpacing: 0,
          title: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                widget.file.name,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.w700,
                ),
              ),
              Text(
                widget.file.path,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(fontSize: 10, color: palette.textSecondary),
              ),
            ],
          ),
          actions: [
            IconButton(
              tooltip: 'Buscar en el archivo',
              onPressed: _controller.showSearch,
              icon: const Icon(LucideIcons.search),
            ),
            IconButton(
              tooltip: 'Deshacer',
              onPressed: _undoController.value.canUndo
                  ? _undoController.undo
                  : null,
              icon: const Icon(LucideIcons.undo2),
            ),
            IconButton(
              tooltip: 'Rehacer',
              onPressed: _undoController.value.canRedo
                  ? _undoController.redo
                  : null,
              icon: const Icon(LucideIcons.redo2),
            ),
            IconButton(
              tooltip: 'Copiar archivo',
              onPressed: _copyCurrentFile,
              icon: const Icon(LucideIcons.copy),
            ),
            Padding(
              padding: const EdgeInsets.only(right: 8),
              child: IconButton.filled(
                tooltip: _saving ? 'Guardando…' : 'Guardar archivo',
                onPressed: _saving ? null : _saveAndStay,
                icon: _saving
                    ? const SizedBox(
                        width: 18,
                        height: 18,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Icon(LucideIcons.save),
              ),
            ),
          ],
        ),
        body: SafeArea(
          child: Column(
            children: [
              Container(
                height: 42,
                padding: const EdgeInsets.symmetric(horizontal: 12),
                decoration: BoxDecoration(
                  color: palette.surface,
                  border: Border(bottom: BorderSide(color: palette.border)),
                ),
                child: Row(
                  children: [
                    Icon(LucideIcons.code2, size: 16, color: palette.accent),
                    const SizedBox(width: 8),
                    Text(
                      _languageLabel,
                      style: TextStyle(
                        color: palette.textSecondary,
                        fontSize: 12,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Container(width: 1, height: 18, color: palette.border),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        _dirty ? 'Cambios sin guardar' : 'Versión guardada',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          fontSize: 12,
                          color: _dirty
                              ? const Color(0xFFFFC857)
                              : palette.textSecondary,
                          fontWeight: _dirty
                              ? FontWeight.w700
                              : FontWeight.w400,
                        ),
                      ),
                    ),
                    PopupMenuButton<String>(
                      tooltip: 'Herramientas del editor',
                      icon: const Icon(LucideIcons.ellipsis, size: 20),
                      onSelected: (action) {
                        switch (action) {
                          case 'comment':
                            _controller.commentOutOrUncommentSelection();
                            break;
                          case 'indent':
                            _controller.indentSelection();
                            break;
                          case 'outdent':
                            _controller.outdentSelection();
                            break;
                          case 'fold_imports':
                            _controller.foldImports();
                            break;
                          case 'fix':
                            _applyAvailableQuickFixes();
                            break;
                        }
                      },
                      itemBuilder: (_) => const [
                        PopupMenuItem(
                          value: 'comment',
                          child: Text('Comentar / descomentar selección'),
                        ),
                        PopupMenuItem(
                          value: 'indent',
                          child: Text('Indentar selección'),
                        ),
                        PopupMenuItem(
                          value: 'outdent',
                          child: Text('Quitar indentación'),
                        ),
                        PopupMenuItem(
                          value: 'fold_imports',
                          child: Text('Plegar imports'),
                        ),
                        PopupMenuItem(
                          value: 'fix',
                          child: Text('Aplicar correcciones rápidas'),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              if (_statusMessage != null)
                Material(
                  color: palette.accent.withValues(alpha: .10),
                  child: Padding(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 14,
                      vertical: 8,
                    ),
                    child: Row(
                      children: [
                        Icon(
                          _fixWasApplied
                              ? LucideIcons.wandSparkles
                              : LucideIcons.info,
                          size: 15,
                          color: palette.accent,
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            _statusMessage!,
                            style: TextStyle(
                              fontSize: 12,
                              color: palette.textPrimary,
                            ),
                          ),
                        ),
                        IconButton(
                          visualDensity: VisualDensity.compact,
                          tooltip: 'Cerrar aviso',
                          onPressed: () => setState(() {
                            _statusMessage = null;
                            _fixWasApplied = false;
                          }),
                          icon: const Icon(LucideIcons.x, size: 16),
                        ),
                      ],
                    ),
                  ),
                ),
              if (_fixWasApplied &&
                  _lastDiffBefore != null &&
                  _lastDiffAfter != null)
                Padding(
                  padding: const EdgeInsets.fromLTRB(12, 8, 12, 2),
                  child: Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: palette.surface,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: palette.border),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        Row(
                          children: [
                            Icon(
                              LucideIcons.code2,
                              size: 15,
                              color: palette.accent,
                            ),
                            const SizedBox(width: 7),
                            Expanded(
                              child: Text(
                                'Corrección aplicada en vivo',
                                style: TextStyle(
                                  color: palette.textPrimary,
                                  fontSize: 12,
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                            ),
                            IconButton(
                              visualDensity: VisualDensity.compact,
                              tooltip: 'Cerrar diff',
                              onPressed: () => setState(() {
                                _fixWasApplied = false;
                                _lastDiffBefore = null;
                                _lastDiffAfter = null;
                              }),
                              icon: const Icon(LucideIcons.x, size: 15),
                            ),
                          ],
                        ),
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 9,
                            vertical: 5,
                          ),
                          decoration: BoxDecoration(
                            color: const Color(0x1AEF4444),
                            borderRadius: BorderRadius.circular(7),
                          ),
                          child: Row(
                            children: [
                              const Text(
                                '−',
                                style: TextStyle(
                                  color: Color(0xFFEF4444),
                                  fontWeight: FontWeight.w800,
                                ),
                              ),
                              const SizedBox(width: 8),
                              Expanded(
                                child: Text(
                                  _lastDiffBefore!,
                                  style: const TextStyle(
                                    fontFamily: 'monospace',
                                    color: Color(0xFFEF4444),
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(height: 4),
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 9,
                            vertical: 5,
                          ),
                          decoration: BoxDecoration(
                            color: const Color(0x1A22C55E),
                            borderRadius: BorderRadius.circular(7),
                          ),
                          child: Row(
                            children: [
                              const Text(
                                '+',
                                style: TextStyle(
                                  color: Color(0xFF22C55E),
                                  fontWeight: FontWeight.w800,
                                ),
                              ),
                              const SizedBox(width: 8),
                              Expanded(
                                child: Text(
                                  _lastDiffAfter!,
                                  style: const TextStyle(
                                    fontFamily: 'monospace',
                                    color: Color(0xFF22C55E),
                                  ),
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
                child: Container(
                  color: palette.surface,
                  child: CodeTheme(
                    data: CodeThemeData(styles: syntaxTheme),
                    child: CodeField(
                      controller: _controller,
                      undoController: _undoController,
                      focusNode: _editorFocusNode,
                      expands: true,
                      wrap: false,
                      background: palette.surface,
                      cursorColor: palette.accent,
                      padding: const EdgeInsets.fromLTRB(10, 14, 20, 40),
                      textStyle: TextStyle(
                        fontFamily: 'monospace',
                        fontSize: 14,
                        height: 1.55,
                        color: palette.textPrimary,
                      ),
                      gutterStyle: GutterStyle(
                        showLineNumbers: true,
                        showErrors: true,
                        showFoldingHandles: true,
                      ),
                      decoration: BoxDecoration(
                        color: palette.surface,
                        border: Border.all(color: palette.border),
                      ),
                    ),
                  ),
                ),
              ),
              Container(
                padding: const EdgeInsets.fromLTRB(12, 7, 12, 8),
                decoration: BoxDecoration(
                  color: palette.surfaceAlt,
                  border: Border(top: BorderSide(color: palette.border)),
                ),
                child: Row(
                  children: [
                    Icon(
                      LucideIcons.listTree,
                      size: 14,
                      color: palette.textSecondary,
                    ),
                    const SizedBox(width: 5),
                    Text(
                      '$_lineCount líneas',
                      style: TextStyle(
                        fontSize: 11,
                        color: palette.textSecondary,
                      ),
                    ),
                    const SizedBox(width: 10),
                    Text(
                      '$_characterCount caracteres',
                      style: TextStyle(
                        fontSize: 11,
                        color: palette.textSecondary,
                      ),
                    ),
                    const Spacer(),
                    Text(
                      'Ctrl/Cmd+Z · Deshacer',
                      style: TextStyle(
                        fontSize: 10,
                        color: palette.textSecondary,
                      ),
                    ),
                  ],
                ),
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(12, 9, 12, 12),
                child: SizedBox(
                  width: double.infinity,
                  child: FilledButton.icon(
                    onPressed: _saving ? null : _askCoderToRepair,
                    icon: const Icon(LucideIcons.wandSparkles, size: 18),
                    label: const Text('Guardar y corregir con Coder'),
                    style: FilledButton.styleFrom(
                      backgroundColor: palette.accent,
                      foregroundColor: palette.isDark
                          ? Colors.black
                          : Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 13),
                    ),
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
