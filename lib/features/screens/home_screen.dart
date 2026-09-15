import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/api.dart';
import '../../core/auth_controller.dart';
import '../../core/models.dart';
import '../widgets/hamburger.dart';

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

  ChatMode _mode = ChatMode.chat;
  bool _isSending = false;
  final List<ChatMessage> _messages = [];

  static const _bg = Colors.black;

  @override
  void dispose() {
    _messageController.dispose();
    _scrollController.dispose();
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
      final response = await ApiClient.post('/ai/chat', {
        'prompt': text,
        'mode': _mode == ChatMode.coder ? 'coder' : 'chat',
      });
      final data = ApiClient.decode(response) as Map<String, dynamic>;
      final chatResponse = ChatResponse.fromJson(data);
      setState(() {
        _messages.add(ChatMessage(text: chatResponse.response, fromUser: false));
      });
    } on ApiException catch (e) {
      setState(() {
        _messages.add(ChatMessage(text: 'Error: ${e.message}', fromUser: false));
      });
    } catch (e) {
      setState(() {
        _messages.add(const ChatMessage(
          text: 'No se pudo contactar al servidor. Intenta de nuevo.',
          fromUser: false,
        ));
      });
    } finally {
      if (mounted) setState(() => _isSending = false);
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
      backgroundColor: _bg,
      drawer: AppDrawer(email: email, mode: _mode, onSelectMode: _toggleMode),
      body: SafeArea(
        child: Column(
          children: [
            _TopBar(onMenuTap: () => _scaffoldKey.currentState?.openDrawer()),
            Expanded(
              child: _messages.isEmpty
                  ? const _EmptyState()
                  : ListView.builder(
                      controller: _scrollController,
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
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
              onModeChange: _toggleMode,
              onSend: _sendMessage,
            ),
          ],
        ),
      ),
    );
  }
}

class _TopBar extends StatelessWidget {
  const _TopBar({required this.onMenuTap});
  final VoidCallback onMenuTap;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
      child: Row(
        children: [
          IconButton(
            onPressed: onMenuTap,
            icon: const Icon(Icons.menu, color: Colors.white),
          ),
          Expanded(
            child: Container(
              height: 44,
              padding: const EdgeInsets.symmetric(horizontal: 14),
              decoration: BoxDecoration(
                color: const Color(0xFF141414),
                borderRadius: BorderRadius.circular(22),
              ),
              child: Row(
                children: [
                  const Icon(Icons.search, color: Color(0xFF8A8A8A), size: 20),
                  const SizedBox(width: 8),
                  const Expanded(
                    child: Text(
                      'Buscar chats',
                      style: TextStyle(color: Color(0xFF8A8A8A), fontSize: 15),
                    ),
                  ),
                  const Icon(Icons.grid_view_rounded, color: Color(0xFF8A8A8A), size: 20),
                ],
              ),
            ),
          ),
          const SizedBox(width: 8),
          IconButton(
            onPressed: () {},
            icon: Image.asset(
              'assets/images/ghost.png',
              width: 22,
              height: 22,
              color: Colors.white,
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
        style: TextStyle(color: Color(0xFF5C5C5C), fontSize: 16),
      ),
    );
  }
}

class _MessageBubble extends StatelessWidget {
  const _MessageBubble({required this.message});
  final ChatMessage message;

  @override
  Widget build(BuildContext context) {
    final isUser = message.fromUser;
    return Align(
      alignment: isUser ? Alignment.centerRight : Alignment.centerLeft,
      child: Container(
        margin: const EdgeInsets.symmetric(vertical: 6),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        constraints: BoxConstraints(maxWidth: MediaQuery.of(context).size.width * 0.78),
        decoration: BoxDecoration(
          color: isUser ? const Color(0xFF1B1B1B) : const Color(0xFF111111),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: const Color(0xFF232323)),
        ),
        child: Text(
          message.text,
          style: const TextStyle(color: Colors.white, fontSize: 15, height: 1.35),
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
    required this.onModeChange,
    required this.onSend,
  });

  final TextEditingController controller;
  final ChatMode mode;
  final bool isSending;
  final ValueChanged<ChatMode> onModeChange;
  final VoidCallback onSend;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(12, 8, 12, 12),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
        decoration: BoxDecoration(
          color: const Color(0xFF141414),
          borderRadius: BorderRadius.circular(28),
        ),
        child: Row(
          children: [
            IconButton(
              onPressed: () {},
              icon: const Icon(Icons.add_circle_outline, color: Colors.white),
            ),
            Expanded(
              child: TextField(
                controller: controller,
                style: const TextStyle(color: Colors.white, fontSize: 15),
                textInputAction: TextInputAction.send,
                onSubmitted: (_) => onSend(),
                decoration: const InputDecoration(
                  hintText: 'Pregunta algo...',
                  hintStyle: TextStyle(color: Color(0xFF8A8A8A)),
                  border: InputBorder.none,
                  isCollapsed: true,
                  contentPadding: EdgeInsets.symmetric(vertical: 12),
                ),
              ),
            ),
            const SizedBox(width: 4),
            _ModeChip(
              label: 'Chat',
              selected: mode == ChatMode.chat,
              onTap: () => onModeChange(ChatMode.chat),
            ),
            const SizedBox(width: 6),
            _ModeChip(
              label: 'Coder',
              selected: mode == ChatMode.coder,
              onTap: () => onModeChange(ChatMode.coder),
            ),
            const SizedBox(width: 4),
            IconButton(
              onPressed: () {},
              icon: Image.asset(
                'assets/images/microphone.png',
                width: 22,
                height: 22,
                color: Colors.white,
              ),
            ),
            isSending
                ? const SizedBox(
                    width: 40,
                    height: 40,
                    child: Padding(
                      padding: EdgeInsets.all(10),
                      child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                    ),
                  )
                : IconButton(
                    onPressed: onSend,
                    icon: const Icon(Icons.volume_up_outlined, color: Colors.white),
                  ),
          ],
        ),
      ),
    );
  }
}

class _ModeChip extends StatelessWidget {
  const _ModeChip({required this.label, required this.selected, required this.onTap});
  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
        decoration: BoxDecoration(
          color: selected ? const Color(0xFF2A2A2A) : Colors.transparent,
          borderRadius: BorderRadius.circular(16),
        ),
        child: Text(
          label,
          style: TextStyle(
            color: selected ? Colors.white : const Color(0xFF8A8A8A),
            fontSize: 13,
            fontWeight: FontWeight.w600,
          ),
        ),
      ),
    );
  }
}

class _CoderPaywallDialog extends StatelessWidget {
  const _CoderPaywallDialog({required this.onClose});
  final VoidCallback onClose;

  Future<void> _openPaypal() async {
    // TODO: reemplazar con el checkout real de PayPal (billing.ts /
    // paypalCheckoutUrl del backend) cuando esté listo el endpoint
    // de suscripción de Coder.
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      backgroundColor: const Color(0xFF0D0D0D),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(24, 20, 24, 24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                IconButton(
                  onPressed: onClose,
                  icon: const Icon(Icons.close, color: Colors.white),
                ),
              ],
            ),
            const Text(
              'Paga para continuar',
              style: TextStyle(color: Colors.white, fontSize: 22, fontWeight: FontWeight.w700),
            ),
            const SizedBox(height: 10),
            const Text(
              'Coder desbloquea envío de imágenes ilimitado y prioridad en las respuestas.',
              style: TextStyle(color: Color(0xFF8A8A8A), fontSize: 14, height: 1.4),
            ),
            const SizedBox(height: 18),
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: const Color(0xFF141414),
                borderRadius: BorderRadius.circular(14),
                border: Border.all(color: const Color(0xFF232323)),
              ),
              child: const Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text('Plan Coder', style: TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.w600)),
                  Text('\$75 COP/mes', style: TextStyle(color: Color(0xFF6ED7FF), fontSize: 16, fontWeight: FontWeight.w700)),
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
                  backgroundColor: const Color(0xFF6ED7FF),
                  foregroundColor: Colors.black,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                ),
                child: const Text('Pagar con PayPal', style: TextStyle(fontWeight: FontWeight.w700, fontSize: 15)),
              ),
            ),
          ],
        ),
      ),
    );
  }
}