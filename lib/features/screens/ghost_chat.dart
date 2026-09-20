import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/api.dart';
import '../../core/i18n.dart';
import '../../core/models.dart';
import '../../core/theme_controller.dart';

class GhostChatScreen extends ConsumerStatefulWidget {
  const GhostChatScreen({super.key});

  @override
  ConsumerState<GhostChatScreen> createState() => _GhostChatScreenState();
}

class _GhostMessage {
  final String text;
  final bool fromUser;
  const _GhostMessage({required this.text, required this.fromUser});
}

class _GhostChatScreenState extends ConsumerState<GhostChatScreen> {
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
      // Nunca mandamos chatId: el backend no persiste nada en Chat/Message.
      final response = await ApiClient.post('/ai/chat', {
        'prompt': text,
        'mode': 'chat',
      });
      final data = ApiClient.decode(response) as Map<String, dynamic>;
      final chatResponse = ChatResponse.fromJson(data);
      setState(() {
        _messages.add(
          _GhostMessage(text: chatResponse.response, fromUser: false),
        );
      });
    } catch (e) {
      setState(() {
        _messages.add(
          const _GhostMessage(
            text: 'No se pudo contactar al servidor. Intenta de nuevo.',
            fromUser: false,
          ),
        );
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
    final palette = ref.watch(appPaletteProvider);

    return Scaffold(
      backgroundColor: palette.background,
      appBar: AppBar(
        backgroundColor: palette.background,
        elevation: 0,
        iconTheme: IconThemeData(color: palette.textPrimary),
        title: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              Icons.visibility_off_outlined,
              color: palette.textPrimary,
              size: 18,
            ),
            const SizedBox(width: 8),
            Text(
              AppLocale.t('incognito_chat'),
              style: TextStyle(color: palette.textPrimary, fontSize: 16),
            ),
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
                color: palette.surface,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: palette.border),
              ),
              child: Row(
                children: [
                  Icon(
                    Icons.info_outline,
                    color: palette.textSecondary,
                    size: 16,
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      AppLocale.t('incognito_notice'),
                      style: TextStyle(
                        color: palette.textSecondary,
                        fontSize: 12.5,
                      ),
                    ),
                  ),
                ],
              ),
            ),
            Expanded(
              child: _messages.isEmpty
                  ? Center(
                      child: Text(
                        'Preguntá lo que quieras, sin dejar rastro',
                        style: TextStyle(
                          color: palette.textSecondary,
                          fontSize: 15,
                        ),
                      ),
                    )
                  : ListView.builder(
                      controller: _scrollController,
                      padding: const EdgeInsets.symmetric(
                        horizontal: 16,
                        vertical: 12,
                      ),
                      itemCount: _messages.length,
                      itemBuilder: (context, index) {
                        final msg = _messages[index];
                        return Align(
                          alignment: msg.fromUser
                              ? Alignment.centerRight
                              : Alignment.centerLeft,
                          child: Container(
                            margin: const EdgeInsets.symmetric(vertical: 6),
                            padding: const EdgeInsets.symmetric(
                              horizontal: 16,
                              vertical: 12,
                            ),
                            constraints: BoxConstraints(
                              maxWidth:
                                  MediaQuery.of(context).size.width * 0.78,
                            ),
                            decoration: BoxDecoration(
                              color: msg.fromUser
                                  ? palette.accent.withValues(alpha: 0.18)
                                  : palette.surface,
                              borderRadius: BorderRadius.circular(16),
                              border: Border.all(color: palette.border),
                            ),
                            child: Text(
                              msg.text,
                              style: TextStyle(
                                color: palette.textPrimary,
                                fontSize: 15,
                                height: 1.35,
                              ),
                            ),
                          ),
                        );
                      },
                    ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(12, 8, 12, 12),
              child: Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 14,
                  vertical: 6,
                ),
                decoration: BoxDecoration(
                  color: palette.surface,
                  borderRadius: BorderRadius.circular(28),
                  border: Border.all(color: palette.border),
                ),
                child: Row(
                  children: [
                    Expanded(
                      child: TextField(
                        controller: _messageController,
                        style: TextStyle(
                          color: palette.textPrimary,
                          fontSize: 15,
                        ),
                        cursorColor: palette.accent,
                        textInputAction: TextInputAction.send,
                        onSubmitted: (_) => _sendMessage(),
                        decoration: InputDecoration(
                          hintText: AppLocale.t('ask_something'),
                          hintStyle: TextStyle(color: palette.textSecondary),
                          border: InputBorder.none,
                          isCollapsed: true,
                          contentPadding: const EdgeInsets.symmetric(
                            vertical: 14,
                          ),
                        ),
                      ),
                    ),
                    _isSending
                        ? SizedBox(
                            width: 40,
                            height: 40,
                            child: Padding(
                              padding: const EdgeInsets.all(10),
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                                color: palette.textPrimary,
                              ),
                            ),
                          )
                        : IconButton(
                            onPressed: _sendMessage,
                            icon: Icon(
                              Icons.send_rounded,
                              color: palette.accent,
                            ),
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
