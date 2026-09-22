import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../core/api.dart';
import '../../core/l10n_extensions.dart';
import '../../core/models.dart';
import '../../core/theme.dart';
import '../../core/theme_controller.dart';

class ArtifactsScreen extends ConsumerStatefulWidget {
  const ArtifactsScreen({super.key});

  @override
  ConsumerState<ArtifactsScreen> createState() => _ArtifactsScreenState();
}

class _ArtifactsScreenState extends ConsumerState<ArtifactsScreen> {
  bool _isLoading = true;
  List<ArtifactItem> _artifacts = [];
  String? _errorText;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() {
      _isLoading = true;
      _errorText = null;
    });
    try {
      final response = await ApiClient.get('/artifacts');
      final data = ApiClient.decode(response) as Map<String, dynamic>;
      final list = (data['artifacts'] as List? ?? [])
          .map((e) => ArtifactItem.fromJson(Map<String, dynamic>.from(e as Map)))
          .toList();
      setState(() {
        _artifacts = list;
        _isLoading = false;
      });
    } catch (e) {
      setState(() {
        _isLoading = false;
        _errorText = 'No se pudieron cargar tus artifacts';
      });
    }
  }

  Future<void> _delete(ArtifactItem artifact) async {
    final palette = ref.read(appPaletteProvider);
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        backgroundColor: palette.surface,
        title: Text('Eliminar artifact', style: TextStyle(color: palette.textPrimary)),
        content: Text(
          '¿Seguro que quieres eliminar "${artifact.title}"?',
          style: TextStyle(color: palette.textSecondary),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(false),
            child: Text(context.l10n.cancel, style: TextStyle(color: palette.textSecondary)),
          ),
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(true),
            child: const Text('Eliminar', style: TextStyle(color: Colors.redAccent)),
          ),
        ],
      ),
    );
    if (confirmed != true) return;

    try {
      await ApiClient.delete('/artifacts/${artifact.id}');
      setState(() => _artifacts.removeWhere((a) => a.id == artifact.id));
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('No se pudo eliminar el artifact')),
      );
    }
  }

  void _openArtifact(ArtifactItem artifact) {
    if (artifact.isFile) {
      _openFile(artifact);
      return;
    }
    _openSnippet(artifact);
  }

  Future<void> _openFile(ArtifactItem artifact) async {
    if (artifact.storagePath == null) return;
    try {
      final signed = await Supabase.instance.client.storage
          .from('artifacts')
          .createSignedUrl(artifact.storagePath!, 600); // 10 min
      final uri = Uri.parse(signed);
      if (await canLaunchUrl(uri)) {
        await launchUrl(uri, mode: LaunchMode.externalApplication);
      } else if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('No se pudo abrir el archivo')),
        );
      }
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('No se pudo generar el enlace del archivo')),
      );
    }
  }

  void _openSnippet(ArtifactItem artifact) {
    final palette = ref.read(appPaletteProvider);
    showModalBottomSheet(
      context: context,
      backgroundColor: palette.surface,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (sheetContext) => DraggableScrollableSheet(
        initialChildSize: 0.75,
        minChildSize: 0.4,
        maxChildSize: 0.95,
        expand: false,
        builder: (context, scrollController) => Column(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 12, 8, 8),
              child: Row(
                children: [
                  Expanded(
                    child: Text(
                      artifact.title,
                      style: TextStyle(color: palette.textPrimary, fontSize: 16, fontWeight: FontWeight.w600),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  IconButton(
                    icon: Icon(Icons.copy, color: palette.textSecondary, size: 20),
                    onPressed: () {
                      Clipboard.setData(ClipboardData(text: artifact.content));
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(content: Text('Copiado al portapapeles')),
                      );
                    },
                  ),
                  IconButton(
                    icon: Icon(Icons.close, color: palette.textSecondary, size: 20),
                    onPressed: () => Navigator.of(sheetContext).pop(),
                  ),
                ],
              ),
            ),
            const Divider(height: 1),
            Expanded(
              child: SingleChildScrollView(
                controller: scrollController,
                padding: const EdgeInsets.all(16),
                child: SelectableText(
                  artifact.content,
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
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final palette = ref.watch(appPaletteProvider);

    return Scaffold(
      backgroundColor: palette.background,
      appBar: AppBar(
        backgroundColor: palette.background,
        elevation: 0,
        iconTheme: IconThemeData(color: palette.textPrimary),
        title: Text(context.l10n.artifacts, style: TextStyle(color: palette.textPrimary)),
      ),
      body: RefreshIndicator(
        onRefresh: _load,
        child: _isLoading
            ? Center(child: CircularProgressIndicator(color: palette.textPrimary))
            : _artifacts.isEmpty
                ? _EmptyArtifactsState(errorText: _errorText, palette: palette)
                : ListView.separated(
                    padding: const EdgeInsets.all(16),
                    itemCount: _artifacts.length,
                    separatorBuilder: (_, __) => const SizedBox(height: 10),
                    itemBuilder: (context, index) {
                      final artifact = _artifacts[index];
                      return InkWell(
                        borderRadius: BorderRadius.circular(14),
                        onTap: () => _openArtifact(artifact),
                        child: Container(
                          padding: const EdgeInsets.all(16),
                          decoration: BoxDecoration(
                            color: palette.surface,
                            borderRadius: BorderRadius.circular(14),
                            border: Border.all(color: palette.border),
                          ),
                          child: Row(
                            children: [
                              Container(
                                width: 40,
                                height: 40,
                                decoration: BoxDecoration(
                                  color: palette.background,
                                  borderRadius: BorderRadius.circular(10),
                                  border: Border.all(color: palette.border),
                                ),
                                child: Icon(
                                  artifact.isFile ? Icons.attach_file_rounded : Icons.code_rounded,
                                  color: palette.accent,
                                  size: 20,
                                ),
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      artifact.title,
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                      style: TextStyle(color: palette.textPrimary, fontSize: 15, fontWeight: FontWeight.w600),
                                    ),
                                    const SizedBox(height: 2),
                                    Text(
                                      artifact.isFile
                                          ? (artifact.mimeType?.isNotEmpty == true ? artifact.mimeType! : 'Archivo')
                                          : artifact.language,
                                      style: TextStyle(color: palette.textSecondary, fontSize: 12),
                                    ),
                                  ],
                                ),
                              ),
                              IconButton(
                                icon: Icon(Icons.delete_outline, color: palette.textSecondary, size: 20),
                                onPressed: () => _delete(artifact),
                              ),
                            ],
                          ),
                        ),
                      );
                    },
                  ),
      ),
    );
  }
}

class _EmptyArtifactsState extends StatelessWidget {
  const _EmptyArtifactsState({this.errorText, required this.palette});
  final String? errorText;
  final AppPalette palette;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) => SingleChildScrollView(
        physics: const AlwaysScrollableScrollPhysics(),
        child: ConstrainedBox(
          constraints: BoxConstraints(minHeight: constraints.maxHeight),
          child: Center(
            child: Padding(
              padding: const EdgeInsets.all(32),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(
                    width: 72,
                    height: 72,
                    decoration: BoxDecoration(
                      color: palette.surface,
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(color: palette.border),
                    ),
                    child: Icon(Icons.code_rounded, color: palette.accent, size: 36),
                  ),
                  const SizedBox(height: 20),
                  Text(
                    'Sin artifacts todavía',
                    style: TextStyle(color: palette.textPrimary, fontSize: 18, fontWeight: FontWeight.w600),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 6),
                  Text(
                    'Los snippets de código que guardes desde el chat en modo Coder aparecerán aquí.',
                    style: TextStyle(color: palette.textSecondary, fontSize: 14),
                    textAlign: TextAlign.center,
                  ),
                  if (errorText != null) ...[
                    const SizedBox(height: 16),
                    Text(errorText!, style: const TextStyle(color: Colors.redAccent, fontSize: 13)),
                  ],
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}