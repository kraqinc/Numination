import 'package:flutter/material.dart';

import '../../core/api.dart';
import '../../core/models.dart';

/// Shows the "buscar chats" overlay as a modal bottom sheet. Call
/// [showSearchChats] from wherever the search bar/icon lives. Resolves
/// with the [ChatSession] the user tapped, or null if dismissed.
Future<ChatSession?> showSearchChats(BuildContext context) {
  return showModalBottomSheet<ChatSession>(
    context: context,
    backgroundColor: Colors.transparent,
    isScrollControlled: true,
    builder: (context) => const SearchChatsSheet(),
  );
}

class SearchChatsSheet extends StatefulWidget {
  const SearchChatsSheet({super.key});

  @override
  State<SearchChatsSheet> createState() => _SearchChatsSheetState();
}

class _SearchChatsSheetState extends State<SearchChatsSheet> {
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
          : _allChats.where((c) => c.title.toLowerCase().contains(normalized)).toList();
    });
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.only(bottom: MediaQuery.of(context).viewInsets.bottom),
      child: Container(
        constraints: BoxConstraints(maxHeight: MediaQuery.of(context).size.height * 0.75),
        decoration: const BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const SizedBox(height: 12),
            Container(
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: const Color(0xFFD8D8D8),
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
              child: TextField(
                controller: _queryController,
                autofocus: true,
                onChanged: _onQueryChanged,
                style: const TextStyle(color: Colors.black),
                decoration: InputDecoration(
                  hintText: 'Escribe lo que buscas',
                  hintStyle: const TextStyle(color: Color(0xFF8A8A8A)),
                  prefixIcon: const Icon(Icons.search, color: Color(0xFF8A8A8A)),
                  filled: true,
                  fillColor: const Color(0xFFF0F0F0),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(14),
                    borderSide: BorderSide.none,
                  ),
                ),
              ),
            ),
            Flexible(
              child: _isLoading
                  ? const Padding(
                      padding: EdgeInsets.all(24),
                      child: CircularProgressIndicator(color: Colors.black),
                    )
                  : _filtered.isEmpty
                      ? const Padding(
                          padding: EdgeInsets.all(24),
                          child: Text(
                            'Sin resultados',
                            style: TextStyle(color: Color(0xFF5C5C5C), fontSize: 15),
                          ),
                        )
                      : ListView.builder(
                          shrinkWrap: true,
                          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                          itemCount: _filtered.length,
                          itemBuilder: (context, index) {
                            final chat = _filtered[index];
                            return ListTile(
                              leading: Icon(
                                chat.mode == 'coder' ? Icons.code_rounded : Icons.chat_bubble_outline,
                                color: const Color(0xFF1E88C7),
                              ),
                              title: Text(chat.title, style: const TextStyle(color: Colors.black)),
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