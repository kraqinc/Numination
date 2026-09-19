import 'package:flutter/material.dart';

import '../../core/api.dart';
import '../../core/models.dart';
import '../../core/theme.dart';

class GhostChatScreen extends StatefulWidget {
  const GhostChatScreen({super.key});

  @override
  State<GhostChatScreen> createState() => _GhostChatScreenState();
}

class _GhostMessage {
  final String text;
  final bool fromUser;
  const _GhostMessage({required this.text, required this.fromUser});
}

class _GhostChatScreenState extends State<GhostChatScreen> {
  final _messageController = TextEditingController();
  final _scrollController = ScrollController();
  final List<_GhostMessage> _messages = [];
  bool _isSending = false;

  @override
  void dispose() {
    _messageController.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  Future<void> _sendMessage() async {
    final text = _messageController.text.trim();
    if (text.isEmpty || _isSending) return;

    setState(() {
      _messages.add(_GhostMessage(text: text, fromUser: true));
      _isSending = true;
      _messageController.clear();
    });
    _scrollToBottom();

    try {
      // Modo incógnito: nunca mandamos chatId, así el backend no persiste
      // nada en las tablas Chat/Message. La conversación solo vive en
      // memoria mientras esta pantalla está abierta.
      final response = await ApiClient.post('/ai/chat', {
        'prompt': text,
        'mode': 'chat',
      });
      final data = ApiClient.decode(response) as Map<String, dynamic>;
      final chatResponse = ChatResponse.fromJson(data);
      setState(() {
        _messages.add(_GhostMessage(text: chatResponse.response, fromUser: false));
      });
    } catch (e) {
      setState(() {
        _messages.add(const _GhostMessage(
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
    return Scaffold(
      backgroundColor: AppColors.screenBackground,
      appBar: AppBar(
        backgroundColor: AppColors.screenBackground,
        elevation: 0,
        iconTheme: const IconThemeData(color: Colors.black),
        title: Row(
          mainAxisSize: MainAxisSize.min,
          children: const [
            Icon(Icons.visibility_off_outlined, color: Colors.black, size: 18),
            SizedBox(width: 8),
            Text('Chat incógnito', style: TextStyle(color: Colors.black, fontSize: 16)),
          ],
        ),
      ),
      body: SafeArea(
        child: Column(
          children: [
            Container(
              margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: const Color(0xFFD8D8D8)),
              ),
              child: const Row(
                children: [
                  Icon(Icons.info_outline, color: Color(0xFF8A8A8A), size: 16),
                  SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      'Este chat no se guarda ni aparece en tu historial.',
                      style: TextStyle(color: Color(0xFF8A8A8A), fontSize: 12.5),
                    ),
                  ),
                ],
              ),
            ),
            Expanded(
              child: _messages.isEmpty
                  ? const Center(
                      child: Text(
                        'Preguntá lo que quieras, sin dejar rastro',
                        style: TextStyle(color: Color(0xFF5C5C5C), fontSize: 15),
                      ),
                    )
                  : ListView.builder(
                      controller: _scrollController,
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                      itemCount: _messages.length,
                      itemBuilder: (context, index) {
                        final msg = _messages[index];
                        return Align(
                          alignment: msg.fromUser ? Alignment.centerRight : Alignment.centerLeft,
                          child: Container(
                            margin: const EdgeInsets.symmetric(vertical: 6),
                            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                            constraints: BoxConstraints(maxWidth: MediaQuery.of(context).size.width * 0.78),
                            decoration: BoxDecoration(
                              color: msg.fromUser ? const Color(0xFF1B1B1B) : Colors.white,
                              borderRadius: BorderRadius.circular(16),
                              border: Border.all(color: const Color(0xFFD8D8D8)),
                            ),
                            child: Text(
                              msg.text,
                              style: TextStyle(color: msg.fromUser ? Colors.white : Colors.black, fontSize: 15, height: 1.35),
                            ),
                          ),
                        );
                      },
                    ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(12, 8, 12, 12),
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(28),
                  border: Border.all(color: const Color(0xFFD8D8D8)),
                ),
                child: Row(
                  children: [
                    Expanded(
                      child: TextField(
                        controller: _messageController,
                        style: const TextStyle(color: Colors.black, fontSize: 15),
                        textInputAction: TextInputAction.send,
                        onSubmitted: (_) => _sendMessage(),
                        decoration: const InputDecoration(
                          hintText: 'Pregunta algo...',
                          hintStyle: TextStyle(color: Color(0xFF8A8A8A)),
                          border: InputBorder.none,
                          isCollapsed: true,
                          contentPadding: EdgeInsets.symmetric(vertical: 14),
                        ),
                      ),
                    ),
                    _isSending
                        ? const SizedBox(
                            width: 40,
                            height: 40,
                            child: Padding(
                              padding: EdgeInsets.all(10),
                              child: CircularProgressIndicator(strokeWidth: 2, color: Colors.black),
                            ),
                          )
                        : IconButton(
                            onPressed: _sendMessage,
                            icon: const Icon(Icons.send_rounded, color: Color(0xFF6ED7FF)),
                          ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}