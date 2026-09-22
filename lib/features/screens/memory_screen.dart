import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/api.dart';
import '../../core/l10n_extensions.dart';
import '../../core/models.dart';
import '../../core/theme.dart';
import '../../core/theme_controller.dart';

class MemoryScreen extends ConsumerStatefulWidget {
  const MemoryScreen({super.key});

  @override
  ConsumerState<MemoryScreen> createState() => _MemoryScreenState();
}

class _MemoryScreenState extends ConsumerState<MemoryScreen> {
  bool _isLoading = true;
  List<MemoryItem> _memories = [];

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() => _isLoading = true);
    try {
      final response = await ApiClient.get('/memory');
      final data = ApiClient.decode(response) as Map<String, dynamic>;
      final list = (data['memories'] as List? ?? [])
          .map((e) => MemoryItem.fromJson(Map<String, dynamic>.from(e as Map)))
          .toList();
      setState(() {
        _memories = list;
        _isLoading = false;
      });
    } catch (e) {
      setState(() => _isLoading = false);
    }
  }

  Future<void> _createMemory() async {
    final palette = ref.read(appPaletteProvider);
    final titleController = TextEditingController();
    final contentController = TextEditingController();

    final saved = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        backgroundColor: palette.surface,
        title: Text(
          context.l10n.create,
          style: TextStyle(color: palette.textPrimary),
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: titleController,
              autofocus: true,
              style: TextStyle(color: palette.textPrimary),
              decoration: InputDecoration(
                hintText: context.l10n.name,
                hintStyle: TextStyle(color: palette.textSecondary),
              ),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: contentController,
              maxLines: 4,
              style: TextStyle(color: palette.textPrimary),
              decoration: InputDecoration(
                hintText: 'Qué quieres que Numination recuerde',
                hintStyle: TextStyle(color: palette.textSecondary),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(false),
            child: Text(
              context.l10n.cancel,
              style: TextStyle(color: palette.textSecondary),
            ),
          ),
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(true),
            child: Text(
              context.l10n.save,
              style: TextStyle(color: palette.accent),
            ),
          ),
        ],
      ),
    );

    if (saved != true) return;
    final title = titleController.text.trim();
    final content = contentController.text.trim();
    if (title.isEmpty || content.isEmpty) return;

    try {
      await ApiClient.post('/memory', {
        'title': title,
        'content': content,
        'type': 'PROJECT',
      });
      _load();
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('No se pudo guardar la memoria')),
      );
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
          context.l10n.memory,
          style: TextStyle(color: palette.textPrimary),
        ),
      ),
      floatingActionButton: FloatingActionButton(
        backgroundColor: palette.accent,
        onPressed: _createMemory,
        child: const Icon(Icons.add),
      ),
      body: RefreshIndicator(
        onRefresh: _load,
        child: _isLoading
            ? Center(
                child: CircularProgressIndicator(color: palette.textPrimary),
              )
            : _memories.isEmpty
            ? _EmptyMemoryState(palette: palette)
            : ListView.separated(
                padding: const EdgeInsets.all(16),
                itemCount: _memories.length,
                separatorBuilder: (_, _) => const SizedBox(height: 10),
                itemBuilder: (context, index) {
                  final memory = _memories[index];
                  return Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: palette.surface,
                      borderRadius: BorderRadius.circular(14),
                      border: Border.all(color: palette.border),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            if (memory.pinned) ...[
                              Icon(
                                Icons.push_pin,
                                size: 14,
                                color: palette.accent,
                              ),
                              const SizedBox(width: 6),
                            ],
                            Expanded(
                              child: Text(
                                memory.title,
                                style: TextStyle(
                                  color: palette.textPrimary,
                                  fontSize: 15,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 6),
                        Text(
                          memory.content,
                          style: TextStyle(
                            color: palette.textSecondary,
                            fontSize: 13,
                            height: 1.4,
                          ),
                        ),
                      ],
                    ),
                  );
                },
              ),
      ),
    );
  }
}

class _EmptyMemoryState extends StatelessWidget {
  const _EmptyMemoryState({required this.palette});
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
                  Icon(Icons.memory_outlined, color: palette.accent, size: 48),
                  const SizedBox(height: 16),
                  Text(
                    'Numination todavía no ha guardado memorias sobre ti.',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      color: palette.textPrimary,
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Toca "+" para guardar algo manualmente, o sigue conversando: lo relevante se guardará solo.',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      color: palette.textSecondary,
                      fontSize: 13,
                      height: 1.4,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
