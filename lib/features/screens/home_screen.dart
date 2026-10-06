import 'dart:io';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:speech_to_text/speech_to_text.dart' as stt;
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../core/ai_modes_controller.dart';
import '../../core/api.dart';
import '../../core/update_service.dart';
import '../../core/auth_controller.dart';
import '../../core/l10n_extensions.dart';
import '../../core/models.dart';
import '../../core/theme_controller.dart';
import '../widgets/ai_response.dart';
import '../widgets/hamburger.dart';
import '../widgets/search_chats.dart';
import 'ghost_chat.dart';
import 'coder_screen.dart';

class ChatMessage {
  final String text;
  final bool fromUser;

  const ChatMessage({required this.text, required this.fromUser});
}

class HomeScreen extends ConsumerStatefulWidget {
  const HomeScreen({super.key});

  @override
  ConsumerState<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends ConsumerState<HomeScreen> with WidgetsBindingObserver {
  final _messageController = TextEditingController();
  final _scrollController = ScrollController();
  final GlobalKey<ScaffoldState> _scaffoldKey = GlobalKey<ScaffoldState>();
  final stt.SpeechToText _speech = stt.SpeechToText();

  String _modeId = 'chat';
  bool _isSending = false;
  bool _isListening = false;
  bool _speechAvailable = false;
  bool _isAttaching = false;

  String? _activeChatId;

  final List<ChatMessage> _messages = [];

  AppUser? _profile;
  int _chatRevision = 0;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _initSpeech();
    _loadProfile();

    WidgetsBinding.instance.addPostFrameCallback((_) {
      UpdateService.checkAndInstallIfEnabled();
    });
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      UpdateService.resumeAfterInstallPermission();
    }
  }

  Future<void> _initSpeech() async {
    _speechAvailable = await _speech.initialize(
      onStatus: (status) {
        if (status == 'done' || status == 'notListening') {
          if (mounted) {
            setState(() => _isListening = false);
          }
        }
      },
      onError: (error) {
        if (mounted) {
          setState(() => _isListening = false);
        }
      },
    );

    if (mounted) {
      setState(() {});
    }
  }

  Future<void> _loadProfile() async {
    try {
      final response = await ApiClient.get('/auth/me');
      final data = ApiClient.decode(response) as Map<String, dynamic>;

      if (!mounted) return;

      setState(
        () => _profile = AppUser.fromJson(data['user'] as Map<String, dynamic>),
      );
    } catch (_) {
      // El perfil es opcional para cargar la pantalla.
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _messageController.dispose();
    _scrollController.dispose();
    _speech.stop();
    super.dispose();
  }

  void _toggleMode(String modeId) {
    if (modeId == _modeId) return;

    if (modeId == 'coder') {
      if (_scaffoldKey.currentState?.isDrawerOpen == true) {
        Navigator.of(context).pop();
      }

      Navigator.of(
        context,
      ).push(MaterialPageRoute(builder: (_) => const CoderScreen()));

      return;
    }

    setState(() => _modeId = modeId);
  }

  void _startNewChat() {
    setState(() {
      _activeChatId = null;
      _messages.clear();
    });
  }

  void _onChatDeleted(ChatSession chat) {
    if (_activeChatId != chat.id) return;

    setState(() {
      _activeChatId = null;
      _messages.clear();
    });
  }

  Future<void> _openChat(ChatSession chat) async {
    setState(() {
      _activeChatId = chat.id;
      _modeId = chat.mode;
      _messages.clear();
    });

    try {
      final encodedChatId = Uri.encodeComponent(chat.id);
      final response = await ApiClient.get('/chats/$encodedChatId/messages');

      final data = ApiClient.decode(response) as Map<String, dynamic>;

      final list = (data['messages'] as List? ?? [])
          .map(
            (e) => ChatMessageDto.fromJson(Map<String, dynamic>.from(e as Map)),
          )
          .toList();

      if (!mounted) return;

      setState(() {
        _messages.addAll(
          list.map(
            (m) => ChatMessage(text: m.content, fromUser: m.role == 'user'),
          ),
        );
      });

      _scrollToBottom();
    } catch (_) {
      if (!mounted) return;

      setState(() {
        _messages.add(
          const ChatMessage(
            text: 'No se pudo cargar este chat.',
            fromUser: false,
          ),
        );
      });
    }
  }

  Future<void> _openSearch() async {
    final selected = await showSearchChats(context);

    if (selected != null) {
      await _openChat(selected);
    }
  }

  void _openGhostChat() {
    Navigator.of(
      context,
    ).push(MaterialPageRoute(builder: (_) => const GhostChatScreen()));
  }

  Future<void> _toggleListening() async {
    if (!_speechAvailable) {
      await _initSpeech();

      if (!_speechAvailable) {
        return;
      }
    }

    if (_isListening) {
      await _speech.stop();

      if (mounted) {
        setState(() => _isListening = false);
      }

      return;
    }

    setState(() => _isListening = true);

    await _speech.listen(
      listenOptions: stt.SpeechListenOptions(localeId: 'es_ES'),
      onResult: (result) {
        if (!mounted) return;

        setState(() {
          _messageController.text = result.recognizedWords;
          _messageController.selection = TextSelection.fromPosition(
            TextPosition(offset: _messageController.text.length),
          );
        });

        if (result.finalResult && _messageController.text.trim().isNotEmpty) {
          _sendMessage();
        }
      },
    );
  }

  Future<void> _attachFile() async {
    if (_isAttaching) return;

    final picked = await FilePicker.pickFile();

    if (picked == null || picked.path == null) {
      return;
    }

    setState(() => _isAttaching = true);

    try {
      final client = Supabase.instance.client;
      final userId = client.auth.currentUser?.id;

      if (userId == null) {
        throw Exception('Sesión no encontrada');
      }

      final file = File(picked.path!);
      final sizeBytes = await file.length();

      const maxFileBytes = 20 * 1024 * 1024;

      if (sizeBytes <= 0) {
        throw Exception('Archivo vacío');
      }

      if (sizeBytes > maxFileBytes) {
        throw Exception('Archivo demasiado grande');
      }

      final originalName = picked.name.trim();

      final safeName = originalName
          .replaceAll(RegExp(r'[^A-Za-z0-9._-]'), '_')
          .replaceAll(RegExp(r'_+'), '_');

      if (safeName.isEmpty ||
          safeName == '.' ||
          safeName == '..' ||
          safeName.contains('..')) {
        throw Exception('Nombre de archivo inválido');
      }

      final storagePath =
          '$userId/${DateTime.now().microsecondsSinceEpoch}_$safeName';

      await client.storage.from('artifacts').upload(storagePath, file);

      final extension = picked.extension?.toLowerCase() ?? '';

      await ApiClient.post('/artifacts', {
        'title': safeName,
        'kind': 'file',
        'storagePath': storagePath,
        'mimeType': extension,
        'sizeBytes': sizeBytes,
        'chatId': _activeChatId,
      });

      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('"${picked.name}" se guardó en Artefactos')),
      );
    } catch (_) {
      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('No se pudo adjuntar el archivo. Inténtalo de nuevo.'),
        ),
      );
    } finally {
      if (mounted) {
        setState(() => _isAttaching = false);
      }
    }
  }

  Future<void> _sendMessage() async {
    final text = _messageController.text.trim();

    if (text.isEmpty || _isSending) return;

    setState(() {
      _messages.add(ChatMessage(text: text, fromUser: true));

      _isSending = true;
      _messageController.clear();
    });

    _scrollToBottom();

    try {
      var chatId = _activeChatId;

      if (chatId == null) {
        final createRes = await ApiClient.post('/chats', {
          'title': text.length > 40 ? '${text.substring(0, 40)}...' : text,
          'mode': _modeId,
        });

        final createData = ApiClient.decode(createRes) as Map<String, dynamic>;

        chatId = (createData['chat'] as Map<String, dynamic>)['id'] as String;

        if (mounted) {
          setState(() {
            _activeChatId = chatId;
            _chatRevision++;
          });
        }
      }

      final response = await ApiClient.post('/ai/chat', {
        'prompt': text,
        'mode': _modeId,
        'chatId': chatId,
      });

      final data = ApiClient.decode(response) as Map<String, dynamic>;
      final chatResponse = ChatResponse.fromJson(data);

      if (!mounted) return;

      setState(() {
        _messages.add(
          ChatMessage(text: chatResponse.response, fromUser: false),
        );

        if (chatResponse.chatTitle != null &&
            chatResponse.chatTitle!.trim().isNotEmpty) {
          _chatRevision++;
        }
      });
    } on ApiException catch (e) {
      if (!mounted) return;

      setState(() {
        _messages.add(
          ChatMessage(text: 'Error: ${e.message}', fromUser: false),
        );
      });
    } catch (_) {
      if (!mounted) return;

      setState(() {
        _messages.add(
          const ChatMessage(
            text: 'No se pudo contactar al servidor. Intenta de nuevo.',
            fromUser: false,
          ),
        );
      });
    } finally {
      if (mounted) {
        setState(() => _isSending = false);
      }

      _scrollToBottom();
    }
  }

  void _scrollToBottom() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!_scrollController.hasClients) return;

      _scrollController.animateTo(
        _scrollController.position.maxScrollExtent,
        duration: const Duration(milliseconds: 250),
        curve: Curves.easeOut,
      );
    });
  }

  @override
  Widget build(BuildContext context) {
    final auth = ref.watch(authControllerProvider);
    final palette = ref.watch(appPaletteProvider);
    final email = auth is AuthAuthenticated ? auth.email : '';
    final availableModes =
        ref.watch(aiModesControllerProvider).value ?? const <AiModeConfig>[];

    ref.listen(aiModesControllerProvider, (previous, next) {
      final list = next.value;

      if (list != null &&
          list.isNotEmpty &&
          !list.any((m) => m.id == _modeId)) {
        setState(() => _modeId = list.first.id);
      }
    });

    return Scaffold(
      key: _scaffoldKey,
      backgroundColor: palette.background,
      drawer: AppDrawer(
        email: email,
        avatarUrl: _profile?.avatarUrl,
        chatRevision: _chatRevision,
        modeId: _modeId,
        availableModes: availableModes,
        onSelectMode: _toggleMode,
        onSelectChat: _openChat,
        onNewChat: _startNewChat,
        onChatDeleted: _onChatDeleted,
      ),
      body: SafeArea(
        child: Column(
          children: [
            _TopBar(
              onMenuTap: () => _scaffoldKey.currentState?.openDrawer(),
              onSearchTap: _openSearch,
              onGhostTap: _openGhostChat,
            ),
            Expanded(
              child: _messages.isEmpty
                  ? const _EmptyState()
                  : ListView.builder(
                      controller: _scrollController,
                      padding: const EdgeInsets.symmetric(
                        horizontal: 16,
                        vertical: 12,
                      ),
                      itemCount: _messages.length,
                      itemBuilder: (context, index) {
                        final msg = _messages[index];

                        return _MessageBubble(message: msg);
                      },
                    ),
            ),
            _BottomInputBar(
              controller: _messageController,
              modeId: _modeId,
              availableModes: availableModes,
              isSending: _isSending,
              isListening: _isListening,
              isAttaching: _isAttaching,
              onModeChange: _toggleMode,
              onSend: _sendMessage,
              onMicTap: _toggleListening,
              onAttachTap: _attachFile,
            ),
          ],
        ),
      ),
    );
  }
}

class _TopBar extends ConsumerWidget {
  const _TopBar({
    required this.onMenuTap,
    required this.onSearchTap,
    required this.onGhostTap,
  });

  final VoidCallback onMenuTap;
  final VoidCallback onSearchTap;
  final VoidCallback onGhostTap;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final palette = ref.watch(appPaletteProvider);

    return Padding(
      padding: const EdgeInsets.fromLTRB(12, 10, 12, 10),
      child: Row(
        children: [
          GestureDetector(
            onTap: onMenuTap,
            behavior: HitTestBehavior.opaque,
            child: Padding(
              padding: const EdgeInsets.all(8),
              child: Icon(
                Icons.menu_rounded,
                color: palette.textPrimary.withValues(alpha: 0.85),
                size: 26,
              ),
            ),
          ),
          const SizedBox(width: 4),
          Expanded(
            child: GestureDetector(
              onTap: onSearchTap,
              child: Container(
                height: 42,
                padding: const EdgeInsets.symmetric(horizontal: 14),
                decoration: BoxDecoration(
                  color: palette.surface,
                  borderRadius: BorderRadius.circular(24),
                  border: Border.all(
                    color: palette.border.withValues(alpha: 0.7),
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.04),
                      blurRadius: 8,
                      offset: const Offset(0, 2),
                    ),
                  ],
                ),
                child: Row(
                  children: [
                    Icon(
                      Icons.search_rounded,
                      color: palette.textSecondary,
                      size: 20,
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        context.l10n.searchChats,
                        style: TextStyle(
                          color: palette.textSecondary,
                          fontSize: 15,
                          fontWeight: FontWeight.w400,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
          const SizedBox(width: 4),
          GestureDetector(
            onTap: onGhostTap,
            behavior: HitTestBehavior.opaque,
            child: Padding(
              padding: const EdgeInsets.all(8),
              child: Image.asset(
                'assets/images/ghost.png',
                width: 24,
                height: 24,
                color: palette.textPrimary.withValues(alpha: 0.8),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _EmptyState extends ConsumerWidget {
  const _EmptyState();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final palette = ref.watch(appPaletteProvider);

    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 28, vertical: 20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 70,
              height: 70,
              decoration: BoxDecoration(
                color: palette.surface,
                borderRadius: BorderRadius.circular(22),
                border: Border.all(color: palette.border),
              ),
              child: Icon(
                Icons.auto_awesome_rounded,
                color: palette.accent,
                size: 34,
              ),
            ),
            const SizedBox(height: 20),
            Text(
              '¿Qué vamos a resolver hoy?',
              textAlign: TextAlign.center,
              style: TextStyle(
                color: palette.textPrimary,
                fontSize: 21,
                fontWeight: FontWeight.w700,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'Escribe una pregunta o empieza con una idea.',
              textAlign: TextAlign.center,
              style: TextStyle(
                color: palette.textSecondary,
                fontSize: 14,
                height: 1.4,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _MessageBubble extends ConsumerWidget {
  const _MessageBubble({required this.message});

  final ChatMessage message;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final palette = ref.watch(appPaletteProvider);
    final isUser = message.fromUser;

    final bubbleColor = isUser
        ? palette.accent.withValues(alpha: 0.14)
        : palette.surface;

    return Align(
      alignment: isUser ? Alignment.centerRight : Alignment.centerLeft,
      child: Container(
        margin: const EdgeInsets.symmetric(vertical: 5),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        constraints: BoxConstraints(
          maxWidth: MediaQuery.of(context).size.width * 0.78,
        ),
        decoration: BoxDecoration(
          color: bubbleColor,
          borderRadius: BorderRadius.circular(18),
          border: Border.all(
            color: isUser
                ? palette.accent.withValues(alpha: 0.25)
                : palette.border.withValues(alpha: 0.6),
          ),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.03),
              blurRadius: 6,
              offset: const Offset(0, 1),
            ),
          ],
        ),
        child: AiResponse(text: message.text),
      ),
    );
  }
}

class _BottomInputBar extends ConsumerWidget {
  const _BottomInputBar({
    required this.controller,
    required this.modeId,
    required this.availableModes,
    required this.isSending,
    required this.isListening,
    required this.isAttaching,
    required this.onModeChange,
    required this.onSend,
    required this.onMicTap,
    required this.onAttachTap,
  });

  final TextEditingController controller;
  final String modeId;
  final List<AiModeConfig> availableModes;
  final bool isSending;
  final bool isListening;
  final bool isAttaching;
  final ValueChanged<String> onModeChange;
  final VoidCallback onSend;
  final VoidCallback onMicTap;
  final VoidCallback onAttachTap;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final palette = ref.watch(appPaletteProvider);

    return Padding(
      padding: const EdgeInsets.fromLTRB(12, 6, 12, 14),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (availableModes.length > 1)
            Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                child: Row(
                  children: availableModes
                      .map(
                        (m) => Padding(
                          padding: const EdgeInsets.only(right: 6),
                          child: _ModeChip(
                            label: m.label,
                            selected: modeId == m.id,
                            onTap: () => onModeChange(m.id),
                          ),
                        ),
                      )
                      .toList(),
                ),
              ),
            ),
          Container(
            constraints: const BoxConstraints(minHeight: 52, maxHeight: 180),
            decoration: BoxDecoration(
              color: palette.surface,
              borderRadius: BorderRadius.circular(28),
              border: Border.all(color: palette.border.withValues(alpha: 0.65)),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.05),
                  blurRadius: 12,
                  offset: const Offset(0, 3),
                ),
              ],
            ),
            child: Row(
              children: [
                Padding(
                  padding: const EdgeInsets.only(left: 6),
                  child: Material(
                    color: Colors.transparent,
                    child: InkWell(
                      onTap: isAttaching ? null : onAttachTap,
                      onLongPress: onMicTap,
                      borderRadius: BorderRadius.circular(22),
                      child: Container(
                        width: 40,
                        height: 40,
                        decoration: BoxDecoration(
                          color: palette.textPrimary.withValues(alpha: 0.08),
                          shape: BoxShape.circle,
                        ),
                        child: isAttaching
                            ? Padding(
                                padding: const EdgeInsets.all(10),
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                  color: palette.textSecondary,
                                ),
                              )
                            : Icon(
                                isListening
                                    ? Icons.mic_rounded
                                    : Icons.add_rounded,
                                color: isListening
                                    ? palette.accent
                                    : palette.textPrimary.withValues(
                                        alpha: 0.85,
                                      ),
                                size: 22,
                              ),
                      ),
                    ),
                  ),
                ),
                Expanded(
                  child: TextField(
                    controller: controller,
                    minLines: 1,
                    maxLines: 6,
                    keyboardType: TextInputType.multiline,
                    textInputAction: TextInputAction.newline,
                    cursorColor: palette.accent,
                    cursorWidth: 2,
                    cursorRadius: const Radius.circular(2),
                    style: TextStyle(
                      color: palette.textPrimary,
                      fontSize: 15,
                      height: 1.45,
                      fontWeight: FontWeight.w400,
                    ),
                    decoration: InputDecoration(
                      hintText: context.l10n.askSomething,
                      hintStyle: TextStyle(
                        color: palette.textSecondary.withValues(alpha: 0.72),
                        fontSize: 15,
                        height: 1.45,
                      ),
                      filled: false,
                      fillColor: Colors.transparent,
                      hoverColor: Colors.transparent,
                      focusColor: Colors.transparent,
                      border: InputBorder.none,
                      enabledBorder: InputBorder.none,
                      focusedBorder: InputBorder.none,
                      disabledBorder: InputBorder.none,
                      errorBorder: InputBorder.none,
                      focusedErrorBorder: InputBorder.none,
                      isCollapsed: true,
                      contentPadding: const EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 10,
                      ),
                    ),
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.only(right: 6),
                  child: Material(
                    color: Colors.transparent,
                    child: InkWell(
                      onTap: isSending ? null : onSend,
                      borderRadius: BorderRadius.circular(22),
                      child: SizedBox(
                        width: 40,
                        height: 40,
                        child: isSending
                            ? Padding(
                                padding: const EdgeInsets.all(10),
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                  color: palette.textPrimary,
                                ),
                              )
                            : Icon(
                                Icons.send_rounded,
                                color: palette.textPrimary.withValues(
                                  alpha: 0.75,
                                ),
                                size: 22,
                              ),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _ModeChip extends ConsumerWidget {
  const _ModeChip({
    required this.label,
    required this.selected,
    required this.onTap,
  });

  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final palette = ref.watch(appPaletteProvider);

    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 7),
        decoration: BoxDecoration(
          color: selected
              ? palette.surfaceAlt
              : palette.surface.withValues(alpha: 0.6),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: selected
                ? palette.border
                : palette.border.withValues(alpha: 0.4),
          ),
        ),
        child: Text(
          label,
          style: TextStyle(
            color: selected ? palette.textPrimary : palette.textSecondary,
            fontSize: 13,
            fontWeight: FontWeight.w600,
          ),
        ),
      ),
    );
  }
}
