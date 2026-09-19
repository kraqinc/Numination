import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:speech_to_text/speech_to_text.dart' as stt;

import '../../core/api.dart';
import '../../core/auth_controller.dart';
import '../../core/models.dart';
import '../../core/theme.dart';
import '../widgets/hamburger.dart';
import '../widgets/search_chats.dart';
import 'ghost_chat.dart';

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

class _HomeScreenState extends ConsumerState<HomeScreen> {
  final _messageController = TextEditingController();
  final _scrollController = ScrollController();
  final GlobalKey<ScaffoldState> _scaffoldKey = GlobalKey<ScaffoldState>();
  final stt.SpeechToText _speech = stt.SpeechToText();

  ChatMode _mode = ChatMode.chat;
  bool _isSending = false;
  bool _isListening = false;
  bool _speechAvailable = false;
  String? _activeChatId;
  final List<ChatMessage> _messages = [];

  AppUser? _profile;

  @override
  void initState() {
    super.initState();
    _initSpeech();
    _loadProfile();
  }

  Future<void> _initSpeech() async {
    _speechAvailable = await _speech.initialize(
      onStatus: (status) {
        if (status == 'done' || status == 'notListening') {
          if (mounted) setState(() => _isListening = false);
        }
      },
      onError: (error) {
        if (mounted) setState(() => _isListening = false);
      },
    );

    if (mounted) setState(() {});
  }

  Future<void> _loadProfile() async {
    try {
      final response = await ApiClient.get('/auth/me');
      final data = ApiClient.decode(response) as Map<String, dynamic>;
      setState(() {
        _profile = AppUser.fromJson(
          data['user'] as Map<String, dynamic>,
        );
      });
    } catch (e) {
      // Silencioso: el drawer y el avatar muestran el estado por defecto.
    }
  }

  @override
  void dispose() {
    _messageController.dispose();
    _scrollController.dispose();
    _speech.stop();
    super.dispose();
  }

  void _toggleMode(ChatMode mode) {
    if (mode == _mode) return;

    if (mode == ChatMode.coder) {
      _showCoderPaywall();
      return;
    }

    setState(() => _mode = mode);
  }

  void _showCoderPaywall() {
    showDialog(
      context: context,
      barrierDismissible: true,
      builder: (dialogContext) => _CoderPaywallDialog(
        onClose: () => Navigator.of(dialogContext).pop(),
      ),
    );
  }

  void _startNewChat() {
    setState(() {
      _activeChatId = null;
      _messages.clear();
    });
  }

  Future<void> _openChat(ChatSession chat) async {
    setState(() {
      _activeChatId = chat.id;
      _mode = chat.mode == 'coder' ? ChatMode.coder : ChatMode.chat;
      _messages.clear();
    });

    try {
      final response = await ApiClient.get(
        '/chats/${chat.id}/messages',
      );

      final data = ApiClient.decode(response) as Map<String, dynamic>;

      final list = (data['messages'] as List? ?? [])
          .map(
            (e) => ChatMessageDto.fromJson(
              Map<String, dynamic>.from(e as Map),
            ),
          )
          .toList();

      setState(() {
        _messages.addAll(
          list.map(
            (m) => ChatMessage(
              text: m.content,
              fromUser: m.role == 'user',
            ),
          ),
        );
      });

      _scrollToBottom();
    } catch (e) {
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
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => const GhostChatScreen(),
      ),
    );
  }

  Future<void> _toggleListening() async {
    if (!_speechAvailable) {
      await _initSpeech();

      if (!_speechAvailable) return;
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
      listenOptions: stt.SpeechListenOptions(
        localeId: 'es_ES',
      ),
      onResult: (result) {
        if (!mounted) return;

        setState(() {
          _messageController.text = result.recognizedWords;
          _messageController.selection = TextSelection.fromPosition(
            TextPosition(
              offset: _messageController.text.length,
            ),
          );
        });

        if (result.finalResult &&
            _messageController.text.trim().isNotEmpty) {
          _sendMessage();
        }
      },
    );
  }

  void _attachFile() {
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Adjuntar archivos: próximamente'),
      ),
    );
  }

  Future<void> _sendMessage() async {
    final text = _messageController.text.trim();

    if (text.isEmpty || _isSending) return;

    setState(() {
      _messages.add(
        ChatMessage(
          text: text,
          fromUser: true,
        ),
      );
      _isSending = true;
      _messageController.clear();
    });

    _scrollToBottom();

    try {
      var chatId = _activeChatId;

      if (chatId == null) {
        final createRes = await ApiClient.post(
          '/chats',
          {
            'title': text.length > 40
                ? '${text.substring(0, 40)}...'
                : text,
            'mode': _mode == ChatMode.coder ? 'coder' : 'chat',
          },
        );

        final createData =
            ApiClient.decode(createRes) as Map<String, dynamic>;

        chatId = (createData['chat'] as Map<String, dynamic>)['id'] as String;

        setState(() => _activeChatId = chatId);
      }

      final response = await ApiClient.post(
        '/ai/chat',
        {
          'prompt': text,
          'mode': _mode == ChatMode.coder ? 'coder' : 'chat',
          'chatId': chatId,
        },
      );

      final data = ApiClient.decode(response) as Map<String, dynamic>;
      final chatResponse = ChatResponse.fromJson(data);

      setState(() {
        _messages.add(
          ChatMessage(
            text: chatResponse.response,
            fromUser: false,
          ),
        );
      });
    } on ApiException catch (e) {
      setState(() {
        _messages.add(
          ChatMessage(
            text: 'Error: ${e.message}',
            fromUser: false,
          ),
        );
      });
    } catch (e) {
      setState(() {
        _messages.add(
          const ChatMessage(
            text:
                'No se pudo contactar al servidor. Intenta de nuevo.',
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
    final email = auth is AuthAuthenticated ? auth.email : '';

    return Scaffold(
      key: _scaffoldKey,
      backgroundColor: AppColors.screenBackground,
      drawer: AppDrawer(
        email: email,
        avatarUrl: _profile?.avatarUrl,
        mode: _mode,
        onSelectMode: _toggleMode,
        onSelectChat: _openChat,
        onNewChat: _startNewChat,
      ),
      body: SafeArea(
        child: Column(
          children: [
            _TopBar(
              onMenuTap: () =>
                  _scaffoldKey.currentState?.openDrawer(),
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
              mode: _mode,
              isSending: _isSending,
              isListening: _isListening,
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

class _TopBar extends StatelessWidget {
  const _TopBar({
    required this.onMenuTap,
    required this.onSearchTap,
    required this.onGhostTap,
  });

  final VoidCallback onMenuTap;
  final VoidCallback onSearchTap;
  final VoidCallback onGhostTap;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
      child: Row(
        children: [
          IconButton(
            onPressed: onMenuTap,
            icon: const Icon(
              Icons.menu,
              color: Colors.black,
            ),
          ),
          Expanded(
            child: GestureDetector(
              onTap: onSearchTap,
              child: Container(
                height: 44,
                padding: const EdgeInsets.symmetric(horizontal: 14),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(22),
                ),
                child: Row(
                  children: [
                    const Icon(
                      Icons.search,
                      color: Color(0xFF8A8A8A),
                      size: 20,
                    ),
                    const SizedBox(width: 8),
                    const Expanded(
                      child: Text(
                        'Buscar chats',
                        style: TextStyle(
                          color: Color(0xFF8A8A8A),
                          fontSize: 15,
                        ),
                      ),
                    ),
                    const Icon(
                      Icons.grid_view_rounded,
                      color: Color(0xFF8A8A8A),
                      size: 20,
                    ),
                  ],
                ),
              ),
            ),
          ),
          const SizedBox(width: 8),
          IconButton(
            onPressed: onGhostTap,
            icon: Image.asset(
              'assets/images/ghost.png',
              width: 22,
              height: 22,
              color: Colors.black,
            ),
          ),
        ],
      ),
    );
  }
}

class _EmptyState extends StatelessWidget {
  const _EmptyState();

  @override
  Widget build(BuildContext context) {
    return const Center(
      child: Text(
        '¿En qué trabajamos hoy?',
        style: TextStyle(
          color: Color(0xFF8A8A8A),
          fontSize: 16,
        ),
      ),
    );
  }
}

class _MessageBubble extends StatelessWidget {
  const _MessageBubble({
    required this.message,
  });

  final ChatMessage message;

  @override
  Widget build(BuildContext context) {
    final isUser = message.fromUser;

    return Align(
      alignment:
          isUser ? Alignment.centerRight : Alignment.centerLeft,
      child: Container(
        margin: const EdgeInsets.symmetric(vertical: 6),
        padding: const EdgeInsets.symmetric(
          horizontal: 16,
          vertical: 12,
        ),
        constraints: BoxConstraints(
          maxWidth: MediaQuery.of(context).size.width * 0.78,
        ),
        decoration: BoxDecoration(
          color: isUser
              ? const Color(0xFF1B1B1B)
              : Colors.white,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: const Color(0xFFD8D8D8),
          ),
        ),
        child: Text(
          message.text,
          style: TextStyle(
            color: isUser ? Colors.white : Colors.black,
            fontSize: 15,
            height: 1.35,
          ),
        ),
      ),
    );
  }
}

class _BottomInputBar extends StatelessWidget {
  const _BottomInputBar({
    required this.controller,
    required this.mode,
    required this.isSending,
    required this.isListening,
    required this.onModeChange,
    required this.onSend,
    required this.onMicTap,
    required this.onAttachTap,
  });

  final TextEditingController controller;
  final ChatMode mode;
  final bool isSending;
  final bool isListening;
  final ValueChanged<ChatMode> onModeChange;
  final VoidCallback onSend;
  final VoidCallback onMicTap;
  final VoidCallback onAttachTap;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(8, 8, 8, 12),
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.symmetric(
          horizontal: 8,
          vertical: 8,
        ),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(28),
          border: Border.all(
            color: const Color(0xFFD8D8D8),
          ),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 8),
              child: TextField(
                controller: controller,
                minLines: 1,
                maxLines: 5,
                style: const TextStyle(
                  color: Colors.black,
                  fontSize: 15,
                ),
                decoration: const InputDecoration(
                  hintText: 'Pregunta algo...',
                  hintStyle: TextStyle(
                    color: Color(0xFF8A8A8A),
                  ),
                  border: InputBorder.none,
                  isCollapsed: true,
                  contentPadding:
                      EdgeInsets.symmetric(vertical: 12),
                ),
              ),
            ),
            const SizedBox(height: 4),
            Row(
              children: [
                IconButton(
                  onPressed: onAttachTap,
                  icon: const Icon(
                    Icons.add_circle_outline,
                    color: Colors.black,
                  ),
                ),
                _ModeChip(
                  label: 'Chat',
                  selected: mode == ChatMode.chat,
                  onTap: () =>
                      onModeChange(ChatMode.chat),
                ),
                const SizedBox(width: 6),
                _ModeChip(
                  label: 'Coder',
                  selected: mode == ChatMode.coder,
                  onTap: () =>
                      onModeChange(ChatMode.coder),
                ),
                const Spacer(),
                IconButton(
                  onPressed: onMicTap,
                  icon: Image.asset(
                    'assets/images/microphone.png',
                    width: 22,
                    height: 22,
                    color: isListening
                        ? const Color(0xFF6ED7FF)
                        : Colors.black,
                  ),
                ),
                isSending
                    ? const SizedBox(
                        width: 40,
                        height: 40,
                        child: Padding(
                          padding: EdgeInsets.all(10),
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: Colors.black,
                          ),
                        ),
                      )
                    : IconButton(
                        onPressed: onSend,
                        icon: const Icon(
                          Icons.send_rounded,
                          color: Color(0xFF1E88C7),
                        ),
                      ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _ModeChip extends StatelessWidget {
  const _ModeChip({
    required this.label,
    required this.selected,
    required this.onTap,
  });

  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(
          horizontal: 14,
          vertical: 8,
        ),
        decoration: BoxDecoration(
          color: selected
              ? const Color(0xFFE0E0E0)
              : Colors.transparent,
          borderRadius: BorderRadius.circular(16),
        ),
        child: Text(
          label,
          style: TextStyle(
            color: selected
                ? Colors.black
                : const Color(0xFF8A8A8A),
            fontSize: 13,
            fontWeight: FontWeight.w600,
          ),
        ),
      ),
    );
  }
}

class _CoderPaywallDialog extends StatelessWidget {
  const _CoderPaywallDialog({
    required this.onClose,
  });

  final VoidCallback onClose;

  Future<void> _openPaypal() async {}

  @override
  Widget build(BuildContext context) {
    return Dialog(
      backgroundColor: const Color(0xFF2A2A2A),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(20),
      ),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(
          24,
          20,
          24,
          24,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                IconButton(
                  onPressed: onClose,
                  icon: const Icon(
                    Icons.close,
                    color: Colors.white,
                  ),
                ),
              ],
            ),
            const Text(
              'Paga para continuar',
              style: TextStyle(
                color: Colors.white,
                fontSize: 22,
                fontWeight: FontWeight.w700,
              ),
            ),
            const SizedBox(height: 10),
            const Text(
              'Coder desbloquea envío de imágenes ilimitado y prioridad en las respuestas.',
              style: TextStyle(
                color: Color(0xFF8A8A8A),
                fontSize: 14,
                height: 1.4,
              ),
            ),
            const SizedBox(height: 18),
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: const Color(0xFF1E1E1E),
                borderRadius: BorderRadius.circular(14),
                border: Border.all(
                  color: const Color(0xFF3A3A3A),
                ),
              ),
              child: const Row(
                mainAxisAlignment:
                    MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    'Plan Coder',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  Text(
                    '\$75 COP/mes',
                    style: TextStyle(
                      color: Color(0xFF6ED7FF),
                      fontSize: 16,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 20),
            SizedBox(
              width: double.infinity,
              height: 52,
              child: ElevatedButton(
                onPressed: _openPaypal,
                style: ElevatedButton.styleFrom(
                  backgroundColor:
                      const Color(0xFF6ED7FF),
                  foregroundColor: Colors.black,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(14),
                  ),
                ),
                child: const Text(
                  'Pagar con PayPal',
                  style: TextStyle(
                    fontWeight: FontWeight.w700,
                    fontSize: 15,
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}