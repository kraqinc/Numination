import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/api.dart';
import '../../core/i18n.dart';
import '../../core/theme.dart';
import '../../core/theme_controller.dart';

class UploadedFile {
  final String id;
  final String key;
  final String url;
  final int size;
  final String? mimeType;
  final String createdAt;
  const UploadedFile({
    required this.id,
    required this.key,
    required this.url,
    required this.size,
    this.mimeType,
    required this.createdAt,
  });

  factory UploadedFile.fromJson(Map<String, dynamic> json) => UploadedFile(
    id: '${json['id'] ?? ''}',
    key: '${json['key'] ?? ''}',
    url: '${json['url'] ?? ''}',
    size: (json['size'] as num?)?.toInt() ?? 0,
    mimeType: json['mimeType']?.toString(),
    createdAt: '${json['createdAt'] ?? ''}',
  );

  String get displayName => key.split('/').last;

  IconData get icon {
    final mime = mimeType ?? '';
    if (mime.startsWith('image/')) return Icons.image_outlined;
    if (mime.startsWith('video/')) return Icons.videocam_outlined;
    if (mime.contains('pdf')) return Icons.picture_as_pdf_outlined;
    if (mime.startsWith('audio/')) return Icons.audiotrack_outlined;
    return Icons.insert_drive_file_outlined;
  }

  String get sizeLabel {
    if (size < 1024) return '$size B';
    if (size < 1024 * 1024) return '${(size / 1024).toStringAsFixed(1)} KB';
    return '${(size / (1024 * 1024)).toStringAsFixed(1)} MB';
  }
}

class UploadedFilesScreen extends ConsumerStatefulWidget {
  const UploadedFilesScreen({super.key});

  @override
  ConsumerState<UploadedFilesScreen> createState() =>
      _UploadedFilesScreenState();
}

class _UploadedFilesScreenState extends ConsumerState<UploadedFilesScreen> {
  bool _isLoading = true;
  List<UploadedFile> _files = [];
  String? _errorText;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() => _isLoading = true);
    try {
      final response = await ApiClient.get('/storage/files');
      final data = ApiClient.decode(response) as Map<String, dynamic>;
      final list = (data['files'] as List? ?? [])
          .map(
            (e) => UploadedFile.fromJson(Map<String, dynamic>.from(e as Map)),
          )
          .toList();
      setState(() {
        _files = list;
        _isLoading = false;
      });
    } catch (e) {
      setState(() {
        _isLoading = false;
        _errorText = 'No se pudieron cargar tus artefactos';
      });
    }
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
        title: Text(
          AppLocale.t('artifacts'),
          style: TextStyle(color: palette.textPrimary),
        ),
      ),
      body: _isLoading
          ? Center(child: CircularProgressIndicator(color: palette.textPrimary))
          : _files.isEmpty
          ? _EmptyFilesState(errorText: _errorText, palette: palette)
          : ListView.separated(
              padding: const EdgeInsets.all(16),
              itemCount: _files.length,
              separatorBuilder: (_, _) => const SizedBox(height: 8),
              itemBuilder: (context, index) {
                final file = _files[index];
                return Container(
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(
                    color: palette.surface,
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(color: palette.border),
                  ),
                  child: Row(
                    children: [
                      Icon(file.icon, color: palette.accent),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              file.displayName,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: TextStyle(
                                color: palette.textPrimary,
                                fontSize: 15,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                            const SizedBox(height: 2),
                            Text(
                              file.sizeLabel,
                              style: TextStyle(
                                color: palette.textSecondary,
                                fontSize: 12,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                );
              },
            ),
    );
  }
}

class _EmptyFilesState extends StatelessWidget {
  const _EmptyFilesState({this.errorText, required this.palette});
  final String? errorText;
  final AppPalette palette;

  @override
  Widget build(BuildContext context) {
    return Center(
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
              child: Icon(
                Icons.folder_open_outlined,
                color: palette.accent,
                size: 32,
              ),
            ),
            const SizedBox(height: 20),
            Text(
              AppLocale.t('no_files_title'),
              style: TextStyle(
                color: palette.textPrimary,
                fontSize: 18,
                fontWeight: FontWeight.w600,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 6),
            Text(
              'Los archivos que envíes en tus chats aparecerán aquí',
              style: TextStyle(color: palette.textSecondary, fontSize: 14),
              textAlign: TextAlign.center,
            ),
            if (errorText != null) ...[
              const SizedBox(height: 16),
              Text(
                errorText!,
                style: const TextStyle(color: Colors.redAccent, fontSize: 13),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
