import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;

import '../../core/api.dart';

class ImageViewerScreen extends StatefulWidget {
  const ImageViewerScreen({
    super.key,
    required this.imageUrl,
    required this.originalPrompt,
    required this.messageId,
    required this.chatId,
  });

  final String imageUrl;
  final String originalPrompt;
  final String? messageId;
  final String? chatId;

  @override
  State<ImageViewerScreen> createState() => _ImageViewerScreenState();
}

class _ImageViewerScreenState extends State<ImageViewerScreen> {
  bool _downloading = false;
  bool _reporting = false;

  static const _styles = <({String name, String prompt})>[
    (name: 'Cinematográfico', prompt: 'fotografía cinematográfica, iluminación natural dramática, composición rica y detallada'),
    (name: 'Anime', prompt: 'ilustración anime original, líneas limpias, color expresivo y acabado profesional'),
    (name: '3D', prompt: 'render 3D de alta calidad, materiales detallados, iluminación de estudio suave'),
    (name: 'Acuarela', prompt: 'pintura tradicional de acuarela, textura de papel y pigmentos suaves'),
    (name: 'Pixel art', prompt: 'pixel art retro, píxeles precisos y paleta de color limitada'),
    (name: 'Minimalista', prompt: 'ilustración editorial minimalista, formas claras y pocos detalles'),
  ];

  void _showMessage(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message), behavior: SnackBarBehavior.floating),
    );
  }

  Future<void> _downloadImage() async {
    if (_downloading) return;
    setState(() => _downloading = true);
    try {
      final uri = Uri.tryParse(widget.imageUrl);
      if (uri == null || uri.scheme != 'https' || uri.host.isEmpty) {
        throw const FormatException('Enlace de imagen no válido.');
      }
      final response = await http
          .get(uri, headers: const {'Accept': 'image/png,image/jpeg,image/webp'})
          .timeout(const Duration(seconds: 35));
      if (response.statusCode != 200 || response.bodyBytes.isEmpty) {
        throw Exception('No se pudo descargar la imagen.');
      }

      final mime = (response.headers['content-type'] ?? 'image/png')
          .split(';').first.trim().toLowerCase();
      final String extension;
      final String mimeType;
      switch (mime) {
        case 'image/jpeg':
          extension = 'jpg';
          mimeType = 'image/jpeg';
        case 'image/webp':
          extension = 'webp';
          mimeType = 'image/webp';
        default:
          extension = 'png';
          mimeType = 'image/png';
      }

      final savedFile = await FilePicker.saveFile(
        dialogTitle: 'Guardar imagen de Numination',
        fileName: 'numination-imagen-${DateTime.now().millisecondsSinceEpoch}.$extension',
        bytes: response.bodyBytes,
        mimeType: mimeType,
      );
      if (!mounted) return;
      if (savedFile != null) _showMessage('Imagen guardada correctamente.');
    } catch (_) {
      _showMessage('No se pudo guardar la imagen. Inténtalo de nuevo.');
    } finally {
      if (mounted) setState(() => _downloading = false);
    }
  }

  Future<void> _chooseStyle() async {
    final style = await showModalBottomSheet<({String name, String prompt})>(
      context: context,
      backgroundColor: const Color(0xFF202020),
      showDragHandle: true,
      builder: (sheetContext) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 4, 16, 20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text('Cambiar estilo', style: TextStyle(
                color: Colors.white, fontSize: 19, fontWeight: FontWeight.w700,
              )),
              const SizedBox(height: 6),
              const Text(
                'Se preparará un prompt automáticamente para generar otra versión.',
                style: TextStyle(color: Colors.white70, fontSize: 13),
              ),
              const SizedBox(height: 12),
              ..._styles.map((item) => ListTile(
                contentPadding: EdgeInsets.zero,
                leading: const Icon(Icons.auto_awesome, color: Color(0xFFFF806E)),
                title: Text(item.name, style: const TextStyle(color: Colors.white)),
                trailing: const Icon(Icons.chevron_right, color: Colors.white54),
                onTap: () => Navigator.pop(sheetContext, item),
              )),
            ],
          ),
        ),
      ),
    );

    if (style == null || !mounted) return;
    final sourceDescription = widget.originalPrompt.trim().isEmpty
        ? 'Conserva el tema principal de la imagen de referencia.'
        : 'Descripción original: ${widget.originalPrompt.trim()}';
    final automaticPrompt = [
      'Genera una nueva imagen basada en esta descripción.',
      sourceDescription,
      'Aplica este estilo visual: ${style.prompt}.',
      'Mantén el sujeto principal, los objetos importantes y la intención de la escena.',
      'Formato panorámico horizontal con relación de aspecto exacta 19:6.',
      'No añadas texto, marcas de agua ni logotipos ajenos a la descripción.',
    ].join(' ');

    // Devuelve el prompt al chat para que el usuario pueda revisarlo antes de enviarlo.
    Navigator.of(context).pop(automaticPrompt);
  }

  Future<void> _reportImage() async {
    if (_reporting) return;
    if (widget.messageId == null || widget.chatId == null) {
      _showMessage('No se encontró el mensaje asociado a esta imagen.');
      return;
    }

    final noteController = TextEditingController();
    String category = 'inappropriate';
    final report = await showDialog<Map<String, String>>(
      context: context,
      builder: (dialogContext) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          title: const Text('Reportar esta imagen'),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('¿Qué problema encontraste?'),
                const SizedBox(height: 10),
                DropdownButtonFormField<String>(
                  value: category,
                  isExpanded: true,
                  items: const [
                    DropdownMenuItem(value: 'inappropriate', child: Text('Contenido inapropiado')),
                    DropdownMenuItem(value: 'spam', child: Text('Spam o contenido engañoso')),
                    DropdownMenuItem(value: 'rights', child: Text('Posible problema de derechos')),
                    DropdownMenuItem(value: 'other', child: Text('Otro problema')),
                  ],
                  onChanged: (value) {
                    if (value != null) setDialogState(() => category = value);
                  },
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: noteController,
                  minLines: 2,
                  maxLines: 4,
                  maxLength: 500,
                  decoration: const InputDecoration(
                    hintText: 'Detalles adicionales (opcional)',
                    border: OutlineInputBorder(),
                  ),
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dialogContext),
              child: const Text('Cancelar'),
            ),
            FilledButton(
              onPressed: () => Navigator.pop(dialogContext, {
                'category': category,
                'note': noteController.text.trim(),
              }),
              child: const Text('Enviar reporte'),
            ),
          ],
        ),
      ),
    );
    noteController.dispose();
    if (report == null || !mounted) return;

    setState(() => _reporting = true);
    try {
      final detail = (report['note'] ?? '').trim();
      final reportNote = [
        'REPORTE_DE_IMAGEN',
        'Categoría: ${report['category']}',
        if (detail.isNotEmpty) 'Detalle: $detail',
      ].join('\n');

      // El endpoint existente valida propiedad/mensaje, registra MessageFeedback
      // y genera la notificación interna; no inventa una ruta nueva.
      await ApiClient.post('/feedback', {
        'messageId': widget.messageId,
        'kind': 'negative',
        'note': reportNote,
      });
      _showMessage('Gracias. El reporte fue enviado para revisión.');
    } catch (_) {
      _showMessage('No se pudo enviar el reporte. Inténtalo de nuevo.');
    } finally {
      if (mounted) setState(() => _reporting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final heroTag = 'numi-image-${widget.messageId ?? widget.imageUrl}';
    return Scaffold(
      backgroundColor: Colors.black,
      body: SafeArea(
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(14, 10, 14, 8),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  _ViewerCircleButton(
                    icon: Icons.close,
                    tooltip: 'Cerrar imagen',
                    onPressed: () => Navigator.of(context).pop(),
                  ),
                  PopupMenuButton<String>(
                    tooltip: 'Más opciones',
                    color: const Color(0xFF2B2B2B),
                    icon: const Icon(Icons.more_vert, color: Colors.white, size: 25),
                    onSelected: (value) {
                      if (value == 'report') _reportImage();
                    },
                    itemBuilder: (context) => const [
                      PopupMenuItem<String>(
                        value: 'report',
                        child: Row(
                          children: [
                            Icon(Icons.flag_outlined, color: Colors.white70, size: 19),
                            SizedBox(width: 10),
                            Text('Reportar esta imagen', style: TextStyle(color: Colors.white)),
                          ],
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            Expanded(
              child: Center(
                child: InteractiveViewer(
                  minScale: 0.8,
                  maxScale: 4,
                  child: Hero(
                    tag: heroTag,
                    child: Image.network(
                      widget.imageUrl,
                      fit: BoxFit.contain,
                      loadingBuilder: (context, child, progress) => progress == null
                          ? child
                          : const SizedBox(
                              width: 44,
                              height: 44,
                              child: CircularProgressIndicator(
                                color: Color(0xFFFF806E), strokeWidth: 2.5,
                              ),
                            ),
                      errorBuilder: (context, error, stackTrace) => const Padding(
                        padding: EdgeInsets.all(24),
                        child: Text('No se pudo cargar esta imagen.',
                            style: TextStyle(color: Colors.white70)),
                      ),
                    ),
                  ),
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(12, 12, 12, 18),
              child: Row(
                children: [
                  Expanded(child: _ViewerAction(
                    icon: Icons.auto_awesome_outlined,
                    label: 'Cambiar estilo',
                    onPressed: _chooseStyle,
                  )),
                  const SizedBox(width: 10),
                  Expanded(child: _ViewerAction(
                    icon: _downloading ? Icons.hourglass_top : Icons.download_outlined,
                    label: _downloading ? 'Guardando…' : 'Descargar',
                    onPressed: _downloading ? null : _downloadImage,
                  )),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _ViewerCircleButton extends StatelessWidget {
  const _ViewerCircleButton({
    required this.icon, required this.tooltip, required this.onPressed,
  });
  final IconData icon;
  final String tooltip;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) => Material(
    color: const Color(0xFF303033),
    shape: const CircleBorder(),
    child: IconButton(
      tooltip: tooltip,
      onPressed: onPressed,
      icon: Icon(icon, color: Colors.white, size: 23),
    ),
  );
}

class _ViewerAction extends StatelessWidget {
  const _ViewerAction({
    required this.icon, required this.label, required this.onPressed,
  });
  final IconData icon;
  final String label;
  final VoidCallback? onPressed;

  @override
  Widget build(BuildContext context) => Column(
    mainAxisSize: MainAxisSize.min,
    children: [
      Material(
        color: const Color(0xFF303033),
        shape: const CircleBorder(),
        child: IconButton(
          tooltip: label,
          onPressed: onPressed,
          icon: Icon(icon, color: Colors.white, size: 22),
          iconSize: 22,
          padding: const EdgeInsets.all(15),
        ),
      ),
      const SizedBox(height: 7),
      Text(label, maxLines: 1, overflow: TextOverflow.ellipsis,
          style: const TextStyle(color: Colors.white, fontSize: 13)),
    ],
  );
}
