
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:flutter_smooth_markdown/flutter_smooth_markdown.dart';
import 'package:lucide_flutter/lucide_flutter.dart';
import 'package:simple_icons/simple_icons.dart';

import '../../core/theme.dart';

class AiResponse extends StatelessWidget {
  const AiResponse({
    super.key,
    required this.text,
    required this.palette,
    this.animateCharacters = false,
  });

  final String text;
  final AppPalette palette;
  final bool animateCharacters;

  @override
  Widget build(BuildContext context) {
    return _ResponseContent(
      text: text,
      palette: palette,
      animateCharacters: animateCharacters,
    );
  }
}

class _ResponseContent extends StatelessWidget {
  const _ResponseContent({
    required this.text,
    required this.palette,
    required this.animateCharacters,
  });

  final String text;
  final AppPalette palette;
  final bool animateCharacters;

  @override
  Widget build(BuildContext context) {
    final parts = _parseResponse(text);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        for (var i = 0; i < parts.length; i++)
          Padding(
            padding: EdgeInsets.only(
              bottom: i == parts.length - 1 ? 0 : 12,
            ),
            child: switch (parts[i]) {
              _CodePart(:final language, :final code) => _CodeBlock(
                  language: language,
                  code: code,
                  palette: palette,
                ),
              _TextPart(:final content) => _MarkdownContent(
                  text: content,
                  palette: palette,
                  animateCharacters: animateCharacters,
                ),
            },
          ),
      ],
    );
  }

  List<_ResponsePart> _parseResponse(String source) {
    final parts = <_ResponsePart>[];
    final lines = source.replaceAll('\r\n', '\n').split('\n');
    final textBuffer = StringBuffer();

    String? codeLanguage;
    StringBuffer? codeBuffer;

    void flushText() {
      final value = textBuffer.toString();
      if (value.isNotEmpty) {
        parts.add(_TextPart(value));
        textBuffer.clear();
      }
    }

    for (final line in lines) {
      final fence = RegExp(r'^\s*(```+|~~~+)\s*(.*?)\s*$')
          .firstMatch(line);

      if (fence != null) {
        final marker = fence.group(1)!;
        final language = fence.group(2)?.trim() ?? '';

        if (codeBuffer == null) {
          flushText();
          codeLanguage = language;
          codeBuffer = StringBuffer();
        } else if (marker[0] == (codeLanguage == null ? '`' : marker[0])) {
          parts.add(
            _CodePart(
              language: codeLanguage ?? '',
              code: _removeTrailingNewline(codeBuffer.toString()),
            ),
          );
          codeBuffer = null;
          codeLanguage = null;
        } else {
          codeBuffer.writeln(line);
        }
        continue;
      }

      if (codeBuffer != null) {
        codeBuffer.writeln(line);
      } else {
        textBuffer.writeln(line);
      }
    }

    if (codeBuffer != null) {
      parts.add(
        _CodePart(
          language: codeLanguage ?? '',
          code: _removeTrailingNewline(codeBuffer.toString()),
        ),
      );
    }

    flushText();
    return parts;
  }

  String _removeTrailingNewline(String value) {
    if (value.endsWith('\n')) {
      return value.substring(0, value.length - 1);
    }
    return value;
  }
}

sealed class _ResponsePart {
  const _ResponsePart();
}

class _TextPart extends _ResponsePart {
  const _TextPart(this.content);

  final String content;
}

class _CodePart extends _ResponsePart {
  const _CodePart({
    required this.language,
    required this.code,
  });

  final String language;
  final String code;
}

class _MarkdownContent extends StatelessWidget {
  const _MarkdownContent({
    required this.text,
    required this.palette,
    required this.animateCharacters,
  });

  final String text;
  final AppPalette palette;
  final bool animateCharacters;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final content = text;

    // SmoothMarkdown renders complete Markdown blocks and preserves
    // tables, lists, links and multiline mathematical expressions.
    return SmoothMarkdown(
      data: content,
      styleSheet: MarkdownStyleSheet.fromTheme(theme),
      selectable: true,
      onTapLink: (url) async {
        final uri = Uri.tryParse(url);
        if (uri == null ||
            (uri.scheme != 'https' && uri.scheme != 'http')) {
          return;
        }

        await launchUrl(
          uri,
          mode: LaunchMode.externalApplication,
        );
      },
    );
  }
}

class _CodeBlock extends StatelessWidget {
  const _CodeBlock({
    required this.language,
    required this.code,
    required this.palette,
  });

  final String language;
  final String code;
  final AppPalette palette;

  IconData _languageIcon() {
    switch (language.toLowerCase().trim()) {
      case 'dart':
        return SimpleIcons.dart;
      case 'python':
      case 'py':
        return SimpleIcons.python;
      case 'javascript':
      case 'js':
        return SimpleIcons.javascript;
      case 'typescript':
      case 'ts':
        return SimpleIcons.typescript;
      case 'java':
        return SimpleIcons.java;
      case 'kotlin':
      case 'kt':
        return SimpleIcons.kotlin;
      case 'swift':
        return SimpleIcons.swift;
      case 'go':
      case 'golang':
        return SimpleIcons.go;
      case 'rust':
      case 'rs':
        return SimpleIcons.rust;
      case 'html':
        return SimpleIcons.html5;
      case 'css':
        return SimpleIcons.css3;
      case 'json':
        return SimpleIcons.json;
      case 'bash':
      case 'sh':
      case 'shell':
      case 'terminal':
        return LucideIcons.terminal;
      case 'yaml':
      case 'yml':
        return SimpleIcons.yaml;
      case 'markdown':
      case 'md':
        return SimpleIcons.markdown;
      case 'php':
        return SimpleIcons.php;
      case 'ruby':
      case 'rb':
        return SimpleIcons.ruby;
      case 'c':
        return SimpleIcons.c;
      case 'cpp':
      case 'c++':
        return SimpleIcons.cplusplus;
      case 'csharp':
      case 'c#':
        return SimpleIcons.csharp;
      case 'sql':
        return SimpleIcons.postgresql;
      default:
        return LucideIcons.code2;
    }
  }

  String _displayLanguage() {
    final value = language.trim();
    if (value.isEmpty) return 'Código';
    return value;
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: palette.surface,
        border: Border.all(color: palette.border),
        borderRadius: BorderRadius.circular(12),
      ),
      clipBehavior: Clip.antiAlias,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Container(
            padding: const EdgeInsets.symmetric(
              horizontal: 12,
              vertical: 10,
            ),
            decoration: BoxDecoration(
              color: palette.surfaceAlt,
              border: Border(
                bottom: BorderSide(color: palette.border),
              ),
            ),
            child: Row(
              children: [
                Icon(
                  _languageIcon(),
                  size: 16,
                  color: palette.textSecondary,
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    _displayLanguage(),
                    style: TextStyle(
                      color: palette.textSecondary,
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
                InkWell(
                  onTap: () async {
                    await Clipboard.setData(
                      ClipboardData(text: code),
                    );

                    if (!context.mounted) return;

                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                        content: Text('Código copiado'),
                        duration: Duration(seconds: 2),
                      ),
                    );
                  },
                  borderRadius: BorderRadius.circular(6),
                  child: Padding(
                    padding: const EdgeInsets.all(5),
                    child: Icon(
                      LucideIcons.copy,
                      size: 15,
                      color: palette.textSecondary,
                    ),
                  ),
                ),
              ],
            ),
          ),
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.all(14),
            child: SelectableText(
              code,
              style: TextStyle(
                color: palette.textPrimary,
                fontSize: 13,
                height: 1.55,
                fontFamily: 'monospace',
              ),
            ),
          ),
        ],
      ),
    );
  }
}
