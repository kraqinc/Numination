import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_math_fork/flutter_math.dart';

import '../../core/theme.dart';
import '../../core/theme_controller.dart';

class AiResponse extends ConsumerWidget {
  const AiResponse({
    super.key,
    required this.text,
  });

  final String text;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final palette = ref.watch(appPaletteProvider);
    final parts = _parseResponse(text);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        for (var i = 0; i < parts.length; i++) ...[
          _ResponsePartView(
            part: parts[i],
            palette: palette,
            onCopy: (code) => _copyCode(context, code),
          ),
          if (i != parts.length - 1)
            const SizedBox(height: 8),
        ],
      ],
    );
  }

  Future<void> _copyCode(
    BuildContext context,
    String code,
  ) async {
    await Clipboard.setData(
      ClipboardData(text: code),
    );

    if (!context.mounted) return;

    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Código copiado'),
        duration: Duration(milliseconds: 1200),
      ),
    );
  }

  List<_ResponsePart> _parseResponse(String source) {
    final result = <_ResponsePart>[];

    final codeRegex = RegExp(
      r'```([^\n`]*)\n?([\s\S]*?)```',
      multiLine: true,
    );

    var cursor = 0;

    for (final match in codeRegex.allMatches(source)) {
      if (match.start > cursor) {
        _parseText(
          source.substring(cursor, match.start),
          result,
        );
      }

      final language = match.group(1)?.trim();
      final code = match.group(2) ?? '';

      result.add(
        _ResponsePart.code(
          code.trimRight(),
          language == null || language.isEmpty
              ? 'code'
              : language,
        ),
      );

      cursor = match.end;
    }

    if (cursor < source.length) {
      _parseText(
        source.substring(cursor),
        result,
      );
    }

    if (result.isEmpty && source.trim().isNotEmpty) {
      _parseText(source, result);
    }

    return result;
  }

  void _parseText(
    String source,
    List<_ResponsePart> result,
  ) {
    final normalized = source.replaceAll('\r\n', '\n');
    final lines = normalized.split('\n');

    final buffer = <String>[];

    void flushText() {
      if (buffer.isEmpty) return;

      final text = buffer.join('\n');

      if (text.trim().isNotEmpty) {
        result.add(
          _ResponsePart.text(text),
        );
      }

      buffer.clear();
    }

    for (final rawLine in lines) {
      final line = rawLine.trim();

      if (_isMathBlock(line)) {
        flushText();

        result.add(
          _ResponsePart.math(
            _normalizeMath(line),
          ),
        );
      } else {
        buffer.add(rawLine);
      }
    }

    flushText();
  }

  bool _isMathBlock(String line) {
    if (line.isEmpty) return false;

    if (line.startsWith(r'$$') &&
        line.endsWith(r'$$')) {
      return true;
    }

    if (line.startsWith(r'\[') &&
        line.endsWith(r'\]')) {
      return true;
    }

    if (line.startsWith(r'\(') &&
        line.endsWith(r'\)')) {
      return true;
    }

    if (line.startsWith(r'\frac')) {
      return true;
    }

    if (line.startsWith(r'\sqrt')) {
      return true;
    }

    return false;
  }

  String _normalizeMath(String value) {
    var result = value.trim();

    if (result.startsWith(r'$$') &&
        result.endsWith(r'$$')) {
      result = result.substring(
        2,
        result.length - 2,
      ).trim();
    }

    if (result.startsWith(r'\[') &&
        result.endsWith(r'\]')) {
      result = result.substring(
        2,
        result.length - 2,
      ).trim();
    }

    if (result.startsWith(r'\(') &&
        result.endsWith(r'\)')) {
      result = result.substring(
        2,
        result.length - 2,
      ).trim();
    }

    return result;
  }
}

enum _ResponsePartType {
  text,
  math,
  code,
}

class _ResponsePart {
  const _ResponsePart.text(this.content)
      : type = _ResponsePartType.text,
        language = null;

  const _ResponsePart.math(this.content)
      : type = _ResponsePartType.math,
        language = null;

  const _ResponsePart.code(
    this.content,
    this.language,
  ) : type = _ResponsePartType.code;

  final _ResponsePartType type;
  final String content;
  final String? language;
}

class _ResponsePartView extends StatelessWidget {
  const _ResponsePartView({
    required this.part,
    required this.palette,
    required this.onCopy,
  });

  final _ResponsePart part;
  final AppPalette palette;
  final ValueChanged<String> onCopy;

  @override
  Widget build(BuildContext context) {
    switch (part.type) {
      case _ResponsePartType.text:
        return _TextResponse(
          text: part.content,
          palette: palette,
        );

      case _ResponsePartType.math:
        return _MathResponse(
          expression: part.content,
          palette: palette,
        );

      case _ResponsePartType.code:
        return _CodeResponse(
          code: part.content,
          language: part.language ?? 'code',
          palette: palette,
          onCopy: onCopy,
        );
    }
  }
}

class _TextResponse extends StatelessWidget {
  const _TextResponse({
    required this.text,
    required this.palette,
  });

  final String text;
  final AppPalette palette;

  @override
  Widget build(BuildContext context) {
    final lines = text.split('\n');

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        for (final line in lines)
          if (line.trim().isNotEmpty)
            Padding(
              padding: const EdgeInsets.symmetric(
                vertical: 2,
              ),
              child: _FormattedLine(
                line: line,
                palette: palette,
              ),
            ),
      ],
    );
  }
}

class _FormattedLine extends StatelessWidget {
  const _FormattedLine({
    required this.line,
    required this.palette,
  });

  final String line;
  final AppPalette palette;

  @override
  Widget build(BuildContext context) {
    final trimmed = line.trim();

    if (trimmed.startsWith('### ')) {
      return Text(
        trimmed.substring(4),
        style: TextStyle(
          color: palette.textPrimary,
          fontSize: 16,
          fontWeight: FontWeight.w800,
        ),
      );
    }

    if (trimmed.startsWith('## ')) {
      return Text(
        trimmed.substring(3),
        style: TextStyle(
          color: palette.textPrimary,
          fontSize: 18,
          fontWeight: FontWeight.w800,
        ),
      );
    }

    if (trimmed.startsWith('# ')) {
      return Text(
        trimmed.substring(2),
        style: TextStyle(
          color: palette.textPrimary,
          fontSize: 20,
          fontWeight: FontWeight.w800,
        ),
      );
    }

    return Text.rich(
      TextSpan(
        children: _spans(line),
      ),
      style: TextStyle(
        color: palette.textPrimary,
        fontSize: 15,
        height: 1.45,
      ),
    );
  }

  List<InlineSpan> _spans(String value) {
    final result = <InlineSpan>[];

    final regex = RegExp(
      r'(\*\*[^*]+\*\*|`[^`]+`)',
    );

    var cursor = 0;

    for (final match in regex.allMatches(value)) {
      if (match.start > cursor) {
        result.add(
          TextSpan(
            text: value.substring(
              cursor,
              match.start,
            ),
          ),
        );
      }

      final token = match.group(0)!;

      if (token.startsWith('**')) {
        result.add(
          TextSpan(
            text: token.substring(
              2,
              token.length - 2,
            ),
            style: const TextStyle(
              fontWeight: FontWeight.w700,
            ),
          ),
        );
      } else {
        result.add(
          WidgetSpan(
            alignment: PlaceholderAlignment.middle,
            child: Container(
              margin: const EdgeInsets.symmetric(
                horizontal: 2,
              ),
              padding: const EdgeInsets.symmetric(
                horizontal: 5,
                vertical: 2,
              ),
              decoration: BoxDecoration(
                color: palette.surfaceAlt,
                borderRadius: BorderRadius.circular(5),
              ),
              child: Text(
                token.substring(
                  1,
                  token.length - 1,
                ),
                style: TextStyle(
                  color: palette.textPrimary,
                  fontFamily: 'monospace',
                  fontSize: 13,
                ),
              ),
            ),
          ),
        );
      }

      cursor = match.end;
    }

    if (cursor < value.length) {
      result.add(
        TextSpan(
          text: value.substring(cursor),
        ),
      );
    }

    return result;
  }
}

class _MathResponse extends StatelessWidget {
  const _MathResponse({
    required this.expression,
    required this.palette,
  });

  final String expression;
  final AppPalette palette;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(
        horizontal: 14,
        vertical: 16,
      ),
      decoration: BoxDecoration(
        color: palette.surfaceAlt,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: palette.border,
        ),
      ),
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: Math.tex(
          expression,
          mathStyle: MathStyle.display,
          textStyle: TextStyle(
            color: palette.textPrimary,
            fontSize: 18,
          ),
          onErrorFallback: (error) {
            return Text(
              expression,
              style: TextStyle(
                color: palette.textPrimary,
                fontSize: 14,
                fontFamily: 'monospace',
              ),
            );
          },
        ),
      ),
    );
  }
}

class _CodeResponse extends StatelessWidget {
  const _CodeResponse({
    required this.code,
    required this.language,
    required this.palette,
    required this.onCopy,
  });

  final String code;
  final String language;
  final AppPalette palette;
  final ValueChanged<String> onCopy;

  IconData _iconForLanguage() {
    final value = language.toLowerCase();

    if (value.contains('dart')) {
      return Icons.code;
    }

    if (value.contains('python') ||
        value == 'py') {
      return Icons.memory_outlined;
    }

    if (value.contains('javascript') ||
        value == 'js' ||
        value.contains('typescript') ||
        value == 'ts') {
      return Icons.javascript;
    }

    if (value.contains('json')) {
      return Icons.data_object;
    }

    if (value.contains('html') ||
        value.contains('css')) {
      return Icons.web;
    }

    if (value.contains('sql')) {
      return Icons.storage_outlined;
    }

    if (value.contains('bash') ||
        value.contains('shell') ||
        value == 'sh' ||
        value == 'zsh') {
      return Icons.terminal;
    }

    if (value.contains('yaml') ||
        value.contains('yml')) {
      return Icons.settings_outlined;
    }

    if (value.contains('java')) {
      return Icons.coffee;
    }

    if (value.contains('kotlin')) {
      return Icons.android;
    }

    if (value.contains('cpp') ||
        value.contains('c++')) {
      return Icons.memory;
    }

    return Icons.code_rounded;
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      decoration: BoxDecoration(
        color: palette.surfaceAlt,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: palette.border,
        ),
      ),
      clipBehavior: Clip.antiAlias,
      child: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(
              12,
              9,
              8,
              9,
            ),
            child: Row(
              children: [
                Icon(
                  _iconForLanguage(),
                  color: palette.textSecondary,
                  size: 18,
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    language.toUpperCase(),
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      color: palette.textSecondary,
                      fontSize: 11,
                      fontWeight: FontWeight.w700,
                      letterSpacing: 0.7,
                    ),
                  ),
                ),
                IconButton(
                  onPressed: () => onCopy(code),
                  tooltip: 'Copiar',
                  visualDensity: VisualDensity.compact,
                  icon: Image.asset(
                    'assets/images/copy_icon.png',
                    width: 19,
                    height: 19,
                  ),
                ),
              ],
            ),
          ),
          Divider(
            height: 1,
            color: palette.border,
          ),
          Align(
            alignment: Alignment.centerLeft,
            child: SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.all(14),
              child: SelectableText(
                code,
                style: TextStyle(
                  color: palette.textPrimary,
                  fontFamily: 'monospace',
                  fontSize: 13,
                  height: 1.5,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}