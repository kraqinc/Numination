import 'dart:async';
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:lucide_flutter/lucide_flutter.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:webview_flutter/webview_flutter.dart';

import '../../core/error_messages.dart';

class CoderPreviewCard extends StatelessWidget {
  const CoderPreviewCard({
    super.key,
    required this.ready,
    required this.onOpen,
  });

  final bool ready;
  final VoidCallback onOpen;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final english = Localizations.localeOf(context).languageCode == 'en';

    return Container(
      margin: const EdgeInsets.fromLTRB(2, 10, 2, 14),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(22),
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            scheme.surfaceContainerHighest.withValues(alpha: .72),
            scheme.surface.withValues(alpha: .96),
          ],
        ),
        border: Border.all(color: scheme.outline.withValues(alpha: .22)),
        boxShadow: [
          BoxShadow(
            blurRadius: 28,
            spreadRadius: -12,
            offset: const Offset(0, 14),
            color: Colors.black.withValues(alpha: .28),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Container(
                width: 42,
                height: 42,
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(13),
                  color: scheme.primary.withValues(alpha: .12),
                  border: Border.all(color: scheme.primary.withValues(alpha: .22)),
                ),
                child: Icon(LucideIcons.monitorPlay, color: scheme.primary),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  english ? 'Live preview' : 'Vista previa',
                  style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w800),
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 5),
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(999),
                  color: ready
                      ? scheme.primary.withValues(alpha: .12)
                      : scheme.surfaceContainerHighest.withValues(alpha: .7),
                ),
                child: Text(
                  ready
                      ? (english ? 'READY' : 'LISTO')
                      : (english ? 'WAITING' : 'ESPERANDO'),
                  style: TextStyle(
                    fontSize: 10,
                    fontWeight: FontWeight.w800,
                    letterSpacing: .6,
                    color: ready ? scheme.primary : scheme.onSurfaceVariant,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          Text(
            ready
                ? (english ? 'Open the current version of your project.' : 'Abre la versión actual de tu proyecto.')
                : AppErrorMessages.previewNotReady,
            style: TextStyle(fontSize: 13, height: 1.35, color: scheme.onSurfaceVariant),
          ),
          const SizedBox(height: 14),
          SizedBox(
            height: 52,
            child: FilledButton.icon(
              onPressed: onOpen,
              icon: const Icon(LucideIcons.play, size: 19),
              label: Text(
                ready
                    ? (english ? 'Open preview' : 'Abrir vista previa')
                    : (english ? 'Check preview' : 'Comprobar vista previa'),
                style: const TextStyle(fontWeight: FontWeight.w800),
              ),
              style: FilledButton.styleFrom(
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class CoderPreviewScreen extends StatefulWidget {
  const CoderPreviewScreen({
    super.key,
    required this.previewUrl,
    required this.projectName,
  });

  final String previewUrl;
  final String projectName;

  @override
  State<CoderPreviewScreen> createState() => _CoderPreviewScreenState();
}

class _CoderPreviewScreenState extends State<CoderPreviewScreen> {
  late final WebViewController _controller;
  int _progress = 0;
  bool _loading = true;
  String? _error;

  bool get _english => Localizations.localeOf(context).languageCode == 'en';

  @override
  void initState() {
    super.initState();
    _controller = WebViewController()
      ..setJavaScriptMode(JavaScriptMode.unrestricted)
      ..setBackgroundColor(const Color(0xFF080A0C))
      ..setNavigationDelegate(
        NavigationDelegate(
          onProgress: (progress) {
            if (!mounted) return;
            setState(() {
              _progress = progress;
              _loading = progress < 100;
            });
          },
          onPageStarted: (_) {
            if (!mounted) return;
            setState(() {
              _loading = true;
              _error = null;
              _progress = 0;
            });
          },
          onPageFinished: (_) { _inspectLoadedPage(); },
          onWebResourceError: (error) {
            if (error.isForMainFrame == false || !mounted) return;
            setState(() {
              _loading = false;
              _error = AppErrorMessages.previewLoadFailed;
            });
          },
        ),
      );
    _loadPreview();
  }

  Future<void> _loadPreview() async {
    final uri = Uri.tryParse(widget.previewUrl.trim());
    if (uri == null || uri.host.isEmpty || (uri.scheme != 'https' && uri.scheme != 'http')) {
      if (mounted) setState(() {
        _loading = false;
        _error = AppErrorMessages.previewInvalidAddress;
      });
      return;
    }
    try {
      await _controller.loadRequest(uri);
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _loading = false;
        _error = AppErrorMessages.previewLoadFailed;
      });
    }
  }

  String _stringResult(Object? value) {
    var result = value?.toString() ?? '';
    if (result.length >= 2 && result.startsWith('"') && result.endsWith('"')) {
      try {
        final decoded = jsonDecode(result);
        if (decoded is String) result = decoded;
      } catch (_) {}
    }
    return result;
  }

  Future<void> _inspectLoadedPage() async {
    await Future<void>.delayed(const Duration(milliseconds: 800));
    if (!mounted) return;

    try {
      final bodyValue = await _controller.runJavaScriptReturningResult(
        'document.body ? document.body.innerText : ""',
      );
      final body = _stringResult(bodyValue).trim();
      final lower = body.toLowerCase();

      String? detectedError;
      if (lower.contains('requested path is invalid')) {
        detectedError = AppErrorMessages.previewInvalidAddress;
      } else if (lower.contains('preview no autorizado') || lower.contains('preview unauthorized') || lower.contains('token') && lower.contains('expired')) {
        detectedError = AppErrorMessages.previewExpired;
      } else if (lower.contains('proyecto no encontrado') || lower.contains('project not found')) {
        detectedError = AppErrorMessages.previewProjectMissing;
      } else if (lower.startsWith('{"error"') || lower.startsWith('{"message"')) {
        detectedError = AppErrorMessages.previewInvalidAddress;
      } else if (lower.contains('numination preview') && (lower.contains('error:') || lower.contains('no se pudo resolver') || lower.contains('dependencia externa'))) {
        detectedError = AppErrorMessages.fromPreviewRuntime(body);
      }

      if (detectedError != null) {
        if (!mounted) return;
        setState(() {
          _loading = false;
          _progress = 100;
          _error = detectedError;
        });
        return;
      }

      final rootValue = await _controller.runJavaScriptReturningResult(
        'document.getElementById("root") ? document.getElementById("root").children.length : 0',
      );
      final rootChildren = int.tryParse(_stringResult(rootValue).replaceAll('"', '').trim()) ?? 0;

      if (rootChildren == 0) {
        if (!mounted) return;
        setState(() {
          _loading = false;
          _progress = 100;
          _error = AppErrorMessages.previewDidNotRender;
        });
        return;
      }
    } catch (_) {
      // Some WebView engines restrict script inspection; the page can still render normally.
    }

    if (!mounted) return;
    setState(() {
      _loading = false;
      _progress = 100;
    });
  }

  Future<void> _openExternal() async {
    final uri = Uri.tryParse(widget.previewUrl);
    if (uri == null || uri.host.isEmpty) {
      if (mounted) setState(() => _error = AppErrorMessages.previewInvalidAddress);
      return;
    }
    try {
      final opened = await launchUrl(uri, mode: LaunchMode.externalApplication);
      if (!opened && mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(AppErrorMessages.previewLoadFailed)),
        );
      }
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(AppErrorMessages.previewLoadFailed)),
        );
      }
    }
  }

  void _reload() {
    setState(() {
      _error = null;
      _loading = true;
      _progress = 0;
    });
    _loadPreview();
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;

    return Scaffold(
      backgroundColor: const Color(0xFF080A0C),
      appBar: AppBar(
        titleSpacing: 4,
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              widget.projectName,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w800),
            ),
            Text(
              _english ? 'Preview · Vite + React' : 'Vista previa · Vite + React',
              style: const TextStyle(fontSize: 11),
            ),
          ],
        ),
        actions: [
          IconButton(
            tooltip: _english ? 'Reload' : 'Recargar',
            onPressed: _reload,
            icon: const Icon(LucideIcons.refreshCw),
          ),
          IconButton(
            tooltip: _english ? 'Open outside Numination' : 'Abrir fuera de Numination',
            onPressed: _openExternal,
            icon: const Icon(LucideIcons.externalLink),
          ),
          const SizedBox(width: 4),
        ],
      ),
      body: Column(
        children: [
          if (_loading)
            LinearProgressIndicator(
              value: _progress > 0 ? _progress / 100 : null,
              minHeight: 2,
            )
          else
            const SizedBox(height: 2),
          Expanded(
            child: _error != null
                ? Center(
                    child: SingleChildScrollView(
                      padding: const EdgeInsets.all(24),
                      child: ConstrainedBox(
                        constraints: const BoxConstraints(maxWidth: 440),
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(LucideIcons.triangleAlert, size: 38, color: scheme.error),
                            const SizedBox(height: 14),
                            Text(
                              _english ? 'Preview could not be displayed' : 'No se pudo mostrar la vista previa',
                              textAlign: TextAlign.center,
                              style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w800, color: Colors.white),
                            ),
                            const SizedBox(height: 8),
                            Text(
                              _error!,
                              textAlign: TextAlign.center,
                              style: const TextStyle(color: Color(0xFFB9C1C9), height: 1.45),
                            ),
                            const SizedBox(height: 18),
                            FilledButton.icon(
                              onPressed: _reload,
                              icon: const Icon(LucideIcons.refreshCw),
                              label: Text(_english ? 'Try again' : 'Reintentar'),
                            ),
                            const SizedBox(height: 8),
                            TextButton.icon(
                              onPressed: _openExternal,
                              icon: const Icon(LucideIcons.externalLink),
                              label: Text(_english ? 'Open in browser' : 'Abrir en el navegador'),
                            ),
                          ],
                        ),
                      ),
                    ),
                  )
                : ClipRRect(
                    borderRadius: const BorderRadius.vertical(top: Radius.circular(14)),
                    child: WebViewWidget(controller: _controller),
                  ),
          ),
        ],
      ),
    );
  }
}
