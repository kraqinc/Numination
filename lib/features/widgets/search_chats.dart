import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/api.dart';
import '../../core/i18n.dart';
import '../../core/models.dart';
import '../../core/theme_controller.dart';

Future<ChatSession?> showSearchChats(BuildContext context) {
  return showModalBottomSheet<ChatSession>(
    context: context,
    backgroundColor: Colors.transparent,
    isScrollControlled: true,
    builder: (context) => const SearchChatsSheet(),
  );
}

class SearchChatsSheet extends ConsumerStatefulWidget {
  const SearchChatsSheet({super.key});

  @override
  ConsumerState<SearchChatsSheet> createState() => _SearchChatsSheetState();
}

class _SearchChatsSheetState extends ConsumerState<SearchChatsSheet> {
  final _queryController = TextEditingController();
  List<ChatSession> _allChats = [];
  List<ChatSession> _filtered = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadChats();
  }

  @override
  void dispose() {
    _queryController.dispose();
    super.dispose();
  }

  Future<void> _loadChats() async {
    try {
      final response = await ApiClient.get('/chats');
      final data = ApiClient.decode(response) as Map<String, dynamic>;
      final list = (data['chats'] as List? ?? [])
          .map((e) => ChatSession.fromJson(Map<String, dynamic>.from(e as Map)))
          .toList();
      setState(() {
        _allChats = list;
        _filtered = list;
        _isLoading = false;
      });
    } catch (e) {
      setState(() => _isLoading = false);
    }
  }

  void _onQueryChanged(String query) {
    final normalized = query.trim().toLowerCase();
    setState(() {
      _filtered = normalized.isEmpty
          ? _allChats
          : _allChats
                .where((c) => c.title.toLowerCase().contains(normalized))
                .toList();
    });
  }

  @override
  Widget build(BuildContext context) {
    final palette = ref.watch(appPaletteProvider);

    return Padding(
      padding: EdgeInsets.only(
        bottom: MediaQuery.of(context).viewInsets.bottom,
      ),
      child: Container(
        constraints: BoxConstraints(
          maxHeight: MediaQuery.of(context).size.height * 0.75,
        ),
        decoration: BoxDecoration(
          color: palette.surface,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const SizedBox(height: 12),
            Container(
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: palette.border,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
              child: TextField(
                controller: _queryController,
                autofocus: true,
                onChanged: _onQueryChanged,
                style: TextStyle(color: palette.textPrimary),
                cursorColor: palette.accent,
                decoration: InputDecoration(
                  hintText: AppLocale.t('search_hint'),
                  hintStyle: TextStyle(color: palette.textSecondary),
                  prefixIcon: Icon(Icons.search, color: palette.textSecondary),
                  filled: true,
                  fillColor: palette.surfaceAlt,
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(14),
                    borderSide: BorderSide.none,
                  ),
                ),
              ),
            ),
            Flexible(
              child: _isLoading
                  ? Padding(
                      padding: const EdgeInsets.all(24),
                      child: CircularProgressIndicator(
                        color: palette.textPrimary,
                      ),
                    )
                  : _filtered.isEmpty
                  ? Padding(
                      padding: const EdgeInsets.all(24),
                      child: Text(
                        AppLocale.t('no_results'),
                        style: TextStyle(
                          color: palette.textSecondary,
                          fontSize: 15,
                        ),
                      ),
                    )
                  : ListView.builder(
                      shrinkWrap: true,
                      padding: const EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 8,
                      ),
                      itemCount: _filtered.length,
                      itemBuilder: (context, index) {
                        final chat = _filtered[index];
                        return ListTile(
                          leading: Icon(
                            chat.mode == 'coder'
                                ? Icons.code_rounded
                                : Icons.chat_bubble_outline,
                            color: palette.accent,
                          ),
                          title: Text(
                            chat.title,
                            style: TextStyle(color: palette.textPrimary),
                          ),
                          onTap: () => Navigator.of(context).pop(chat),
                        );
                      },
                    ),
            ),
            const SizedBox(height: 12),
          ],
        ),
      ),
    );
  }
}
