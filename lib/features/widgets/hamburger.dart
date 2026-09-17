import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/api.dart';
import '../../core/auth_controller.dart';
import '../../core/models.dart';
import '../screens/projects_screen.dart';
import '../screens/settings_screen.dart';
import '../screens/uploaded_files.dart';

class AppDrawer extends ConsumerStatefulWidget {
  const AppDrawer({
    super.key,
    required this.email,
    required this.avatarUrl,
    required this.mode,
    required this.onSelectMode,
    required this.onSelectChat,
    required this.onNewChat,
  });

  final String email;
  final String? avatarUrl;
  final ChatMode mode;
  final ValueChanged<ChatMode> onSelectMode;
  final ValueChanged<ChatSession> onSelectChat;
  final VoidCallback onNewChat;

  @override
  ConsumerState<AppDrawer> createState() =>
      _AppDrawerState();
}

class _AppDrawerState
    extends ConsumerState<AppDrawer> {
  bool _isLoading = true;
  List<ChatSession> _chats = [];

  @override
  void initState() {
    super.initState();
    _loadChats();
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
        _chats = chats;
        _isLoading = false;
      });
    } catch (_) {
      if (!mounted) return;

      setState(() {
        _isLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final username =
        widget.email.isNotEmpty
            ? widget.email.split('@').first
            : 'Usuario';

    return Drawer(
      backgroundColor: Colors.black,
      child: SafeArea(
        child: Padding(
          padding:
              const EdgeInsets.symmetric(
            horizontal: 16,
            vertical: 12,
          ),
          child: Column(
            crossAxisAlignment:
                CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  IconButton(
                    onPressed: () {
                      Navigator.of(context).pop();

                      Navigator.of(context).push(
                        MaterialPageRoute(
                          builder: (_) =>
                              const SettingsScreen(),
                        ),
                      );
                    },
                    icon: CircleAvatar(
                      radius: 14,
                      backgroundColor:
                          const Color(0xFF232323),
                      backgroundImage:
                          widget.avatarUrl != null
                              ? NetworkImage(
                                  widget.avatarUrl!,
                                )
                              : null,
                      child:
                          widget.avatarUrl == null
                              ? const Icon(
                                  Icons.person,
                                  size: 16,
                                  color:
                                      Colors.white70,
                                )
                              : null,
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      username,
                      overflow:
                          TextOverflow.ellipsis,
                      style:
                          const TextStyle(
                        color: Colors.white,
                        fontSize: 20,
                        fontWeight:
                            FontWeight.w600,
                      ),
                    ),
                  ),
                  IconButton(
                    onPressed: () async {
                      await ref
                          .read(
                            authControllerProvider
                                .notifier,
                          )
                          .signOut();
                    },
                    icon: const Icon(
                      Icons.logout,
                      color: Colors.white,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 24),
              _DrawerItem(
                icon:
                    Icons.folder_copy_outlined,
                label: 'Proyectos',
                onTap: () {
                  Navigator.of(context).pop();

                  Navigator.of(context).push(
                    MaterialPageRoute(
                      builder: (_) =>
                          const ProjectsScreen(),
                    ),
                  );
                },
              ),
              const SizedBox(height: 18),
              _DrawerItem(
                icon:
                    Icons.description_outlined,
                label: 'Artefactos',
                onTap: () {
                  Navigator.of(context).pop();

                  Navigator.of(context).push(
                    MaterialPageRoute(
                      builder: (_) =>
                          const UploadedFilesScreen(),
                    ),
                  );
                },
              ),
              const SizedBox(height: 18),
              _DrawerItem(
                icon:
                    Icons.power_off_outlined,
                label: 'Conectores',
                onTap: () {},
              ),
              const SizedBox(height: 16),
              const Divider(
                color: Color(0xFF232323),
              ),
              const SizedBox(height: 8),
              Row(
                mainAxisAlignment:
                    MainAxisAlignment
                        .spaceBetween,
                children: [
                  const Text(
                    'Sesiones',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 18,
                    ),
                  ),
                  ModePillDropdown(
                    mode: widget.mode,
                    onSelectMode:
                        widget.onSelectMode,
                  ),
                ],
              ),
              const SizedBox(height: 16),
              Expanded(
                child:
                    _isLoading
                        ? const Center(
                            child:
                                CircularProgressIndicator(
                              color:
                                  Colors.white,
                            ),
                          )
                        : _chats.isEmpty
                            ? const Center(
                                child: Text(
                                  'Sin chats',
                                  style:
                                      TextStyle(
                                    color:
                                        Color(
                                      0xFF5C5C5C,
                                    ),
                                  ),
                                ),
                              )
                            : ListView.builder(
                                itemCount:
                                    _chats.length,
                                itemBuilder:
                                    (
                                      context,
                                      index,
                                    ) {
                                      final chat =
                                          _chats[
                                            index
                                          ];

                                      return ListTile(
                                        contentPadding:
                                            EdgeInsets
                                                .zero,
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
                                          maxLines:
                                              1,
                                          overflow:
                                              TextOverflow
                                                  .ellipsis,
                                          style:
                                              const TextStyle(
                                            color:
                                                Colors.white,
                                            fontSize:
                                                15,
                                          ),
                                        ),
                                        onTap: () {
                                          Navigator.of(
                                            context,
                                          ).pop();

                                          widget
                                              .onSelectChat(
                                            chat,
                                          );
                                        },
                                      );
                                    },
                              ),
              ),
              Align(
                alignment:
                    Alignment.centerRight,
                child: FloatingActionButton(
                  onPressed: () {
                    Navigator.of(context).pop();
                    widget.onNewChat();
                  },
                  backgroundColor:
                      const Color(0xFF6ED7FF),
                  child: const Icon(
                    Icons.add,
                    color: Colors.black,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _DrawerItem
    extends StatelessWidget {
  const _DrawerItem({
    required this.icon,
    required this.label,
    required this.onTap,
  });

  final IconData icon;
  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      borderRadius:
          BorderRadius.circular(12),
      onTap: onTap,
      child: Padding(
        padding:
            const EdgeInsets.symmetric(
          vertical: 4,
        ),
        child: Row(
          children: [
            Icon(
              icon,
              color: Colors.white,
              size: 22,
            ),
            const SizedBox(width: 16),
            Text(
              label,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 17,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class ModePillDropdown
    extends StatelessWidget {
  const ModePillDropdown({
    super.key,
    required this.mode,
    required this.onSelectMode,
  });

  final ChatMode mode;
  final ValueChanged<ChatMode> onSelectMode;

  @override
  Widget build(BuildContext context) {
    return PopupMenuButton<ChatMode>(
      color: const Color(0xFF1B1B1B),
      onSelected: onSelectMode,
      itemBuilder: (_) => const [
        PopupMenuItem(
          value: ChatMode.chat,
          child: Text(
            'Chat',
            style: TextStyle(
              color: Colors.white,
            ),
          ),
        ),
        PopupMenuItem(
          value: ChatMode.coder,
          child: Text(
            'Coder',
            style: TextStyle(
              color: Colors.white,
            ),
          ),
        ),
      ],
      child: Container(
        padding:
            const EdgeInsets.symmetric(
          horizontal: 16,
          vertical: 8,
        ),
        decoration: BoxDecoration(
          borderRadius:
              BorderRadius.circular(20),
          border: Border.all(
            color: const Color(
              0xFF313131,
            ),
          ),
        ),
        child: Row(
          mainAxisSize:
              MainAxisSize.min,
          children: [
            Text(
              mode == ChatMode.coder
                  ? 'Coder'
                  : 'Chat',
              style: const TextStyle(
                color: Colors.white,
                fontSize: 15,
              ),
            ),
            const SizedBox(width: 6),
            const Icon(
              Icons.keyboard_arrow_down,
              color: Colors.white,
              size: 18,
            ),
          ],
        ),
      ),
    );
  }
}