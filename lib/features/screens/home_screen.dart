import 'dart:io';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lucide_flutter/lucide_flutter.dart';
import 'package:speech_to_text/speech_to_text.dart' as stt;

import '../../core/ai_modes_controller.dart';
import '../../core/api.dart';
import '../../core/auth_controller.dart';
import '../../core/l10n_extensions.dart';
import '../../core/models.dart';
import '../../core/theme_controller.dart';
import '../../core/update_service.dart';
import '../widgets/ai_response.dart';
import '../widgets/hamburger.dart';
import '../widgets/search_chats.dart';
import '../widgets/voice_input_button.dart';
import 'coder_screen.dart';
import 'ghost_chat.dart';

class ChatMessage {
  final String text;
  final bool fromUser;
  final String? id;
  final String? chatId;

  final bool memorySaved;
  final String? memoryId;
  final String? memoryTitle;
  final String? memoryContent;

  const ChatMessage({
    required this.text,
    required this.fromUser,
    this.id,
    this.chatId,
    this.memorySaved = false,
    this.memoryId,
    this.memoryTitle,
    this.memoryContent,
  });
}

class PendingAttachment {
  final String name;
  final String content;
  final int sizeBytes;

  const PendingAttachment({
    required this.name,
    required this.content,
    required this.sizeBytes,
  });
}

class HomeScreen extends ConsumerStatefulWidget {
  const HomeScreen({super.key});

  @override
  ConsumerState<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends ConsumerState<HomeScreen>
    with WidgetsBindingObserver {
  final _messageController = TextEditingController();
  final _scrollController = ScrollController();
  final GlobalKey<ScaffoldState> _scaffoldKey = GlobalKey<ScaffoldState>();

  final stt.SpeechToText _speech = stt.SpeechToText();

  bool _isSending = false;
  bool _isListening = false;
  bool _speechAvailable = false;
  bool _isAttaching = false;
  bool _overthink = false;

  String _speechLocaleId = 'es_ES';
  String _speechBaseText = '';
  String _modeId = 'chat';

  ApiCancelToken? _generationToken;

  final List<PendingAttachment> _pendingAttachments = [];
  final List<ChatMessage> _messages = [];

  String? _activeChatId;

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
     onStatus: (status) async {
       if (!_isListening) return;

       if (status == 'done' || status == 'notListening') {
         await _restartSpeechListening();
       }
     },
     onError: (_) async {
       if (!_isListening) return;

       await _restartSpeechListening();
     },
   );

   if (_speechAvailable) {
     try {
       final locales = await _speech.locales();

       const preferred = <String>[
         'es_CO',
         'es_ES',
         'es_MX',
         'es_US',
       ];

       for (final wanted in preferred) {
         if (locales.any((locale) => locale.localeId == wanted)) {
           _speechLocaleId = wanted;
           break;
         }
       }
     } catch (_) {}
   }

   if (mounted) {
     setState(() {});
   }
 }

 Future<void> _restartSpeechListening() async {
   if (!_isListening || !_speechAvailable) return;

   try {
     await _speech.listen(
       listenOptions: stt.SpeechListenOptions(
         localeId: _speechLocaleId,
         partialResults: true,
         listenFor: const Duration(minutes: 5),
         pauseFor: const Duration(seconds: 3),
       ),
       onResult: (result) {
         if (!mounted || !_isListening) return;

         final spoken = result.recognizedWords.trim();

         if (spoken.isEmpty) return;

         final merged = [
           if (_speechBaseText.isNotEmpty) _speechBaseText,
           spoken,
         ].join(_speechBaseText.isNotEmpty ? ' ' : '');

         setState(() {
           _messageController.text = merged;
           _messageController.selection = TextSelection.fromPosition(
             TextPosition(offset: merged.length),
           );
         });
       },
     );
   } catch (_) {
     if (!mounted || !_isListening) return;

     await Future<void>.delayed(const Duration(milliseconds: 250));

     if (_isListening) {
       await _restartSpeechListening();
     }
   }
 }


  Future<void> _loadProfile() async {
    try {
      final response = await ApiClient.get('/auth/me');

      final data = ApiClient.decode(response) as Map<String, dynamic>;

      if (!mounted) return;

      setState(() {
        _profile = AppUser.fromJson(data['user'] as Map<String, dynamic>);
      });
    } catch (_) {
      // El perfil no debe impedir que cargue el chat.
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
      _messageController.clear();
      _pendingAttachments.clear();
    });

    _scrollToBottom();
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
            (m) => ChatMessage(
              text: m.content,
              fromUser: m.role == 'user',
              id: m.id,
              chatId: m.chatId,
            ),
          ),
        );
      });

      _scrollToBottom();
    } catch (_) {
      if (!mounted) return;

      setState(() {
        _messages.add(
          const ChatMessage(
            text: 'No pudimos cargar este chat. Inténtalo de nuevo.',
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
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text(
                'El dictado no está disponible. Revisa el permiso del micrófono.',
              ),
            ),
          );
        }
        return;
      }
    }

    if (_isListening) {
      if (mounted) {
        setState(() => _isListening = false);
      }

      await _speech.stop();
      return;
    }

    _speechBaseText = _messageController.text.trimRight();

    if (mounted) {
      setState(() => _isListening = true);
    }

    try {
      await _speech.listen(
        listenOptions: stt.SpeechListenOptions(
          localeId: _speechLocaleId,
          partialResults: true,
          listenFor: const Duration(minutes: 5),
          pauseFor: const Duration(seconds: 3),
        ),
        onResult: (result) {
          if (!mounted) return;

          final spoken = result.recognizedWords.trim();

          final merged = [
            if (_speechBaseText.isNotEmpty) _speechBaseText,
            if (spoken.isNotEmpty) spoken,
          ].join(_speechBaseText.isNotEmpty ? ' ' : '');

          setState(() {
            _messageController.text = merged;

            _messageController.selection = TextSelection.fromPosition(
              TextPosition(offset: merged.length),
            );
          });
        },
      );
    } catch (_) {
      if (mounted) {
        setState(() => _isListening = false);

        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text(
              'No pudimos iniciar el micrófono. Revisa el permiso e inténtalo de nuevo.',
            ),
          ),
        );
      }
    }
  }

  Future<void> _openAddMenu() async {
    await showModalBottomSheet<void>(
      context: context,
      showDragHandle: true,
      builder: (sheetContext) {
        return StatefulBuilder(
          builder: (sheetContext, setSheetState) {
            return SafeArea(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  ListTile(
                    leading: const Icon(LucideIcons.paperclip),
                    title: const Text('Añadir archivos'),
                    subtitle: const Text(
                      'Vista previa local hasta enviar el mensaje',
                    ),
                    onTap: () {
                      Navigator.pop(sheetContext);
                      _attachFile();
                    },
                  ),
                  ListTile(
                    leading: Icon(
                      _modeId == 'coder'
                          ? LucideIcons.messageCircle
                          : LucideIcons.code2,
                    ),
                    title: Text(
                      _modeId == 'coder' ? 'Cambiar a chat' : 'Cambiar a coder',
                    ),
                    trailing: const Icon(LucideIcons.chevronRight),
                    onTap: () {
                      Navigator.pop(sheetContext);

                      _toggleMode(_modeId == 'coder' ? 'chat' : 'coder');
                    },
                  ),
                  SwitchListTile(
                    secondary: const Icon(LucideIcons.brain),
                    title: const Text('Sobrepensar'),
                    subtitle: const Text(
                      'Revisión más profunda antes de responder',
                    ),
                    value: _overthink,
                    onChanged: (value) {
                      setState(() => _overthink = value);
                      setSheetState(() {});
                    },
                  ),
                  const SizedBox(height: 8),
                ],
              ),
            );
          },
        );
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
      const textExtensions = <String>{
        'txt',
        'md',
        'dart',
        'py',
        'js',
        'jsx',
        'ts',
        'tsx',
        'json',
        'yaml',
        'yml',
        'html',
        'css',
        'xml',
        'sql',
        'sh',
        'kt',
        'java',
        'go',
        'rs',
        'swift',
        'env',
        'toml',
        'gradle',
        'properties',
        'c',
        'h',
        'cpp',
        'php',
      };

      final extension = (picked.extension ?? '').toLowerCase();

      if (!textExtensions.contains(extension)) {
        throw Exception(
          'Por ahora la vista previa admite archivos de texto y código.',
        );
      }

      final file = File(picked.path!);
      final size = await file.length();

      if (size <= 0) {
        throw Exception('El archivo está vacío.');
      }

      if (size > 1024 * 1024) {
        throw Exception(
          'Por ahora cada archivo de texto debe pesar máximo 1 MB.',
        );
      }

      final content = await file.readAsString();

      if (content.length > 100000) {
        throw Exception('El contenido del archivo es demasiado largo.');
      }

      if (!mounted) return;

      setState(() {
        _pendingAttachments.add(
          PendingAttachment(
            name: picked.name,
            content: content,
            sizeBytes: size,
          ),
        );
      });
    } catch (e) {
      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('$e')));
    } finally {
      if (mounted) {
        setState(() => _isAttaching = false);
      }
    }
  }

  void _cancelGeneration() {
    _generationToken?.cancel();
  }

  Future<void> _sendMessage() async {
    final text = _messageController.text.trim();

    final attachments = List<PendingAttachment>.from(_pendingAttachments);

    if ((text.isEmpty && attachments.isEmpty) || _isSending) {
      return;
    }

    final visibleText = text.isEmpty ? 'Revisa los archivos adjuntos.' : text;

    final attachmentContext = attachments
        .map((file) {
          return '--- ${file.name} ---\n${file.content}';
        })
        .join('\n\n');

    var effectivePrompt = visibleText;

    if (attachmentContext.isNotEmpty) {
      effectivePrompt += '\n\nArchivos adjuntos:\n$attachmentContext';
    }

    if (effectivePrompt.length > 9900) {
      effectivePrompt =
          '${effectivePrompt.substring(0, 9900)}\n[Contenido truncado]';
    }

    final token = ApiCancelToken();
    final userMessageIndex = _messages.length;

    setState(() {
      _messages.add(
        ChatMessage(
          text: attachments.isEmpty
              ? visibleText
              : '$visibleText\n\n${attachments.length} archivo(s) adjunto(s)',
          fromUser: true,
        ),
      );

      _isSending = true;
      _generationToken = token;
      _messageController.clear();
      _pendingAttachments.clear();
    });

    _scrollToBottom();

    try {
      var chatId = _activeChatId;

      if (chatId == null) {
        final createRes = await ApiClient.post('/chats', {
          'title': visibleText.length > 40
              ? '${visibleText.substring(0, 40)}...'
              : visibleText,
          'mode': _modeId,
        });

        final createData = ApiClient.decode(createRes) as Map<String, dynamic>;

        final chat = Map<String, dynamic>.from(createData['chat'] as Map);

        chatId = '${chat['id']}';

        if (mounted) {
          setState(() {
            _activeChatId = chatId;
            _chatRevision++;
          });
        }
      }

      if (token.isCancelled) {
        throw const ApiRequestCancelled();
      }

      final response = await ApiClient.postCancelable('/ai/chat', {
        'prompt': effectivePrompt,
        'mode': _modeId,
        'chatId': chatId,
        'overthink': _overthink,
      }, token);

      final data = ApiClient.decode(response) as Map<String, dynamic>;

      final chatResponse = ChatResponse.fromJson(data);

      if (!mounted || token.isCancelled) return;

      setState(() {
        if (userMessageIndex < _messages.length) {
          final old = _messages[userMessageIndex];

          _messages[userMessageIndex] = ChatMessage(
            text: old.text,
            fromUser: true,
            id: data['userMessageId']?.toString(),
            chatId: chatId,
          );
        }

        _messages.add(
          ChatMessage(
            text: chatResponse.response,
            fromUser: false,
            id: data['assistantMessageId']?.toString(),
            chatId: chatId,
            memorySaved: data['memorySaved'] == true,
            memoryId: data['memoryId']?.toString(),
            memoryTitle: data['memoryTitle']?.toString(),
            memoryContent: data['memoryContent']?.toString(),
          ),
        );

        if (chatResponse.chatTitle?.trim().isNotEmpty == true) {
          _chatRevision++;
        }
      });
    } on ApiRequestCancelled {
      // Cancelar no agrega una respuesta falsa.
    } on ApiException catch (_) {
      if (!mounted || token.isCancelled) return;

      setState(() {
        _messages.add(
          ChatMessage(
            text: 'Numi no pudo responder en este momento. Inténtalo de nuevo.',
            fromUser: false,
          ),
        );
      });
    } catch (_) {
      if (!mounted || token.isCancelled) return;

      setState(() {
        _messages.add(
          const ChatMessage(
            text: 'Numi no pudo responder en este momento. Inténtalo de nuevo.',
            fromUser: false,
          ),
        );
      });
    } finally {
      if (mounted) {
        setState(() {
          _isSending = false;

          if (identical(_generationToken, token)) {
            _generationToken = null;
          }
        });
      }

      _scrollToBottom();
    }
  }

  void _copyMessage(ChatMessage message) {
    Clipboard.setData(ClipboardData(text: message.text));

    ScaffoldMessenger.of(
      context,
    ).showSnackBar(const SnackBar(content: Text('Mensaje copiado')));
  }

  void _editMessage(ChatMessage message) {
    setState(() {
      _messageController.text = message.text;

      _messageController.selection = TextSelection.fromPosition(
        TextPosition(offset: _messageController.text.length),
      );
    });
  }

  Future<void> _sendFeedback(ChatMessage message, String kind) async {
    final messageId = message.id;

    if (messageId == null || messageId.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'Todavía no podemos guardar tu opinión sobre este mensaje.',
          ),
        ),
      );
      return;
    }

    String? note;
    TextEditingController? noteController;

    if (kind == 'negative') {
      noteController = TextEditingController();

      note = await showDialog<String>(
        context: context,
        builder: (dialogContext) => AlertDialog(
          title: const Text('¿Qué pasó con esta respuesta?'),
          content: TextField(
            controller: noteController,
            minLines: 2,
            maxLines: 5,
            decoration: const InputDecoration(
              hintText: 'Cuéntanos qué estuvo mal o qué te faltó...',
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dialogContext),
              child: const Text('Cancelar'),
            ),
            FilledButton(
              onPressed: () {
                Navigator.pop(dialogContext, noteController!.text.trim());
              },
              child: const Text('Enviar opinión'),
            ),
          ],
        ),
      );

      noteController.dispose();

      if (note == null) {
        return;
      }
    }

    try {
      await ApiClient.post('/feedback', {
        'messageId': messageId,
        'kind': kind,
        if (note != null && note.isNotEmpty) 'note': note,
      });

      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Gracias. Tu opinión fue guardada.')),
      );
    } catch (_) {
      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('No pudimos guardar tu opinión. Inténtalo de nuevo.'),
        ),
      );
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
              onMenuTap: () {
                _scaffoldKey.currentState?.openDrawer();
              },
              onSearchTap: _openSearch,
              onGhostTap: _openGhostChat,
            ),
            Expanded(
              child: _messages.isEmpty
                  ? const _EmptyState()
                  : ListView.builder(
                      controller: _scrollController,
                      padding: const EdgeInsets.fromLTRB(0, 8, 0, 18),
                      itemCount: _messages.length + (_isSending ? 1 : 0),
                      itemBuilder: (context, index) {
                        if (_isSending && index == _messages.length) {
                          return const _ThinkingMessage();
                        }

                        final message = _messages[index];

                        return _MessageBubble(
                          message: message,
                          onCopy: _copyMessage,
                          onEdit: _editMessage,
                          onFeedback: _sendFeedback,
                        );
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
              overthink: _overthink,
              pendingAttachments: _pendingAttachments,
              onRemoveAttachment: (file) {
                setState(() {
                  _pendingAttachments.remove(file);
                });
              },
              onToggleOverthink: () {
                setState(() {
                  _overthink = !_overthink;
                });
              },
              onCancel: _cancelGeneration,
              onModeChange: _toggleMode,
              onSend: _sendMessage,
              onMicTap: _toggleListening,
              onAttachTap: _openAddMenu,
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
      padding: const EdgeInsets.fromLTRB(12, 10, 12, 8),
      child: Row(
        children: [
          GestureDetector(
            onTap: onMenuTap,
            behavior: HitTestBehavior.opaque,
            child: Padding(
              padding: const EdgeInsets.all(8),
              child: Icon(
                Icons.menu_rounded,
                color: palette.textPrimary.withValues(alpha: 0.88),
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
                  borderRadius: BorderRadius.circular(22),
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

class _MemorySavedWidget extends StatelessWidget {
  const _MemorySavedWidget({required this.title, this.content});

  final String? title;
  final String? content;

  @override
  Widget build(BuildContext context) {
    final displayTitle = title?.trim().isNotEmpty == true
        ? title!.trim()
        : 'Memoria guardada';

    return TweenAnimationBuilder<double>(
      tween: Tween(begin: 0, end: 1),
      duration: const Duration(milliseconds: 320),
      curve: Curves.easeOutCubic,
      builder: (context, value, child) {
        return Opacity(
          opacity: value,
          child: Transform.translate(
            offset: Offset(0, 8 * (1 - value)),
            child: Transform.scale(scale: 0.98 + (value * 0.02), child: child),
          ),
        );
      },
      child: Container(
        width: double.infinity,
        margin: const EdgeInsets.only(bottom: 10),
        padding: const EdgeInsets.symmetric(horizontal: 13, vertical: 11),
        decoration: BoxDecoration(
          color: Theme.of(
            context,
          ).colorScheme.surfaceContainerHighest.withValues(alpha: 0.42),
          borderRadius: BorderRadius.circular(14),
          border: Border.all(
            color: Theme.of(
              context,
            ).colorScheme.outline.withValues(alpha: 0.18),
          ),
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            Container(
              width: 32,
              height: 32,
              decoration: BoxDecoration(
                color: Theme.of(
                  context,
                ).colorScheme.primary.withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(9),
              ),
              child: Icon(
                LucideIcons.savePen,
                size: 17,
                color: Theme.of(context).colorScheme.primary,
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Memoria guardada',
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w700,
                      color: Theme.of(context).colorScheme.onSurface,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    displayTitle,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontSize: 12,
                      color: Theme.of(context).colorScheme.onSurfaceVariant,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _MessageBubble extends ConsumerWidget {
  const _MessageBubble({
    required this.message,
    required this.onCopy,
    required this.onEdit,
    required this.onFeedback,
  });

  final ChatMessage message;
  final ValueChanged<ChatMessage> onCopy;
  final ValueChanged<ChatMessage> onEdit;
  final void Function(ChatMessage, String) onFeedback;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final palette = ref.watch(appPaletteProvider);
    final isUser = message.fromUser;

    return Align(
      alignment: isUser ? Alignment.centerRight : Alignment.centerLeft,
      child: Container(
        margin: const EdgeInsets.symmetric(vertical: 5),
        constraints: BoxConstraints(
          maxWidth: MediaQuery.of(context).size.width * 0.88,
        ),
        child: Column(
          crossAxisAlignment: isUser
              ? CrossAxisAlignment.end
              : CrossAxisAlignment.start,
          children: [
            if (!isUser && message.memorySaved)
              _MemorySavedWidget(
                title: message.memoryTitle,
                content: message.memoryContent,
              ),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              decoration: BoxDecoration(
                color: isUser
                    ? palette.accent.withValues(alpha: 0.14)
                    : palette.surface,
                borderRadius: BorderRadius.circular(18),
                border: Border.all(
                  color: isUser
                      ? palette.accent.withValues(alpha: 0.25)
                      : palette.border.withValues(alpha: 0.6),
                ),
              ),
              child: AiResponse(text: message.text),
            ),
            Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                if (isUser)
                  IconButton(
                    tooltip: 'Editar mensaje',
                    visualDensity: VisualDensity.compact,
                    onPressed: () => onEdit(message),
                    icon: const Icon(LucideIcons.pencil, size: 17),
                  ),
                IconButton(
                  tooltip: 'Copiar mensaje',
                  visualDensity: VisualDensity.compact,
                  onPressed: () => onCopy(message),
                  icon: const Icon(LucideIcons.copy, size: 17),
                ),
                if (!isUser) ...[
                  IconButton(
                    tooltip: 'Me gustó esta respuesta',
                    visualDensity: VisualDensity.compact,
                    onPressed: () => onFeedback(message, 'positive'),
                    icon: const Icon(LucideIcons.thumbsUp, size: 17),
                  ),
                  IconButton(
                    tooltip: 'No me ayudó',
                    visualDensity: VisualDensity.compact,
                    onPressed: () => onFeedback(message, 'negative'),
                    icon: const Icon(LucideIcons.thumbsDown, size: 17),
                  ),
                ],
              ],
            ),
          ],
        ),
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
    required this.overthink,
    required this.pendingAttachments,
    required this.onRemoveAttachment,
    required this.onToggleOverthink,
    required this.onCancel,
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
  final bool overthink;
  final List<PendingAttachment> pendingAttachments;
  final ValueChanged<PendingAttachment> onRemoveAttachment;
  final VoidCallback onToggleOverthink;
  final VoidCallback onCancel;
  final ValueChanged<String> onModeChange;
  final VoidCallback onSend;
  final VoidCallback onMicTap;
  final VoidCallback onAttachTap;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final palette = ref.watch(appPaletteProvider);

    return Padding(
      padding: const EdgeInsets.fromLTRB(12, 4, 12, 12),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (pendingAttachments.isNotEmpty)
            Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: Align(
                alignment: Alignment.centerLeft,
                child: Wrap(
                  spacing: 7,
                  runSpacing: 7,
                  children: pendingAttachments.map((file) {
                    return InputChip(
                      avatar: const Icon(LucideIcons.fileText, size: 16),
                      label: Text(file.name, overflow: TextOverflow.ellipsis),
                      onDeleted: () => onRemoveAttachment(file),
                    );
                  }).toList(),
                ),
              ),
            ),
          if (overthink)
            Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: Align(
                alignment: Alignment.centerLeft,
                child: ActionChip(
                  avatar: const Icon(LucideIcons.brain, size: 16),
                  label: const Text('Sobrepensar activado'),
                  onPressed: onToggleOverthink,
                ),
              ),
            ),
          if (availableModes.length > 1)
            Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                child: Row(
                  children: availableModes.map((mode) {
                    return Padding(
                      padding: const EdgeInsets.only(right: 6),
                      child: _ModeChip(
                        label: mode.label,
                        selected: modeId == mode.id,
                        onTap: () => onModeChange(mode.id),
                      ),
                    );
                  }).toList(),
                ),
              ),
            ),
          AnimatedContainer(
            duration: const Duration(milliseconds: 220),
            curve: Curves.easeOutCubic,
            padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 3),
            decoration: BoxDecoration(
              color: palette.surface,
              borderRadius: BorderRadius.circular(30),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(
                    alpha: isListening ? 0.10 : 0.05,
                  ),
                  blurRadius: isListening ? 22 : 12,
                  offset: const Offset(0, 4),
                ),
              ],
            ),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Padding(
                  padding: const EdgeInsets.only(left: 2, bottom: 1),
                  child: IconButton(
                    tooltip: 'Más herramientas',
                    onPressed: isAttaching ? null : onAttachTap,
                    icon: AnimatedSwitcher(
                      duration: const Duration(milliseconds: 180),
                      child: isAttaching
                          ? const SizedBox(
                              key: ValueKey('loading'),
                              width: 19,
                              height: 19,
                              child: CircularProgressIndicator(strokeWidth: 2),
                            )
                          : const Icon(key: ValueKey('plus'), LucideIcons.plus),
                    ),
                  ),
                ),
                Expanded(
                  child: TextField(
                    controller: controller,
                    enabled: !isSending,
                    minLines: 1,
                    maxLines: 6,
                    keyboardType: TextInputType.multiline,
                    textInputAction: TextInputAction.newline,
                    cursorColor: palette.accent,
                    style: TextStyle(
                      color: palette.textPrimary,
                      fontSize: 16,
                      height: 1.4,
                    ),
                    decoration: InputDecoration(
                      hintText: context.l10n.askSomething,
                      hintStyle: TextStyle(
                        color: palette.textSecondary.withValues(alpha: 0.72),
                      ),
                      border: InputBorder.none,
                      enabledBorder: InputBorder.none,
                      focusedBorder: InputBorder.none,
                      disabledBorder: InputBorder.none,
                      errorBorder: InputBorder.none,
                      focusedErrorBorder: InputBorder.none,
                      isCollapsed: true,
                      contentPadding: const EdgeInsets.symmetric(
                        horizontal: 8,
                        vertical: 14,
                      ),
                    ),
                  ),
                ),
                VoiceInputButton(
                  isListening: isListening,
                  enabled: !isSending,
                  color: palette.accent,
                  onTap: onMicTap,
                ),
                Padding(
                  padding: const EdgeInsets.only(right: 2, bottom: 1),
                  child: IconButton.filled(
                    tooltip: isSending
                        ? 'Detener generación'
                        : 'Enviar mensaje',
                    onPressed: isSending ? onCancel : onSend,
                    icon: AnimatedSwitcher(
                      duration: const Duration(milliseconds: 180),
                      transitionBuilder: (child, animation) {
                        return ScaleTransition(
                          scale: animation,
                          child: FadeTransition(
                            opacity: animation,
                            child: child,
                          ),
                        );
                      },
                      child: Icon(
                        isSending ? LucideIcons.square : LucideIcons.arrowUp,
                        key: ValueKey(isSending),
                        size: 20,
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

class _ThinkingMessage extends StatefulWidget {
  const _ThinkingMessage();

  @override
  State<_ThinkingMessage> createState() => _ThinkingMessageState();
}

class _ThinkingMessageState extends State<_ThinkingMessage>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 900),
  )..repeat();

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(18, 12, 18, 18),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: List.generate(3, (index) {
          return AnimatedBuilder(
            animation: _controller,
            builder: (context, child) {
              final phase = (_controller.value * 3 - index) % 3;

              final opacity =
                  0.35 + (0.65 * (1 - (phase - 1).abs().clamp(0.0, 1.0)));

              final offsetY = -3 * (1 - (phase - 1).abs().clamp(0.0, 1.0));

              return Transform.translate(
                offset: Offset(0, offsetY),
                child: Opacity(
                  opacity: opacity,
                  child: Container(
                    width: 7,
                    height: 7,
                    margin: const EdgeInsets.symmetric(horizontal: 3),
                    decoration: BoxDecoration(
                      color: Theme.of(context).colorScheme.onSurface,
                      shape: BoxShape.circle,
                    ),
                  ),
                ),
              );
            },
          );
        }),
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
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        curve: Curves.easeOutCubic,
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 7),
        decoration: BoxDecoration(
          color: selected
              ? palette.surfaceAlt
              : palette.surface.withValues(alpha: 0.6),
          borderRadius: BorderRadius.circular(16),
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
