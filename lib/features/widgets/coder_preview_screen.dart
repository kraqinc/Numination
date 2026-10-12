import 'dart:async';
import 'dart:convert';
import 'dart:math' as math;

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
    this.openingPreview = false,
    this.message,
  });

  final bool ready;
  final bool openingPreview;
  final String? message;
  final VoidCallback onOpen;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final english = Localizations.localeOf(context).languageCode == 'en';
    final messageText = message?.trim() ?? '';

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
              Expanded(
                child: Text(
                  english ? 'Live preview' : 'Vista previa',
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w800,
                  ),
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
            openingPreview
                ? (english
                      ? 'Checking and opening preview...'
                      : 'Comprobando y abriendo la vista previa...')
                : ready
                ? (english
                      ? 'Open the current version of your project.'
                      : 'Abre la versión actual de tu proyecto.')
                : (messageText.isNotEmpty
                      ? messageText
                      : AppErrorMessages.previewNotReady),
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
              onPressed: openingPreview ? null : onOpen,
              icon: openingPreview
                  ? const SizedBox(
                      width: 19,
                      height: 19,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Icon(LucideIcons.play, size: 19),
              label: Text(
                openingPreview
                    ? (english ? 'Opening...' : 'Abriendo...')
                    : ready
                    ? (english ? 'Open preview' : 'Abrir vista previa')
                    : (english ? 'Check preview' : 'Comprobar vista previa'),
                style: const TextStyle(fontWeight: FontWeight.w800),
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

class _LegoPreviewLoader extends StatefulWidget {
  const _LegoPreviewLoader({required this.loading});

  final bool loading;

  @override
  State<_LegoPreviewLoader> createState() => _LegoPreviewLoaderState();
}

class _LegoPreviewLoaderState extends State<_LegoPreviewLoader>
    with TickerProviderStateMixin {
  late final AnimationController _buildController;
  late final AnimationController _exitController;

  bool _hidden = false;

  @override
  void initState() {
    super.initState();

    _buildController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 2200),
    );

    _exitController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 520),
    );

    if (widget.loading) {
      _buildController.repeat();
    } else {
      _hidden = true;
      _buildController.value = 0.7;
      _exitController.value = 1;
    }
  }

  @override
  void didUpdateWidget(covariant _LegoPreviewLoader oldWidget) {
    super.didUpdateWidget(oldWidget);

    if (oldWidget.loading && !widget.loading) {
      // Dejamos el marco completo y después dispersamos sus piezas.
      _buildController.stop();
      _buildController.value = 0.7;

      _exitController.forward(from: 0).whenComplete(() {
        if (mounted) {
          setState(() => _hidden = true);
        }
      });
    } else if (!oldWidget.loading && widget.loading) {
      _hidden = false;
      _exitController.stop();
      _exitController.reset();
      _buildController.repeat();
    }
  }

  List<Offset> get _brickPositions => [
    for (var column = 0; column < 5; column++) Offset(column * 40.0, 0),
    for (var row = 1; row < 3; row++) Offset(160, row * 26.0),
    for (var column = 4; column >= 0; column--) Offset(column * 40.0, 78),
    for (var row = 2; row >= 1; row--) Offset(0, row * 26.0),
  ];

  @override
  void dispose() {
    _buildController.dispose();
    _exitController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (_hidden) return const SizedBox.shrink();

    final colors = Theme.of(context).colorScheme;
    final english = Localizations.localeOf(context).languageCode == 'en';

    return AnimatedBuilder(
      animation: Listenable.merge([_buildController, _exitController]),
      builder: (context, _) {
        final phase = widget.loading ? _buildController.value : 0.7;

        final cycleExplosion = widget.loading && phase > 0.74
            ? ((phase - 0.74) / 0.26).clamp(0.0, 1.0).toDouble()
            : 0.0;

        final explosion = widget.loading
            ? cycleExplosion
            : _exitController.value;

        final backgroundOpacity = widget.loading
            ? 0.96
            : (0.96 * (1 - _exitController.value)).clamp(0.0, 1.0).toDouble();

        return IgnorePointer(
          child: Container(
            color: const Color(0xFF080A0C).withValues(alpha: backgroundOpacity),
            child: Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  SizedBox(
                    width: 194,
                    height: 100,
                    child: Stack(
                      clipBehavior: Clip.none,
                      children: List.generate(_brickPositions.length, (index) {
                        final point = _brickPositions[index];

                        final building = phase < 0.45
                            ? ((phase - index * 0.022) / 0.075)
                                  .clamp(0.0, 1.0)
                                  .toDouble()
                            : 1.0;

                        final opacity = (building * (1 - explosion))
                            .clamp(0.0, 1.0)
                            .toDouble();

                        final angle = index * 2.399963229728653;
                        final distance = explosion * 118;

                        return Positioned(
                          left: point.dx,
                          top: point.dy,
                          width: 34,
                          height: 21,
                          child: Opacity(
                            opacity: opacity,
                            child: Transform.translate(
                              offset: Offset(
                                math.cos(angle) * distance,
                                math.sin(angle) * distance * 0.75,
                              ),
                              child: Transform.rotate(
                                angle: angle * explosion * 1.15,
                                child: Transform.scale(
                                  scale: 1 - explosion * 0.62,
                                  child: _LegoPreviewBrick(
                                    color: index.isEven
                                        ? colors.primary
                                        : colors.tertiary,
                                  ),
                                ),
                              ),
                            ),
                          ),
                        );
                      }),
                    ),
                  ),
                  const SizedBox(height: 24),
                  Text(
                    english ? 'Building preview' : 'Construyendo vista previa',
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 16,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    english
                        ? 'Assembling the interface'
                        : 'Ensamblando la interfaz',
                    style: const TextStyle(
                      color: Color(0xFFADB7C7),
                      fontSize: 12,
                    ),
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }
}

class _LegoPreviewBrick extends StatelessWidget {
  const _LegoPreviewBrick({required this.color});

  final Color color;

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            color.withValues(alpha: 0.98),
            color.withValues(alpha: 0.68),
          ],
        ),
        borderRadius: BorderRadius.circular(5),
        border: Border.all(
          color: Colors.white.withValues(alpha: 0.38),
          width: 0.7,
        ),
        boxShadow: [
          BoxShadow(
            color: color.withValues(alpha: 0.22),
            blurRadius: 5,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(5, 2, 5, 3),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            for (var i = 0; i < 2; i++)
              Container(
                width: 7,
                height: 5,
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.48),
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
          ],
        ),
      ),
    );
  }
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
            if (!mounted) {
              return;
            }

            setState(() {
              _progress = progress;
              // La carga termina cuando acaba la inspección del DOM,
              // no simplemente cuando el WebView llega al 100 %.
              _loading = true;
            });
          },
          onPageStarted: (_) {
            if (!mounted) {
              return;
            }

            setState(() {
              _loading = true;
              _error = null;
              _progress = 0;
            });
          },
          onPageFinished: (_) {
            if (!mounted) return;
            setState(() {
              _loading = true;
              _progress = 0;
            });
            _inspectLoadedPage();
          },
          onWebResourceError: (error) {
            if (error.isForMainFrame == false || !mounted) {
              return;
            }

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

    if (uri == null ||
        uri.host.isEmpty ||
        (uri.scheme != 'https' && uri.scheme != 'http')) {
      if (mounted) {
        setState(() {
          _loading = false;
          _error = AppErrorMessages.previewInvalidAddress;
        });
      }

      return;
    }

    try {
      await _controller.loadRequest(uri);
    } catch (_) {
      if (!mounted) {
        return;
      }

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

        if (decoded is String) {
          result = decoded;
        }
      } catch (_) {
        // Conserva el resultado original si no es JSON válido.
      }
    }

    return result;
  }

  Future<void> _inspectLoadedPage() async {
    try {
      // React puede tardar en montar el DOM. No declaramos la
      // página vacía tras una única comprobación demasiado pronto.
      for (var attempt = 0; attempt < 14; attempt++) {
        await Future<void>.delayed(const Duration(milliseconds: 400));

        if (!mounted) return;

        final probeValue = await _controller.runJavaScriptReturningResult(
          'JSON.stringify({'
          'body: document.body ? document.body.innerText : "",'
          'runtimeError: document.getElementById("numi-error")'
          '? document.getElementById("numi-error").innerText : "",'
          'rootChildren: (document.getElementById("root") || '
          'document.querySelector("main") || document.body).children.length,'
          'rootVisible: (() => {'
          'const root = document.getElementById("root") || '
          'document.querySelector("main") || document.body;'
          'if (!root || (root.children.length === 0 && '
          '!((root.innerText || "").trim()))) return false;'
          'const rect = root.getBoundingClientRect();'
          'const style = window.getComputedStyle(root);'
          'return rect.width > 0 && rect.height > 0 && '
          'style.display !== "none" && '
          'style.visibility !== "hidden";'
          '})()'
          '})',
        );

        final decoded = jsonDecode(_stringResult(probeValue));

        if (decoded is! Map) {
          throw const FormatException(
            'El WebView devolvió un diagnóstico inválido.',
          );
        }

        final body = (decoded['body']?.toString() ?? '').trim();
        final runtimeError = (decoded['runtimeError']?.toString() ?? '').trim();

        final visibleText = [
          if (body.isNotEmpty) body,
          if (runtimeError.isNotEmpty) runtimeError,
        ].join('\n');

        final lower = visibleText.toLowerCase();

        String? detectedError;

        if (lower.contains('requested path is invalid')) {
          detectedError = AppErrorMessages.previewInvalidAddress;
        } else if (lower.contains('preview no autorizado') ||
            lower.contains('preview unauthorized') ||
            (lower.contains('token') && lower.contains('expired'))) {
          detectedError = AppErrorMessages.previewExpired;
        } else if (lower.contains('proyecto no encontrado') ||
            lower.contains('project not found')) {
          detectedError = AppErrorMessages.previewProjectMissing;
        } else if (lower.contains('proyecto no previewable') ||
            lower.contains('no contiene una aplicación vite') ||
            lower.contains('project is not previewable')) {
          detectedError = AppErrorMessages.previewNotReady;
        } else if (lower.startsWith('{"error"') ||
            lower.startsWith('{"message"')) {
          detectedError = AppErrorMessages.previewInvalidAddress;
        } else if (lower.contains('numination preview') &&
            (lower.contains('error:') ||
                lower.contains('no se pudo resolver') ||
                lower.contains('dependencia externa'))) {
          detectedError = AppErrorMessages.fromPreviewRuntime(visibleText);
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

        final rootChildren = decoded['rootChildren'] is num
            ? (decoded['rootChildren'] as num).toInt()
            : 0;

        final rootVisible = decoded['rootVisible'] == true;

        if (rootChildren > 0 && rootVisible) {
          if (!mounted) return;

          setState(() {
            _loading = false;
            _progress = 100;
            _error = null;
          });
          return;
        }
      }

      if (!mounted) return;

      setState(() {
        _loading = false;
        _progress = 100;
        _error = AppErrorMessages.previewDidNotRender;
      });
    } catch (_) {
      // Antes este fallo se ignoraba y se mostraba una página vacía.
      if (!mounted) return;

      setState(() {
        _loading = false;
        _progress = 100;
        _error = AppErrorMessages.previewLoadFailed;
      });
    }
  }

  Future<void> _openExternal() async {
    final uri = Uri.tryParse(widget.previewUrl.trim());

    if (uri == null ||
        uri.host.isEmpty ||
        (uri.scheme != 'https' && uri.scheme != 'http')) {
      if (mounted) {
        setState(() {
          _error = AppErrorMessages.previewInvalidAddress;
        });
      }

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
              _english
                  ? 'Preview · Vite + React'
                  : 'Vista previa · Vite + React',
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
            tooltip: _english
                ? 'Open outside Numination'
                : 'Abrir fuera de Numination',
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
            child: Stack(
              fit: StackFit.expand,
              children: [
                _error != null
                    ? Center(
                        child: SingleChildScrollView(
                          padding: const EdgeInsets.all(24),
                          child: ConstrainedBox(
                            constraints: const BoxConstraints(maxWidth: 440),
                            child: Column(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(
                                  LucideIcons.triangleAlert,
                                  size: 38,
                                  color: scheme.error,
                                ),
                                const SizedBox(height: 14),
                                Text(
                                  _english
                                      ? 'Preview could not be displayed'
                                      : 'No se pudo mostrar la vista previa',
                                  textAlign: TextAlign.center,
                                  style: const TextStyle(
                                    fontSize: 17,
                                    fontWeight: FontWeight.w800,
                                    color: Colors.white,
                                  ),
                                ),
                                const SizedBox(height: 8),
                                Text(
                                  _error!,
                                  textAlign: TextAlign.center,
                                  style: const TextStyle(
                                    color: Color(0xFFB9C1C9),
                                    height: 1.45,
                                  ),
                                ),
                                const SizedBox(height: 18),
                                FilledButton.icon(
                                  onPressed: _reload,
                                  icon: const Icon(LucideIcons.refreshCw),
                                  label: Text(
                                    _english ? 'Try again' : 'Reintentar',
                                  ),
                                ),
                                const SizedBox(height: 8),
                                TextButton.icon(
                                  onPressed: _openExternal,
                                  icon: const Icon(LucideIcons.externalLink),
                                  label: Text(
                                    _english
                                        ? 'Open in browser'
                                        : 'Abrir en el navegador',
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      )
                    : ClipRRect(
                        borderRadius: const BorderRadius.vertical(
                          top: Radius.circular(14),
                        ),
                        child: WebViewWidget(controller: _controller),
                      ),
                _LegoPreviewLoader(loading: _loading),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
