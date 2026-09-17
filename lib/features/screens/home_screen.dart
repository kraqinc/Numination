import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:speech_to_text/speech_recognition_result.dart';
import 'package:speech_to_text/speech_to_text.dart' as stt;
import 'package:speech_to_text/speech_to_text.dart'
    show SpeechListenOptions;

import '../../core/api.dart';
import '../../core/auth_controller.dart';
import '../../core/models.dart';
import '../widgets/hamburger.dart';
import '../widgets/search_chats.dart';
import 'ghost_chat.dart';

class ChatMessage {
  final String text;
  final bool fromUser;

  const ChatMessage({
    required this.text,
    required this.fromUser,
  });
}

class HomeScreen extends ConsumerStatefulWidget {
  const HomeScreen({super.key});

  @override
  ConsumerState<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends ConsumerState<HomeScreen> {
  final _messageController = TextEditingController();
  final _scrollController = ScrollController();
  final _scaffoldKey = GlobalKey<ScaffoldState>();
  final stt.SpeechToText _speech = stt.SpeechToText();

  ChatMode _mode = ChatMode.chat;

  bool _isSending = false;
  bool _isListening = false;
  bool _speechReady = false;

  String? _selectedChatTitle;

  final List<String> _pendingFiles = [];
  final List<ChatMessage> _messages = [];

  static const Color _background = Color(0xFFECECEC);

  @override
  void dispose() {
    _speech.cancel();
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

    setState(() {
      _mode = mode;
    });
  }

  void _showCoderPaywall() {
    showDialog<void>(
      context: context,
      builder: (dialogContext) {
        return AlertDialog(
          backgroundColor: const Color(0xFF111111),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(20),
          ),
          title: const Text(
            'Coder',
            style: TextStyle(color: Colors.white),
          ),
          content: const Text(
            'El modo Coder requiere el plan correspondiente.',
            style: TextStyle(
              color: Color(0xFF9A9A9A),
              height: 1.4,
            ),
          ),
          actions: [
            TextButton(
              onPressed: () {
                Navigator.of(dialogContext).pop();
              },
              child: const Text('Cerrar'),
            ),
          ],
        );
      },
    );
  }

  Future<void> _sendMessage() async {
    final text = _messageController.text.trim();

    if (text.isEmpty || _isSending) {
      return;
    }

    final files = List<String>.from(_pendingFiles);

    setState(() {
      _messages.add(
        ChatMessage(
          text: files.isEmpty
              ? text
              : '$text\n\nAdjuntos:\n${files.join('\n')}',
          fromUser: true,
        ),
      );

      _messageController.clear();
      _pendingFiles.clear();
      _isSending = true;
    });

    _scrollToBottom();

    try {
      final response = await ApiClient.post(
        '/ai/chat',
        {
          'prompt': text,
          'mode': _mode == ChatMode.coder ? 'coder' : 'chat',
        },
      );

      final decoded = ApiClient.decode(response);

      if (decoded is! Map<String, dynamic>) {
        throw Exception('Respuesta inválida del servidor');
      }

      final chatResponse = ChatResponse.fromJson(decoded);

      if (!mounted) return;

      setState(() {
        _messages.add(
          ChatMessage(
            text: chatResponse.response,
            fromUser: false,
          ),
        );
      });
    } on ApiException catch (e) {
      if (!mounted) return;

      setState(() {
        _messages.add(
          ChatMessage(
            text: 'Error: ${e.message}',
            fromUser: false,
          ),
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
      if (!mounted)

      setState(() {
        _isSending = false;
      });

      _scrollToBottom();
    }
  }

  Future<void> _pickFiles() async {
    try {
      final files = await FilePicker.pickFiles();

      if (!mounted || files.isEmpty) {
        return;
      }

      setState(() {
        _pendingFiles.addAll(
          files.map((file) => file.name),
        );
      });

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            '${files.length} archivo(s) seleccionado(s)',
          ),
        ),
      );
    } catch (_) {
      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('No se pudieron seleccionar los archivos'),
        ),
      );
    }
  }

  Future<void> _toggleListening() async {
    if (_isListening) {
      await _speech.stop();

      if (!mounted) return;

      setState(() {
        _isListening = false;
        });

      return;
    }

    if (!_speechReady) {
      _speechReady = await _speech.initialize(
        onError: (error) {
          if (!mounted) return;

          setState(() {
            _isListening = false;
          });

          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(
                'Micrófono: ${error.errorMsg}',
              ),
            ),
          );
        },
        onStatus: (status) {
          if (!mounted) return;

          if (status == 'done' || status == 'notListening') {
            setState(() {
              _isListening = false;
            });
          }
        },
      );
    }

    if (!_speechReady) {
      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'El reconocimiento de voz no está disponible en este dispositivo',
          ),
        ),
      );

      return;
    }

    setState(() {
      _isListening = true;
    });

    await _speech.listen(
      onResult: _onSpeechResult,
      listenOptions: SpeechListenOptions(
        partialResults: true,
        autoPunctuation: true,
        listenMode: stt.ListenMode.dictation,
      ),
    );
  }

  void _onSpeechResult(
    SpeechRecognitionResult result,
  ) {
    if (!mounted) return;

    if (result.recognizedWords.isNotEmpty) {
      _messageController.text = result.recognizedWords;

      _messageController.selection = TextSelection.fromPosition(
        TextPosition(
          offset: _messageController.text.length,
        ),
      );
    }

    if (result.finalResult) {
      setState(() {
        _isListening = false;
      });
    }
  }

  Future<void> _openSearch() async {
    final chat = await showSearchChats(context);

    if (!mounted || chat == null) {
      return;
    }

    setState(() {
      _selectedChatTitle = chat.title;
      _mode = chat.mode == 'coder'
          ? ChatMode.coder
          : ChatMode.chat;
      _messages.clear();
    });
  }

  void _openNewChat() {
    setState(() {
      _selectedChatTitle = null;
      _messages.clear();
      _messageController.clear();
      _pendingFiles.clear();
    });
  }

  void _selectChat(ChatSession chat) {
    setState(() {
      _selectedChatTitle = chat.title;

      _mode = chat.mode == 'coder'
          ? ChatMode.coder
          : ChatMode.chat;

      _messages.clear();
    });
  }

  void _openGhost() {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => const GhostChatScreen(),
      ),
    );
  }

  void _scrollToBottom() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!_scrollController.hasClients) {
        return;
      }

      _scrollController.animateTo(
        _scrollController.position.maxScrollExtent,
        duration: const Duration(
          milliseconds: 250,
        ),
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
      backgroundColor: _background,
      drawer: AppDrawer(
        email: email,
        avatarUrl: null,
        mode: _mode,
        onSelectMode: _toggleMode,
        onSelectChat: _selectChat,
        onNewChat: _openNewChat,
      ),
      body: SafeArea(
        child: Column(
          children: [
            _TopBar(
              title: _selectedChatTitle,
              onMenuTap: () {
                _scaffoldKey.currentState?.openDrawer();
              },
              onSearch: _openSearch,
              onGhost: _openGhost,
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
                      itemBuilder: (
                        context,
                        index,
                      ) {
                        return _MessageBubble(
                          message: _messages[index],
                        );
                      },
                    ),
            ),
            _BottomInputBar(
              controller: _messageController,
              mode: _mode,
              isSending: _isSending,
              isListening: _isListening,
              pendingFiles: _pendingFiles,
              onModeChange: _toggleMode,
              onSend: _sendMessage,
              onPickFiles: _pickFiles,
              onMic: _toggleListening,
              onRemoveFile: (name) {
                setState(() {
                  _pendingFiles.remove(name);
                });
              },
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
    required this.onSearch,
    required this.onGhost,
    this.title,
  });

  final VoidCallback onMenuTap;
  final VoidCallback onSearch;
  final VoidCallback onGhost;
  final String? title;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(
        16,
        8,
        16,
        8,
      ),
      child: Row(
        children: [
          IconButton(
            onPressed: onMenuTap,
            icon: const Icon(
              Icons.menu,
              color: Colors.black87,
            ),
          ),
          Expanded(
            child: GestureDetector(
              onTap: onSearch,
              child: Container(
                height: 44,
                padding: const EdgeInsets.symmetric(
                  horizontal: 14,
                ),
                decoration: BoxDecoration(
                  color: const Color(0xFF141414),
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
                    Expanded(
                      child: Text(
                        title ?? 'Buscar chats',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
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
            onPressed: onGhost,
            icon: Image.asset(
              'assets/images/ghost.png',
              width: 22,
              height: 22,
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
          color: Color(0xFF5C5C5C),
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
      alignment: isUser
          ? Alignment.centerRight
          : Alignment.centerLeft,
      child: Container(
        margin: const EdgeInsets.symmetric(
          vertical: 6,
        ),
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
              : const Color(0xFF111111),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: const Color(0xFF232323),
          ),
        ),
        child: Text(
          message.text,
          style: const TextStyle(
            color: Colors.white,
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
    required this.pendingFiles,
    required this.onModeChange,
    required this.onSend,
    required this.onPickFiles,
    required this.onMic,
    required this.onRemoveFile,
  });

  final TextEditingController controller;
  final ChatMode mode;
  final bool isSending;
  final bool isListening;
  final List<String> pendingFiles;

  final ValueChanged<ChatMode> onModeChange;
  final VoidCallback onSend;
  final VoidCallback onPickFiles;
  final VoidCallback onMic;
  final ValueChanged<String> onRemoveFile;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(
        12,
        8,
        12,
        12,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          if (pendingFiles.isNotEmpty)
            SizedBox(
              height: 36,
              child: ListView.separated(
                scrollDirection: Axis.horizontal,
                itemCount: pendingFiles.length,
                separatorBuilder: (
                  _,
                  _,
                ) =>
                    const SizedBox(width: 6),
                itemBuilder: (
                  context,
                  index,
                ) {
                  final name = pendingFiles[index];

                  return Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 10,
                    ),
                    decoration: BoxDecoration(
                      color: const Color(0xFF141414),
                      borderRadius: BorderRadius.circular(18),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Icon(
                          Icons.attach_file,
                          color: Color(0xFF6ED7FF),
                          size: 15,
                        ),
                        const SizedBox(width: 5),
                        ConstrainedBox(
                          constraints: const BoxConstraints(
                            maxWidth: 150,
                          ),
                          child: Text(
                            name,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 12,
                            ),
                          ),
                        ),
                        IconButton(
                          padding: EdgeInsets.zero,
                          constraints: const BoxConstraints(
                            minWidth: 28,
                            minHeight: 28,
                          ),
                          onPressed: () {
                            onRemoveFile(name);
                          },
                          icon: const Icon(
                            Icons.close,
                            color: Color(0xFF8A8A8A),
                            size: 15,
                          ),
                        ),
                      ],
                    ),
                  );
                },
              ),
            ),
          if (pendingFiles.isNotEmpty)
            const SizedBox(height: 6),
          Container(
            padding: const EdgeInsets.symmetric(
              horizontal: 10,
              vertical: 8,
            ),
            decoration: BoxDecoration(
              color: const Color(0xFF141414),
              borderRadius: BorderRadius.circular(28),
            ),
            child: Row(
              children: [
                IconButton(
                  onPressed: isSending ? null : onPickFiles,
                  icon: const Icon(
                    Icons.add_circle_outline,
                    color: Colors.white,
                  ),
                ),
                Expanded(
                  child: TextField(
                    controller: controller,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 15,
                    ),
                    textInputAction: TextInputAction.send,
                    onSubmitted: (_) {
                      onSend();
                    },
                    decoration: const InputDecoration(
                      hintText: 'Pregunta algo...',
                      hintStyle: TextStyle(
                        color: Color(0xFF8A8A8A),
                      ),
                      border: InputBorder.none,
                      isCollapsed: true,
                      contentPadding: EdgeInsets.symmetric(
                        vertical: 12,
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 4),
                _ModeChip(
                  label: 'Chat',
                  selected: mode == ChatMode.chat,
                  onTap: () {
                    onModeChange(ChatMode.chat);
                  },
                ),
                const SizedBox(width: 6),
                _ModeChip(
                  label: 'Coder',
                  selected: mode == ChatMode.coder,
                  onTap: () {
                    onModeChange(ChatMode.coder);
                  },
                ),
                const SizedBox(width: 4),
                IconButton(
                  onPressed: isSending ? null : onMic,
                  icon: Icon(
                    isListening
                        ? Icons.stop_circle_outlined
                        : Icons.mic_none_rounded,
                    color: isListening
                        ? const Color(0xFFFF7282)
                        : Colors.white,
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
                            color: Colors.white,
                          ),
                        ),
                      )
                    : IconButton(
                        onPressed: onSend,
                        icon: const Icon(
                          Icons.send_rounded,
                          color: Color(0xFF6ED7FF),
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
              ? const Color(0xFF2A2A2A)
              : Colors.transparent,
          borderRadius: BorderRadius.circular(16),
        ),
        child: Text(
          label,
          style: TextStyle(
            color: selected
                ? Colors.white
                : const Color(0xFF8A8A8A),
            fontSize: 13,
            fontWeight: FontWeight.w600,
          ),
        ),
      ),
    );
  }
}
