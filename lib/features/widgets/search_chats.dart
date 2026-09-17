import 'package:flutter/material.dart';

import '../../core/api.dart';
import '../../core/models.dart';

Future<ChatSession?> showSearchChats(
  BuildContext context,
) {
  return showModalBottomSheet<ChatSession>(
    context: context,
    backgroundColor:
        Colors.transparent,
    isScrollControlled: true,
    builder: (_) =>
        const SearchChatsSheet(),
  );
}

class SearchChatsSheet
    extends StatefulWidget {
  const SearchChatsSheet({
    super.key,
  });

  @override
  State<SearchChatsSheet> createState() =>
      _SearchChatsSheetState();
}

class _SearchChatsSheetState
    extends State<SearchChatsSheet> {
  final _queryController =
      TextEditingController();

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
      final response =
          await ApiClient.get('/chats');

      final decoded =
          ApiClient.decode(response);

      final data =
          decoded is Map<String, dynamic>
              ? decoded
              : <String, dynamic>{};

      final raw =
          data['chats'] ??
          data['items'] ??
          const [];

      final chats =
          raw is List
              ? raw
                  .whereType<Map>()
                  .map(
                    (item) =>
                        ChatSession.fromJson(
                      Map<String, dynamic>.from(
                        item,
                      ),
                    ),
                  )
                  .toList()
              : <ChatSession>[];

      if (!mounted) return;

      setState(() {
        _allChats = chats;
        _filtered = chats;
        _isLoading = false;
      });
    } catch (_) {
      if (!mounted) return;

      setState(() {
        _isLoading = false;
      });
    }
  }

  void _onQueryChanged(
    String query,
  ) {
    final normalized =
        query.trim().toLowerCase();

    setState(() {
      if (normalized.isEmpty) {
        _filtered = _allChats;
        return;
      }

      _filtered =
          _allChats
              .where(
                (chat) =>
                    chat.title
                        .toLowerCase()
                        .contains(
                          normalized,
                        ),
              )
              .toList();
    });
  }

  @override
  Widget build(
    BuildContext context,
  ) {
    return Padding(
      padding: EdgeInsets.only(
        bottom:
            MediaQuery.of(
              context,
            ).viewInsets.bottom,
      ),
      child: Container(
        constraints: BoxConstraints(
          maxHeight:
              MediaQuery.of(context)
                      .size
                      .height *
                  0.75,
        ),
        decoration:
            const BoxDecoration(
          color: Color(0xFF141414),
          borderRadius:
              BorderRadius.vertical(
            top: Radius.circular(24),
          ),
        ),
        child: Column(
          mainAxisSize:
              MainAxisSize.min,
          children: [
            const SizedBox(height: 12),
            Container(
              width: 40,
              height: 4,
              decoration:
                  BoxDecoration(
                color:
                    const Color(
                  0xFF3A3A3A,
                ),
                borderRadius:
                    BorderRadius.circular(
                  2,
                ),
              ),
            ),
            Padding(
              padding:
                  const EdgeInsets.fromLTRB(
                16,
                16,
                16,
                8,
              ),
              child: TextField(
                controller:
                    _queryController,
                autofocus: true,
                onChanged:
                    _onQueryChanged,
                style:
                    const TextStyle(
                  color: Colors.white,
                ),
                decoration:
                    InputDecoration(
                  hintText:
                      'Escribe lo que buscas',
                  hintStyle:
                      const TextStyle(
                    color:
                        Color(0xFF5C5C5C),
                  ),
                  prefixIcon:
                      const Icon(
                    Icons.search,
                    color:
                        Color(0xFF8A8A8A),
                  ),
                  filled: true,
                  fillColor:
                      const Color(
                    0xFF1E1E1E,
                  ),
                  border:
                      OutlineInputBorder(
                    borderRadius:
                        BorderRadius.circular(
                      14,
                    ),
                    borderSide:
                        BorderSide.none,
                  ),
                ),
              ),
            ),
            Flexible(
              child:
                  _isLoading
                      ? const Padding(
                          padding:
                              EdgeInsets.all(
                            24,
                          ),
                          child:
                              CircularProgressIndicator(
                            color:
                                Colors.white,
                          ),
                        )
                      : _filtered.isEmpty
                          ? const Padding(
                              padding:
                                  EdgeInsets.all(
                                24,
                              ),
                              child: Text(
                                'Sin resultados',
                                style:
                                    TextStyle(
                                  color:
                                      Color(
                                    0xFF5C5C5C,
                                  ),
                                  fontSize:
                                      15,
                                ),
                              ),
                            )
                          : ListView.builder(
                              shrinkWrap: true,
                              padding:
                                  const EdgeInsets
                                      .symmetric(
                                horizontal:
                                    12,
                                vertical: 8,
                              ),
                              itemCount:
                                  _filtered.length,
                              itemBuilder:
                                  (
                                    context,
                                    index,
                                  ) {
                                    final chat =
                                        _filtered[
                                          index
                                        ];

                                    return ListTile(
                                      leading:
                                          Icon(
                                        chat.mode ==
                                                'coder'
                                            ? Icons
                                                .code_rounded
                                            : Icons
                                                .chat_bubble_outline,
                                        color:
                                            const Color(
                                          0xFF6ED7FF,
                                        ),
                                      ),
                                      title:
                                          Text(
                                        chat.title,
                                        style:
                                            const TextStyle(
                                          color:
                                              Colors.white,
                                        ),
                                      ),
                                      onTap: () {
                                        Navigator.of(
                                          context,
                                        ).pop(
                                          chat,
                                        );
                                      },
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