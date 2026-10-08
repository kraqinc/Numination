import 'package:flutter/material.dart';
import 'package:lucide_flutter/lucide_flutter.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:webview_flutter/webview_flutter.dart';

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
                  border: Border.all(
                    color: scheme.primary.withValues(alpha: .22),
                  ),
                ),
                child: Icon(LucideIcons.monitorPlay, color: scheme.primary),
              ),
              const SizedBox(width: 12),
              const Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Preview',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    SizedBox(height: 2),
                    Text('Vite + React', style: TextStyle(fontSize: 12)),
                  ],
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
                  ready ? 'LISTO' : 'ESPERANDO',
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
                ? 'Tu proyecto ya tiene una vista ejecutable.'
                : 'Nada qe hacer por ahora',
            style: TextStyle(
              fontSize: 13,
              height: 1.35,
              color: scheme.onSurfaceVariant,
            ),
          ),
          const SizedBox(height: 14),
          SizedBox(
            height: 52,
            child: FilledButton.icon(
              onPressed: ready ? onOpen : null,
              icon: const Icon(LucideIcons.play, size: 19),
              label: const Text(
                'Ver ahora',
                style: TextStyle(fontWeight: FontWeight.w800),
              ),
              style: FilledButton.styleFrom(
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(15),
                ),
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

  @override
  void initState() {
    super.initState();

    _controller = WebViewController()
      ..setJavaScriptMode(JavaScriptMode.unrestricted)
      ..setBackgroundColor(Colors.transparent)
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
            });
          },
          onPageFinished: (_) {
            if (!mounted) return;

            setState(() {
              _loading = false;
              _progress = 100;
            });
          },
          onWebResourceError: (error) {
            if (!mounted) return;

            setState(() {
              _loading = false;
              _error = error.description.isEmpty
                  ? 'No se pudo cargar el preview.'
                  : error.description;
            });
          },
        ),
      )
      ..loadRequest(Uri.parse(widget.previewUrl));
  }

  Future<void> _openExternal() async {
    final uri = Uri.tryParse(widget.previewUrl);
    if (uri == null) return;

    final opened = await launchUrl(uri, mode: LaunchMode.externalApplication);

    if (!opened && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('No se pudo abrir el preview.')),
      );
    }
  }

  void _reload() {
    setState(() {
      _error = null;
      _loading = true;
      _progress = 0;
    });

    _controller.reload();
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;

    return Scaffold(
      backgroundColor: scheme.surface,
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
            const Text(
              'Preview · Vite + React',
              style: TextStyle(fontSize: 11),
            ),
          ],
        ),
        actions: [
          IconButton(
            tooltip: 'Recargar',
            onPressed: _reload,
            icon: const Icon(LucideIcons.refreshCw),
          ),
          IconButton(
            tooltip: 'Abrir fuera de Numination',
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
                    child: Padding(
                      padding: const EdgeInsets.all(24),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(
                            LucideIcons.triangleAlert,
                            size: 34,
                            color: scheme.error,
                          ),
                          const SizedBox(height: 14),
                          const Text(
                            'El preview encontró un problema',
                            textAlign: TextAlign.center,
                            style: TextStyle(
                              fontSize: 17,
                              fontWeight: FontWeight.w800,
                            ),
                          ),
                          const SizedBox(height: 7),
                          Text(
                            _error!,
                            textAlign: TextAlign.center,
                            style: TextStyle(
                              color: scheme.onSurfaceVariant,
                              height: 1.35,
                            ),
                          ),
                          const SizedBox(height: 18),
                          FilledButton.icon(
                            onPressed: _reload,
                            icon: const Icon(LucideIcons.refreshCw),
                            label: const Text('Reintentar'),
                          ),
                        ],
                      ),
                    ),
                  )
                : ClipRRect(
                    borderRadius: const BorderRadius.vertical(
                      top: Radius.circular(14),
                    ),
                    child: WebViewWidget(controller: _controller),
                  ),
          ),
        ],
      ),
    );
  }
}
