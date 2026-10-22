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
            padding: EdgeInsets.only(bottom: i == parts.length - 1 ? 0 : 12),
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
      final fence = RegExp(r'^\s*(```+|~~~+)\s*(.*?)\s*$').firstMatch(line);

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
  const _CodePart({required this.language, required this.code});

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

  Future<void> _openLink(String url) async {
    final uri = Uri.tryParse(url);

    if (uri == null ||
        uri.scheme != 'https' ||
        uri.host.isEmpty ||
        uri.userInfo.isNotEmpty) {
      return;
    }

    await launchUrl(uri, mode: LaunchMode.externalApplication);
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final bodyStyle =
        (theme.textTheme.bodyMedium ?? const TextStyle(fontSize: 14)).copyWith(
          color: palette.textPrimary,
          height: 1.5,
        );

    final sheet = MarkdownStyleSheet.fromTheme(theme).copyWith(
      textStyle: bodyStyle,
      paragraphStyle: bodyStyle,
      tableHeaderStyle: bodyStyle.copyWith(
        fontSize: 13.5,
        fontWeight: FontWeight.w700,
        height: 1.45,
      ),
      tableCellStyle: bodyStyle.copyWith(fontSize: 13, height: 1.55),
      tableHeaderDecoration: BoxDecoration(
        color: palette.accent.withValues(alpha: 0.14),
      ),
      tableOddRowDecoration: BoxDecoration(
        color: palette.surfaceAlt.withValues(alpha: 0.5),
      ),
      tableEvenRowDecoration: BoxDecoration(color: palette.surface),
      tableBorder: TableBorder.all(
        color: palette.border.withValues(alpha: 0.85),
        width: 0.8,
      ),
      tableCellPadding: const EdgeInsets.symmetric(
        horizontal: 14,
        vertical: 12,
      ),
      blockSpacing: 14,
    );

    final pieces = _splitTables(text);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        for (var i = 0; i < pieces.length; i++)
          if (pieces[i].rows != null)
            Padding(
              padding: EdgeInsets.only(bottom: i == pieces.length - 1 ? 0 : 12),
              child: _HorizontalMarkdownTable(
                rows: pieces[i].rows!,
                palette: palette,
                styleSheet: sheet,
                onTapLink: _openLink,
              ),
            )
          else if ((pieces[i].markdown ?? '').trim().isNotEmpty)
            Padding(
              padding: EdgeInsets.only(bottom: i == pieces.length - 1 ? 0 : 12),
              child: SmoothMarkdown(
                data: pieces[i].markdown!,
                styleSheet: sheet,
                selectable: true,
                onTapLink: _openLink,
              ),
            ),
      ],
    );
  }

  List<_MarkdownPiece> _splitTables(String source) {
    final lines = source.replaceAll('\r\n', '\n').split('\n');
    final result = <_MarkdownPiece>[];
    final textLines = <String>[];
    var i = 0;
    var foundTable = false;

    void flushText() {
      final value = textLines.join('\n');
      if (value.trim().isNotEmpty) {
        result.add(_MarkdownPiece.markdown(value));
      }
      textLines.clear();
    }

    while (i < lines.length) {
      final isTable =
          i + 1 < lines.length &&
          lines[i].contains('|') &&
          _isDelimiter(lines[i + 1]);

      if (!isTable) {
        textLines.add(lines[i]);
        i++;
        continue;
      }

      foundTable = true;
      flushText();

      final rows = <List<String>>[_parseRow(lines[i])];
      i += 2; // Cabecera y separador Markdown.

      while (i < lines.length &&
          lines[i].trim().isNotEmpty &&
          lines[i].contains('|')) {
        rows.add(_parseRow(lines[i]));
        i++;
      }

      if (rows.first.isNotEmpty) {
        result.add(_MarkdownPiece.table(rows));
      }
    }

    flushText();

    // No alterar el Markdown original cuando no contiene tablas.
    return foundTable ? result : [_MarkdownPiece.markdown(source)];
  }

  bool _isDelimiter(String line) {
    final cells = _parseRow(line);
    if (cells.isEmpty) return false;

    final pattern = RegExp(r'^:?-{3,}:?$');
    return cells.every((cell) => pattern.hasMatch(cell.replaceAll(' ', '')));
  }

  List<String> _parseRow(String line) {
    var value = line.trim();

    if (value.startsWith('|')) {
      value = value.substring(1);
    }

    if (value.endsWith('|') &&
        (value.length < 2 || value[value.length - 2] != '\\')) {
      value = value.substring(0, value.length - 1);
    }

    final cells = <String>[];
    final cell = StringBuffer();

    for (var i = 0; i < value.length; i++) {
      final character = value[i];

      if (character == '\\' && i + 1 < value.length && value[i + 1] == '|') {
        cell.write('|');
        i++;
      } else if (character == '|') {
        cells.add(cell.toString().trim());
        cell.clear();
      } else {
        cell.write(character);
      }
    }

    cells.add(cell.toString().trim());
    return cells;
  }
}

class _MarkdownPiece {
  const _MarkdownPiece.markdown(this.markdown) : rows = null;

  const _MarkdownPiece.table(this.rows) : markdown = null;

  final String? markdown;
  final List<List<String>>? rows;
}

class _HorizontalMarkdownTable extends StatefulWidget {
  const _HorizontalMarkdownTable({
    required this.rows,
    required this.palette,
    required this.styleSheet,
    required this.onTapLink,
  });

  final List<List<String>> rows;
  final AppPalette palette;
  final MarkdownStyleSheet styleSheet;
  final Future<void> Function(String url) onTapLink;

  @override
  State<_HorizontalMarkdownTable> createState() =>
      _HorizontalMarkdownTableState();
}

class _HorizontalMarkdownTableState extends State<_HorizontalMarkdownTable> {
  final ScrollController _controller = ScrollController();

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    var columnCount = 1;
    for (final row in widget.rows) {
      if (row.length > columnCount) columnCount = row.length;
    }

    final availableWidth = (MediaQuery.sizeOf(context).width * 0.88)
        .clamp(280.0, 980.0)
        .toDouble();

    // Ancho mínimo real para impedir que las columnas queden aplastadas.
    final cellWidth = columnCount == 1
        ? availableWidth
        : (availableWidth / columnCount)
              .clamp(200.0, availableWidth)
              .toDouble();

    final tableWidth = cellWidth * columnCount;
    final padding =
        widget.styleSheet.tableCellPadding ??
        const EdgeInsets.symmetric(horizontal: 14, vertical: 12);

    final widths = <int, TableColumnWidth>{
      for (var column = 0; column < columnCount; column++)
        column: FixedColumnWidth(cellWidth),
    };

    return Container(
      decoration: BoxDecoration(
        color: widget.palette.surface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: widget.palette.border),
      ),
      clipBehavior: Clip.antiAlias,
      child: Scrollbar(
        controller: _controller,
        thumbVisibility: tableWidth > availableWidth,
        interactive: true,
        child: SingleChildScrollView(
          controller: _controller,
          scrollDirection: Axis.horizontal,
          physics: const ClampingScrollPhysics(),
          child: SizedBox(
            width: tableWidth,
            child: Table(
              columnWidths: widths,
              border: widget.styleSheet.tableBorder,
              defaultVerticalAlignment: TableCellVerticalAlignment.middle,
              children: [
                for (var row = 0; row < widget.rows.length; row++)
                  TableRow(
                    decoration: row == 0
                        ? widget.styleSheet.tableHeaderDecoration
                        : row.isOdd
                        ? widget.styleSheet.tableOddRowDecoration
                        : widget.styleSheet.tableEvenRowDecoration,
                    children: [
                      for (var column = 0; column < columnCount; column++)
                        _cell(
                          row < widget.rows.length &&
                                  column < widget.rows[row].length
                              ? widget.rows[row][column]
                              : '',
                          header: row == 0,
                          width: (cellWidth - padding.horizontal)
                              .clamp(40.0, cellWidth)
                              .toDouble(),
                          padding: padding,
                        ),
                    ],
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _cell(
    String value, {
    required bool header,
    required double width,
    required EdgeInsets padding,
  }) {
    final cellStyle =
        (header
            ? widget.styleSheet.tableHeaderStyle
            : widget.styleSheet.tableCellStyle) ??
        widget.styleSheet.textStyle ??
        const TextStyle(fontSize: 13);

    final sheet = widget.styleSheet.copyWith(
      textStyle: cellStyle,
      paragraphStyle: cellStyle,
      blockSpacing: 0,
    );

    return Padding(
      padding: padding,
      child: SizedBox(
        width: width,
        child: value.trim().isEmpty
            ? const SizedBox(height: 20)
            : SmoothMarkdown(
                data: value,
                styleSheet: sheet,
                selectable: true,
                onTapLink: widget.onTapLink,
              ),
      ),
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
        return LucideIcons.code2;
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
        return LucideIcons.code2;
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
        return LucideIcons.code2;
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
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
            decoration: BoxDecoration(
              color: palette.surfaceAlt,
              border: Border(bottom: BorderSide(color: palette.border)),
            ),
            child: Row(
              children: [
                Icon(_languageIcon(), size: 16, color: palette.textSecondary),
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
                    await Clipboard.setData(ClipboardData(text: code));

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
