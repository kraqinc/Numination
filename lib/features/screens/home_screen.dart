import 'dart:io';
import 'dart:math' as math;

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lucide_flutter/lucide_flutter.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:speech_to_text/speech_to_text.dart' as stt;

import '../../core/ai_modes_controller.dart';
import '../../core/api.dart';
import '../../core/auth_controller.dart';
import '../../core/error_messages.dart';
import '../../core/l10n_extensions.dart';
import '../../core/models.dart';
import '../../core/theme_controller.dart';
import '../../core/update_service.dart';
import '../widgets/ai_response.dart';
import '../widgets/hamburger.dart';
import '../widgets/search_chats.dart';
import '../widgets/voice_input_button.dart';
import 'coder_chat_screen.dart' as coder_chat;
import 'coder_screen.dart' as coder;
import 'ghost_chat.dart';

class ChatMessage {
  final String text;
  final bool fromUser;
  final String? id;
  final String? chatId;
  final bool memorySaved;
  final String? imageUrl;
  final String? memoryId;
  final String? memoryTitle;
  final String? memoryContent;

  const ChatMessage({
    required this.text,
    required this.fromUser,
    this.id,
    this.chatId,
    this.memorySaved = false,
    this.imageUrl,
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

class _PromptStarter {
  const _PromptStarter({
    required this.label,
    required this.icon,
    required this.prompt,
  });

  final String label;
  final IconData icon;
  final String prompt;
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
  final _scaffoldKey = GlobalKey<ScaffoldState>();
  final FocusNode _messageFocusNode = FocusNode();
  final stt.SpeechToText _speech = stt.SpeechToText();

  String _composerHint = '¿Qué quieres resolver hoy?';
  bool _webSearchForNextMessage = false;
  bool _toolsExpanded = false;
  bool _imageGenerationForNextMessage = false;

  static const _hintPreferenceKey = 'numination.lastComposerHintIndex';

  static const _composerHintsEs = <String>[
    '¿Qué quieres resolver hoy?',
    'Explícame una idea con un ejemplo.',
    'Ayúdame a escribir algo con claridad.',
    'Resume este tema sin perder lo importante.',
    'Enséñame paso a paso.',
    'Revisa este código y detecta errores.',
    'Ayúdame a entender este mensaje de error.',
    'Dame ideas para iniciar un proyecto.',
    'Compara estas opciones con pros y contras.',
    'Organiza estas tareas por prioridad.',
    'Convierte estas notas en un plan.',
    'Prepárame preguntas para practicar.',
    'Explícame este concepto desde cero.',
    'Ayúdame a encontrar una solución práctica.',
    'Mejora la claridad de este texto.',
    'Extrae las ideas principales.',
    'Ayúdame a preparar una presentación.',
    'Diseña un esquema antes de empezar.',
    'Simplifica este fragmento de código.',
    'Revisa la lógica de esta propuesta.',
    'Ayúdame a aprender algo nuevo.',
    'Divide esta meta en pasos concretos.',
    'Sugiere mejoras para mi proyecto.',
    'Guíame para depurar este problema.',
    '¿Por dónde empezamos?',
  ];

  static const _composerHintsEn = <String>[
    'What would you like to solve today?',
    'Explain an idea with a simple example.',
    'Help me write this more clearly.',
    'Summarize this without losing key details.',
    'Teach me step by step.',
    'Review this code and find errors.',
    'Help me understand this error message.',
    'Give me ideas for a new project.',
    'Compare these options and their trade-offs.',
    'Help me prioritize these tasks.',
    'Turn these notes into a plan.',
    'Create practice questions for me.',
    'Explain this concept from scratch.',
    'Help me find a practical solution.',
    'Make this text clearer.',
    'Extract the main ideas.',
    'Help me prepare a presentation.',
    'Create an outline before we begin.',
    'Simplify this code snippet.',
    'Check the logic of this idea.',
    'Help me learn something new.',
    'Break this goal into concrete steps.',
    'Suggest improvements for my project.',
    'Guide me through debugging this issue.',
    'Where should we start?',
  ];

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
  bool _isLoadingHistory = false;
  int _chatLoadRevision = 0;
  String? _animatedAssistantMessageId;

  AppUser? _profile;
  int _chatRevision = 0;

  @override
  void initState() {
    super.initState();
    _rotateComposerHint();
    UpdateService.startAutomaticChecks();

    WidgetsBinding.instance.addObserver(this);

    _initSpeech();
    _loadProfile();

    WidgetsBinding.instance.addPostFrameCallback((_) async {
      if (!mounted) return;

      final openedSettings = await UpdateService.promptForAutoUpdatesPermission(
        context,
      );

      if (!mounted || openedSettings) return;

      await UpdateService.checkAndInstallIfEnabled();
    });
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      UpdateService.resumeAfterInstallPermission().then((_) {
        if (mounted) {
          UpdateService.checkAndInstallIfEnabled();
        }
      });
    }
  }

  Future<void> _rotateComposerHint() async {
    final hints = AppErrorMessages.isEnglish
        ? _composerHintsEn
        : _composerHintsEs;

    try {
      final prefs = await SharedPreferences.getInstance();
      final previous = prefs.getInt(_hintPreferenceKey) ?? -1;

      final choices = List<int>.generate(
        hints.length,
        (index) => index,
      ).where((index) => index != previous).toList();

      final next = choices.isEmpty
          ? math.Random().nextInt(hints.length)
          : choices[math.Random().nextInt(choices.length)];

      await prefs.setInt(_hintPreferenceKey, next);

      if (!mounted) return;
      setState(() => _composerHint = hints[next]);
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _composerHint = hints[math.Random().nextInt(hints.length)];
      });
    }
  }

  List<_PromptStarter> get _promptStarters {
    final english = AppErrorMessages.isEnglish;

    return [
      _PromptStarter(
        label: english ? 'Write code' : 'Escribir código',
        icon: LucideIcons.code2,
        prompt: english
            ? 'Help me write and improve a clear, maintainable code solution.'
            : 'Ayúdame a escribir y mejorar una solución de código clara y mantenible.',
      ),
      _PromptStarter(
        label: english ? 'Explain a concept' : 'Explicar un concepto',
        icon: LucideIcons.messageCircle,
        prompt: english
            ? 'Explain this concept step by step using a practical example.'
            : 'Explícame este concepto paso a paso con un ejemplo práctico.',
      ),
      _PromptStarter(
        label: english ? 'Plan a project' : 'Planificar un proyecto',
        icon: LucideIcons.lightbulb,
        prompt: english
            ? 'Help me plan a project with clear steps and priorities.'
            : 'Ayúdame a planificar un proyecto con pasos y prioridades claras.',
      ),
    ];
  }

  void _selectPromptStarter(_PromptStarter starter) {
    final prompt = starter.prompt;
    final placeholder = RegExp(r'\[[^\]]+\]').firstMatch(prompt);

    setState(() {
      _webSearchForNextMessage = false;
      _imageGenerationForNextMessage = false;

      _messageController.value = TextEditingValue(
        text: prompt,
        selection: placeholder == null
            ? TextSelection.collapsed(offset: prompt.length)
            : TextSelection(
                baseOffset: placeholder.start,
                extentOffset: placeholder.end,
              ),
      );
    });

    _messageFocusNode.requestFocus();
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

        const preferred = <String>['es_CO', 'es_ES', 'es_MX', 'es_US'];

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
    UpdateService.stopAutomaticChecks();
    _messageController.dispose();
    _scrollController.dispose();
    _messageFocusNode.dispose();
    _speech.stop();
    super.dispose();
  }

  void _toggleMode(String modeId) {
    if (modeId == 'coder') {
      _generationToken?.cancel();
      _chatLoadRevision++;

      if (mounted) {
        setState(() {
          _isSending = false;
          _isLoadingHistory = false;
          _generationToken = null;
        });
      }

      if (_scaffoldKey.currentState?.isDrawerOpen == true) {
        Navigator.of(context).pop();
      }

      Navigator.of(context)
          .push<void>(
            MaterialPageRoute<void>(builder: (_) => const coder.CoderScreen()),
          )
          .then((_) {
            if (mounted) setState(() => _chatRevision++);
          });

      return;
    }

    if (modeId == _modeId) return;

    _generationToken?.cancel();
    _chatLoadRevision++;

    setState(() {
      _modeId = modeId;
      _activeChatId = null;
      _messages.clear();
      _isSending = false;
      _isLoadingHistory = false;
      _generationToken = null;
      _animatedAssistantMessageId = null;
    });
  }

  void _startNewChat() {
    _generationToken?.cancel();
    _chatLoadRevision++;

    setState(() {
      _activeChatId = null;
      _messages.clear();
      _messageController.clear();
      _pendingAttachments.clear();
      _isSending = false;
      _isLoadingHistory = false;
      _generationToken = null;
      _animatedAssistantMessageId = null;
    });

    _scrollToBottom();
  }

  void _onChatDeleted(ChatSession chat) {
    if (_activeChatId != chat.id) return;

    _generationToken?.cancel();
    _chatLoadRevision++;

    setState(() {
      _activeChatId = null;
      _messages.clear();
      _isSending = false;
      _isLoadingHistory = false;
      _generationToken = null;
      _animatedAssistantMessageId = null;
    });
  }

  Future<void> _openChat(ChatSession chat) async {
    _generationToken?.cancel();
    _generationToken = null;
    final loadRevision = ++_chatLoadRevision;

    if (chat.mode.toLowerCase() == 'coder') {
      final projectId = chat.projectId;

      if (projectId == null || projectId.isEmpty) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text(
                'Esta conversación Coder no tiene un proyecto asociado.',
              ),
            ),
          );
        }
        return;
      }

      if (mounted) {
        setState(() {
          _isSending = false;
          _isLoadingHistory = false;
          _animatedAssistantMessageId = null;
        });
      }

      var projectName = 'Proyecto';

      try {
        final response = await ApiClient.get('/projects');
        final data = ApiClient.decode(response) as Map<String, dynamic>;

        final projects = (data['projects'] as List? ?? []).whereType<Map>().map(
          (row) => Project.fromJson(Map<String, dynamic>.from(row)),
        );

        for (final project in projects) {
          if (project.id == projectId) {
            projectName = project.name;
            break;
          }
        }
      } catch (_) {
        // Abrir el historial no debe depender del nombre del proyecto.
      }

      if (!mounted || loadRevision != _chatLoadRevision) return;

      await Navigator.of(context).push<void>(
        MaterialPageRoute<void>(
          builder: (_) => coder_chat.CoderChatScreen(
            projectId: projectId,
            projectName: projectName,
            chatId: chat.id,
          ),
        ),
      );

      if (mounted) setState(() => _chatRevision++);
      return;
    }

    setState(() {
      _activeChatId = chat.id;
      _modeId = chat.mode;
      _messages.clear();
      _isLoadingHistory = true;
      _isSending = false;
      _animatedAssistantMessageId = null;
    });

    try {
      final encodedChatId = Uri.encodeComponent(chat.id);
      final response = await ApiClient.get('/chats/$encodedChatId/messages');
      final data = ApiClient.decode(response) as Map<String, dynamic>;

      final list = (data['messages'] as List? ?? [])
          .map(
            (row) =>
                ChatMessageDto.fromJson(Map<String, dynamic>.from(row as Map)),
          )
          .toList();

      if (!mounted ||
          loadRevision != _chatLoadRevision ||
          _activeChatId != chat.id) {
        return;
      }

      setState(() {
        _isLoadingHistory = false;
        _messages
          ..clear()
          ..addAll(
            list.map((message) {
              const imageMarker = '[[NUMINATION_IMAGE]]\n';
              final isGeneratedImage =
                  message.role != 'user' &&
                  message.content.startsWith(imageMarker);
              final imageUrl = isGeneratedImage
                  ? message.content.substring(imageMarker.length).trim()
                  : null;

              return ChatMessage(
                text: isGeneratedImage ? '' : message.content,
                fromUser: message.role == 'user',
                id: message.id,
                chatId: message.chatId,
                imageUrl: imageUrl != null && imageUrl.isNotEmpty
                    ? imageUrl
                    : null,
              );
            }),
          );
      });

      _scrollToBottom();
    } catch (_) {
      if (!mounted ||
          loadRevision != _chatLoadRevision ||
          _activeChatId != chat.id) {
        return;
      }

      setState(() {
        _isLoadingHistory = false;
        _messages
          ..clear()
          ..add(
            const ChatMessage(
              text:
                  'No pudimos cargar este chat. Comprueba la conexión e inténtalo de nuevo.',
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
    ).push(MaterialPageRoute<void>(builder: (_) => const GhostChatScreen()));
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

  Future<void> _attachFile() async {
    if (_isAttaching) return;

    final picked = await FilePicker.pickFile();

    if (picked == null || picked.path == null) return;

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

    if ((text.isEmpty && attachments.isEmpty) || _isSending) return;

    final useImageGeneration = _imageGenerationForNextMessage;
    final useWebSearch = _webSearchForNextMessage && !useImageGeneration;
    final visibleText = text.isEmpty ? 'Revisa los archivos adjuntos.' : text;

    if (useImageGeneration && visibleText.length > 1800) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            AppErrorMessages.isEnglish
                ? 'Image prompts must be 1800 characters or fewer.'
                : 'El prompt de imagen debe tener máximo 1800 caracteres.',
          ),
        ),
      );
      return;
    }

    final attachmentContext = attachments
        .map((file) => '--- ${file.name} ---\n${file.content}')
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
      _animatedAssistantMessageId = null;
      _webSearchForNextMessage = false;
      _imageGenerationForNextMessage = false;
    });

    _scrollToBottom();

    String? requestChatId = _activeChatId;
    var createdChat = false;
    var assistantIndex = -1;
    var responseText = '';
    var streamCompleted = false;

    try {
      if (requestChatId == null) {
        final createRes = await ApiClient.post('/chats', {
          'title': visibleText.length > 40
              ? '${visibleText.substring(0, 40)}...'
              : visibleText,
          'mode': _modeId,
        });

        final createData = ApiClient.decode(createRes) as Map<String, dynamic>;
        final chat = Map<String, dynamic>.from(createData['chat'] as Map);

        requestChatId = '${chat['id']}';
        createdChat = true;

        if (token.isCancelled ||
            !mounted ||
            !identical(_generationToken, token)) {
          if (responseText.isEmpty) {
            await _discardEmptyChat(requestChatId);
          }
          throw const ApiRequestCancelled();
        }

        setState(() {
          _activeChatId = requestChatId;
          _chatRevision++;
        });
      }

      final chatId = requestChatId;

      if (token.isCancelled ||
          !mounted ||
          !identical(_generationToken, token) ||
          _activeChatId != chatId) {
        throw const ApiRequestCancelled();
      }

      if (useImageGeneration) {
        final imageResponse = await ApiClient.postCancelable(
          '/ai/images/generate',
          {'prompt': visibleText, 'chatId': chatId},
          token,
          timeout: const Duration(seconds: 110),
        );

        final imageData = Map<String, dynamic>.from(
          ApiClient.decode(imageResponse) as Map,
        );
        final generatedImageUrl = imageData['imageUrl']?.toString().trim();

        if (imageData['success'] != true ||
            generatedImageUrl == null ||
            generatedImageUrl.isEmpty) {
          throw const ApiException(
            502,
            'El servidor no devolvió una imagen válida. Inténtalo de nuevo.',
          );
        }

        if (token.isCancelled ||
            !mounted ||
            !identical(_generationToken, token) ||
            _activeChatId != chatId) {
          throw const ApiRequestCancelled();
        }

        final userMessageId = imageData['userMessageId']?.toString();
        final assistantMessageId = imageData['assistantMessageId']?.toString();
        responseText = AppErrorMessages.isEnglish
            ? 'Image generated successfully.'
            : 'Imagen generada correctamente.';
        streamCompleted = true;

        setState(() {
          if (userMessageIndex >= 0 && userMessageIndex < _messages.length) {
            final old = _messages[userMessageIndex];
            _messages[userMessageIndex] = ChatMessage(
              text: old.text,
              fromUser: true,
              id: userMessageId,
              chatId: chatId,
            );
          }

          _messages.add(
            ChatMessage(
              text: responseText,
              fromUser: false,
              id: assistantMessageId,
              chatId: chatId,
              imageUrl: generatedImageUrl,
            ),
          );
          _animatedAssistantMessageId = assistantMessageId;
          _chatRevision++;
        });

        _scrollToBottom();
        return;
      }

      assistantIndex = _messages.length;

      setState(() {
        _messages.add(ChatMessage(text: '', fromUser: false, chatId: chatId));
      });

      _scrollToBottom();

      await for (final event in ApiClient.postSse('/ai/chat/stream', {
        'prompt': effectivePrompt,
        'mode': _modeId,
        'chatId': chatId,
        'overthink': _overthink,
        'webSearch': useWebSearch,
      }, token)) {
        if (token.isCancelled) throw const ApiRequestCancelled();

        final eventName = event['event']?.toString() ?? 'message';
        final rawPayload = event['data'];

        final payload = rawPayload is Map
            ? Map<String, dynamic>.from(rawPayload)
            : <String, dynamic>{};

        if (eventName == 'token') {
          final delta = payload['delta']?.toString() ?? '';
          if (delta.isEmpty) continue;

          responseText += delta;

          if (mounted &&
              !token.isCancelled &&
              identical(_generationToken, token) &&
              _activeChatId == chatId) {
            setState(() {
              if (assistantIndex >= 0 && assistantIndex < _messages.length) {
                _messages[assistantIndex] = ChatMessage(
                  text: responseText,
                  fromUser: false,
                  chatId: chatId,
                );
              }
            });

            _scrollToBottom();
          }
        } else if (eventName == 'done') {
          streamCompleted = true;

          final completeText = payload['response']?.toString();
          if (completeText != null && completeText.isNotEmpty) {
            responseText = completeText;
          }

          final userId = payload['userMessageId']?.toString();
          final assistantId = payload['assistantMessageId']?.toString();

          if (mounted &&
              !token.isCancelled &&
              identical(_generationToken, token) &&
              _activeChatId == chatId) {
            setState(() {
              if (userMessageIndex >= 0 &&
                  userMessageIndex < _messages.length) {
                final old = _messages[userMessageIndex];

                _messages[userMessageIndex] = ChatMessage(
                  text: old.text,
                  fromUser: true,
                  id: userId,
                  chatId: chatId,
                );
              }

              if (assistantIndex >= 0 && assistantIndex < _messages.length) {
                _messages[assistantIndex] = ChatMessage(
                  text: responseText,
                  fromUser: false,
                  id: assistantId,
                  chatId: chatId,
                  memorySaved: payload['memorySaved'] == true,
                  memoryId: payload['memoryId']?.toString(),
                  memoryTitle: payload['memoryTitle']?.toString(),
                  memoryContent: payload['memoryContent']?.toString(),
                );
              }

              _animatedAssistantMessageId = assistantId;

              if (payload['chatTitle']?.toString().trim().isNotEmpty == true) {
                _chatRevision++;
              }
            });
          }
        } else if (eventName == 'error') {
          throw ApiException(
            503,
            ApiClient.friendlyMessage(
              503,
              payload['error']?.toString(),
              code: payload['code']?.toString(),
            ),
          );
        }
      }

      if (!streamCompleted) {
        throw const ApiException(
          502,
          'La respuesta se interrumpió antes de terminar. Inténtalo de nuevo.',
        );
      }

      if (responseText.trim().isEmpty) {
        throw const ApiException(
          502,
          'La IA devolvió una respuesta vacía. Inténtalo de nuevo.',
        );
      }
    } on ApiRequestCancelled {
      if (createdChat &&
          requestChatId != null &&
          !streamCompleted &&
          _activeChatId != requestChatId) {
        await _discardEmptyChat(requestChatId);
      }

      if (mounted &&
          _activeChatId == requestChatId &&
          assistantIndex >= 0 &&
          assistantIndex < _messages.length &&
          _messages[assistantIndex].text.isEmpty) {
        setState(() => _messages.removeAt(assistantIndex));
      }
    } on ApiException catch (e) {
      if (createdChat &&
          requestChatId != null &&
          !streamCompleted &&
          _activeChatId != requestChatId) {
        await _discardEmptyChat(requestChatId);
      }

      if (!mounted || token.isCancelled || _activeChatId != requestChatId) {
        return;
      }

      final failureText = responseText.isEmpty
          ? 'Numi no pudo responder en este momento. ${e.message}'
          : '$responseText\n\n${AppErrorMessages.streamInterrupted}';

      setState(() {
        final failure = ChatMessage(
          text: failureText,
          fromUser: false,
          chatId: requestChatId,
        );

        if (assistantIndex >= 0 && assistantIndex < _messages.length) {
          _messages[assistantIndex] = failure;
        } else {
          _messages.add(failure);
        }
      });
    } catch (_) {
      if (createdChat &&
          requestChatId != null &&
          !streamCompleted &&
          _activeChatId != requestChatId) {
        await _discardEmptyChat(requestChatId);
      }

      if (!mounted || token.isCancelled || _activeChatId != requestChatId) {
        return;
      }

      setState(() {
        final failure = ChatMessage(
          text: responseText.isEmpty
              ? AppErrorMessages.aiUnavailable
              : '$responseText\n\n${AppErrorMessages.streamInterrupted}',
          fromUser: false,
          chatId: requestChatId,
        );

        if (assistantIndex >= 0 && assistantIndex < _messages.length) {
          _messages[assistantIndex] = failure;
        } else {
          _messages.add(failure);
        }
      });
    } finally {
      if (mounted && identical(_generationToken, token)) {
        setState(() {
          _isSending = false;
          _generationToken = null;
        });
      }

      _scrollToBottom();
    }
  }

  Future<void> _discardEmptyChat(String chatId) async {
    try {
      await ApiClient.delete('/chats/${Uri.encodeComponent(chatId)}');
    } catch (_) {
      // La limpieza no debe ocultar el error original.
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

    _messageFocusNode.requestFocus();
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

      if (note == null) return;
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
          !list.any((mode) => mode.id == _modeId)) {
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
              child: _isLoadingHistory
                  ? const Center(child: CircularProgressIndicator())
                  : _messages.isEmpty
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
                          animateCharacters:
                              !message.fromUser &&
                              (message.id == null ||
                                  message.id == _animatedAssistantMessageId),
                          onCopy: _copyMessage,
                          onEdit: _editMessage,
                          onFeedback: _sendFeedback,
                        );
                      },
                    ),
            ),
            _BottomInputBar(
              controller: _messageController,
              focusNode: _messageFocusNode,
              modeId: _modeId,
              availableModes: availableModes,
              isSending: _isSending,
              isListening: _isListening,
              isAttaching: _isAttaching,
              overthink: _overthink,
              pendingAttachments: _pendingAttachments,
              hintText: _composerHint,
              webSearchEnabled: _webSearchForNextMessage,
              imageGenerationEnabled: _imageGenerationForNextMessage,
              showPromptStarters: !_isLoadingHistory && _messages.isEmpty,
              promptStarters: _promptStarters,
              onRemoveAttachment: (file) {
                setState(() {
                  _pendingAttachments.remove(file);
                });
              },
              onToggleOverthink: () {
                setState(() {
                  final enable = !_overthink;
                  _overthink = enable;
                  if (enable) {
                    _webSearchForNextMessage = false;
                    _imageGenerationForNextMessage = false;
                  }
                });
              },
              toolsExpanded: _toolsExpanded,
              onToggleTools: () {
                setState(() {
                  _toolsExpanded = !_toolsExpanded;
                });
              },
              onToggleWebSearch: () {
                setState(() {
                  final enable = !_webSearchForNextMessage;
                  _webSearchForNextMessage = enable;
                  if (enable) {
                    _imageGenerationForNextMessage = false;
                    _overthink = false;
                  }
                });
              },
              onToggleImageGeneration: () {
                setState(() {
                  final enable = !_imageGenerationForNextMessage;
                  _imageGenerationForNextMessage = enable;
                  if (enable) {
                    _webSearchForNextMessage = false;
                    _overthink = false;
                  }
                });
              },
              onPromptSelected: _selectPromptStarter,
              onCancel: _cancelGeneration,
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
      padding: const EdgeInsets.fromLTRB(12, 10, 12, 8),
      child: Row(
        children: [
          GestureDetector(
            onTap: onMenuTap,
            behavior: HitTestBehavior.opaque,
            child: Padding(
              padding: const EdgeInsets.all(8),
              child: Icon(
                LucideIcons.menu,
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
                      LucideIcons.search,
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
                LucideIcons.sparkles,
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
    this.animateCharacters = false,
    required this.onCopy,
    required this.onEdit,
    required this.onFeedback,
  });

  final ChatMessage message;
  final bool animateCharacters;
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
        margin: EdgeInsets.symmetric(vertical: 5, horizontal: isUser ? 0 : 12),
        constraints: BoxConstraints(
          maxWidth: MediaQuery.of(context).size.width * (isUser ? 0.88 : 0.94),
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
            if (message.imageUrl?.isNotEmpty == true) ...[
              ClipRRect(
                borderRadius: BorderRadius.circular(16),
                child: Container(
                  color: palette.surface,
                  child: Image.network(
                    message.imageUrl!,
                    width: MediaQuery.of(context).size.width * 0.82,
                    fit: BoxFit.contain,
                    loadingBuilder: (context, child, progress) {
                      if (progress == null) return child;
                      final total = progress.expectedTotalBytes;
                      return SizedBox(
                        height: 220,
                        child: Center(
                          child: CircularProgressIndicator(
                            value: total == null
                                ? null
                                : progress.cumulativeBytesLoaded / total,
                          ),
                        ),
                      );
                    },
                    errorBuilder: (context, error, stackTrace) {
                      return Container(
                        width: MediaQuery.of(context).size.width * 0.82,
                        padding: const EdgeInsets.all(20),
                        child: Text(
                          AppErrorMessages.isEnglish
                              ? 'This image could not be loaded. Try generating it again.'
                              : 'No pudimos cargar esta imagen. Intenta generarla de nuevo.',
                          style: TextStyle(color: palette.textSecondary),
                        ),
                      );
                    },
                  ),
                ),
              ),
              if (message.text.trim().isNotEmpty)
                Padding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 4,
                    vertical: 6,
                  ),
                  child: AiResponse(text: message.text),
                ),
            ] else if (isUser)
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 12,
                ),
                decoration: BoxDecoration(
                  color: palette.accent.withValues(alpha: 0.14),
                  borderRadius: BorderRadius.circular(18),
                  border: Border.all(
                    color: palette.accent.withValues(alpha: 0.25),
                  ),
                ),
                child: AiResponse(text: message.text),
              )
            else
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 6),
                child: AiResponse(
                  text: message.text,
                  animateCharacters: animateCharacters,
                ),
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
    required this.focusNode,
    required this.modeId,
    required this.availableModes,
    required this.isSending,
    required this.isListening,
    required this.isAttaching,
    required this.overthink,
    required this.pendingAttachments,
    required this.hintText,
    required this.webSearchEnabled,
    required this.imageGenerationEnabled,
    required this.toolsExpanded,
    required this.onToggleTools,
    required this.showPromptStarters,
    required this.promptStarters,
    required this.onRemoveAttachment,
    required this.onToggleOverthink,
    required this.onToggleWebSearch,
    required this.onToggleImageGeneration,
    required this.onPromptSelected,
    required this.onCancel,
    required this.onModeChange,
    required this.onSend,
    required this.onMicTap,
    required this.onAttachTap,
  });

  final TextEditingController controller;
  final FocusNode focusNode;
  final String modeId;
  final List<AiModeConfig> availableModes;
  final bool isSending;
  final bool isListening;
  final bool isAttaching;
  final bool overthink;
  final List<PendingAttachment> pendingAttachments;
  final String hintText;
  final bool webSearchEnabled;
  final bool imageGenerationEnabled;
  final bool toolsExpanded;
  final bool showPromptStarters;
  final List<_PromptStarter> promptStarters;
  final ValueChanged<PendingAttachment> onRemoveAttachment;
  final VoidCallback onToggleOverthink;
  final VoidCallback onToggleWebSearch;
  final VoidCallback onToggleImageGeneration;
  final ValueChanged<_PromptStarter> onPromptSelected;
  final VoidCallback onToggleTools;
  final VoidCallback onCancel;
  final ValueChanged<String> onModeChange;
  final VoidCallback onSend;
  final VoidCallback onMicTap;
  final VoidCallback onAttachTap;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final palette = ref.watch(appPaletteProvider);
    final english = AppErrorMessages.isEnglish;

    final hasActiveTool =
        webSearchEnabled || imageGenerationEnabled || overthink;

    final IconData? selectedToolIcon = webSearchEnabled
        ? LucideIcons.globe
        : imageGenerationEnabled
        ? LucideIcons.image
        : overthink
        ? LucideIcons.brain
        : null;

    final String? selectedToolName = webSearchEnabled
        ? (english ? 'Search the web' : 'Buscar en la web')
        : imageGenerationEnabled
        ? (english ? 'Generate images' : 'Generar imágenes')
        : overthink
        ? (english ? 'Deep analysis' : 'Análisis profundo')
        : null;

    final toolHeading = english ? 'TOOLS' : 'HERRAMIENTAS';

    Widget toolButton({
      required IconData icon,
      required String label,
      required VoidCallback onPressed,
      bool selected = false,
    }) {
      return Tooltip(
        message: label,
        child: Semantics(
          button: true,
          selected: selected,
          label: label,
          child: Material(
            color: Colors.transparent,
            shape: const CircleBorder(),
            child: InkWell(
              customBorder: const CircleBorder(),
              onTap: onPressed,
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 180),
                curve: Curves.easeOutCubic,
                width: 44,
                height: 44,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: selected
                      ? palette.accent.withValues(alpha: 0.15)
                      : palette.surfaceAlt,
                  border: Border.all(
                    color: selected
                        ? palette.accent.withValues(alpha: 0.8)
                        : palette.textSecondary.withValues(alpha: 0.18),
                    width: selected ? 1.4 : 1,
                  ),
                  boxShadow: selected
                      ? [
                          BoxShadow(
                            color: palette.accent.withValues(alpha: 0.17),
                            blurRadius: 12,
                            spreadRadius: 1,
                          ),
                        ]
                      : const [],
                ),
                child: Icon(
                  icon,
                  size: 19,
                  color: selected
                      ? palette.accent
                      : palette.textSecondary,
                ),
              ),
            ),
          ),
        ),
      );
    }

    void closeTools() {
      if (toolsExpanded) onToggleTools();
    }

    return Padding(
      padding: const EdgeInsets.fromLTRB(12, 4, 12, 12),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (showPromptStarters)
            Padding(
              padding: const EdgeInsets.only(bottom: 10),
              child: SizedBox(
                height: 40,
                child: ListView.separated(
                  scrollDirection: Axis.horizontal,
                  itemCount: promptStarters.length,
                  separatorBuilder: (_, index) => const SizedBox(width: 7),
                  itemBuilder: (context, index) {
                    final starter = promptStarters[index];
                    return ActionChip(
                      avatar: Icon(starter.icon, size: 16),
                      label: Text(starter.label),
                      onPressed: () => onPromptSelected(starter),
                    );
                  },
                ),
              ),
            ),
          AnimatedContainer(
            duration: const Duration(milliseconds: 220),
            curve: Curves.easeOutCubic,
            padding: const EdgeInsets.fromLTRB(8, 5, 5, 5),
            decoration: BoxDecoration(
              color: palette.surface,
              borderRadius: BorderRadius.circular(24),
              border: Border.all(
                color: toolsExpanded || hasActiveTool
                    ? palette.accent.withValues(alpha: 0.38)
                    : palette.textSecondary.withValues(alpha: 0.16),
              ),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(
                    alpha: isListening ? 0.10 : 0.045,
                  ),
                  blurRadius: isListening ? 20 : 12,
                  offset: const Offset(0, 4),
                ),
              ],
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                if (pendingAttachments.isNotEmpty)
                  Padding(
                    padding: const EdgeInsets.fromLTRB(5, 6, 5, 8),
                    child: Wrap(
                      spacing: 7,
                      runSpacing: 6,
                      children: pendingAttachments.map((file) {
                        return InputChip(
                          avatar: const Icon(LucideIcons.fileText, size: 16),
                          label: Text(
                            file.name,
                            overflow: TextOverflow.ellipsis,
                          ),
                          onDeleted: () => onRemoveAttachment(file),
                        );
                      }).toList(),
                    ),
                  ),
                if (toolsExpanded || hasActiveTool)
                  Padding(
                    padding: const EdgeInsets.fromLTRB(7, 5, 5, 8),
                    child: Row(
                      children: [
                        if (toolsExpanded)
                          Text(
                            toolHeading,
                            style: TextStyle(
                              color: palette.accent,
                              fontSize: 10,
                              fontWeight: FontWeight.w700,
                              letterSpacing: 0.8,
                            ),
                          )
                        else if (selectedToolIcon != null)
                          Tooltip(
                            message: selectedToolName ?? toolHeading,
                            child: AnimatedContainer(
                              duration: const Duration(milliseconds: 180),
                              width: 34,
                              height: 34,
                              decoration: BoxDecoration(
                                shape: BoxShape.circle,
                                color: palette.accent.withValues(alpha: 0.13),
                                border: Border.all(
                                  color: palette.accent.withValues(alpha: 0.65),
                                ),
                                boxShadow: [
                                  BoxShadow(
                                    color: palette.accent.withValues(alpha: 0.12),
                                    blurRadius: 10,
                                  ),
                                ],
                              ),
                              child: Icon(
                                selectedToolIcon,
                                size: 17,
                                color: palette.accent,
                              ),
                            ),
                          ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Container(
                            height: 1,
                            color: palette.textSecondary.withValues(
                              alpha: 0.22,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                AnimatedSize(
                  duration: const Duration(milliseconds: 220),
                  curve: Curves.easeOutCubic,
                  alignment: Alignment.topCenter,
                  child: toolsExpanded
                      ? Padding(
                          padding: const EdgeInsets.fromLTRB(4, 0, 4, 10),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Wrap(
                                spacing: 7,
                                runSpacing: 0,
                                children: [
                                  toolButton(
                                    icon: LucideIcons.globe,
                                    label: english
                                        ? 'Search the web'
                                        : 'Buscar en la web',
                                    selected: webSearchEnabled,
                                    onPressed: () {
                                      onToggleWebSearch();
                                      closeTools();
                                    },
                                  ),
                                  toolButton(
                                    icon: LucideIcons.image,
                                    label: english
                                        ? 'Generate images'
                                        : 'Generar imágenes',
                                    selected: imageGenerationEnabled,
                                    onPressed: () {
                                      onToggleImageGeneration();
                                      closeTools();
                                    },
                                  ),
                                  toolButton(
                                    icon: LucideIcons.paperclip,
                                    label: english
                                        ? 'Attach files'
                                        : 'Añadir archivos',
                                    onPressed: () {
                                      closeTools();
                                      onAttachTap();
                                    },
                                  ),
                                  toolButton(
                                    icon: LucideIcons.brain,
                                    label: english
                                        ? 'Deep analysis'
                                        : 'Análisis profundo',
                                    selected: overthink,
                                    onPressed: () {
                                      onToggleOverthink();
                                      closeTools();
                                    },
                                  ),
                                ],
                              ),
                              if (availableModes.length > 1) ...[
                                const SizedBox(height: 12),
                                Text(
                                  english ? 'MODE' : 'MODO',
                                  style: TextStyle(
                                    color: palette.textSecondary,
                                    fontSize: 10,
                                    fontWeight: FontWeight.w700,
                                    letterSpacing: 0.8,
                                  ),
                                ),
                                const SizedBox(height: 7),
                                Wrap(
                                  spacing: 6,
                                  runSpacing: 6,
                                  children: availableModes.map((mode) {
                                    return _ModeChip(
                                      label: mode.label,
                                      selected: modeId == mode.id,
                                      onTap: () {
                                        onModeChange(mode.id);
                                        closeTools();
                                      },
                                    );
                                  }).toList(),
                                ),
                              ],
                            ],
                          ),
                        )
                      : const SizedBox.shrink(),
                ),
                Row(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    SizedBox(
                      width: 42,
                      height: 44,
                      child: IconButton(
                        tooltip: toolsExpanded
                            ? (english ? 'Close tools' : 'Cerrar herramientas')
                            : (english ? 'More tools' : 'Más herramientas'),
                        onPressed: isAttaching ? null : onToggleTools,
                        padding: EdgeInsets.zero,
                        icon: AnimatedSwitcher(
                          duration: const Duration(milliseconds: 180),
                          child: isAttaching
                              ? const SizedBox(
                                  key: ValueKey('loading'),
                                  width: 19,
                                  height: 19,
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2,
                                  ),
                                )
                              : Icon(
                                  toolsExpanded
                                      ? LucideIcons.x
                                      : LucideIcons.plus,
                                  key: ValueKey(toolsExpanded),
                                  color: toolsExpanded
                                      ? palette.accent
                                      : palette.textSecondary,
                                ),
                        ),
                      ),
                    ),
                    Expanded(
                      child: Padding(
                        padding: const EdgeInsets.fromLTRB(3, 9, 3, 11),
                        child: TextField(
                          controller: controller,
                          focusNode: focusNode,
                          enabled: !isSending,
                          minLines: 1,
                          maxLines: 5,
                          keyboardType: TextInputType.multiline,
                          textInputAction: TextInputAction.send,
                          onSubmitted: (_) {
                            if (!isSending) onSend();
                          },
                          cursorColor: palette.accent,
                          style: TextStyle(
                            color: palette.textPrimary,
                            fontSize: 15,
                            height: 1.35,
                          ),
                          decoration: InputDecoration(
                            hintText: hintText,
                            hintMaxLines: 2,
                            hintStyle: TextStyle(
                              color: palette.textSecondary.withValues(
                                alpha: 0.76,
                              ),
                            ),
                            border: InputBorder.none,
                            enabledBorder: InputBorder.none,
                            focusedBorder: InputBorder.none,
                            disabledBorder: InputBorder.none,
                            errorBorder: InputBorder.none,
                            focusedErrorBorder: InputBorder.none,
                            isCollapsed: true,
                            contentPadding: EdgeInsets.zero,
                          ),
                        ),
                      ),
                    ),
                    Padding(
                      padding: const EdgeInsets.only(bottom: 2),
                      child: VoiceInputButton(
                        isListening: isListening,
                        enabled: !isSending,
                        color: palette.accent,
                        onTap: onMicTap,
                      ),
                    ),
                    const SizedBox(width: 3),
                    Padding(
                      padding: const EdgeInsets.only(bottom: 2),
                      child: IconButton.filled(
                        tooltip: isSending
                            ? (english
                                  ? 'Stop generation'
                                  : 'Detener generación')
                            : (english ? 'Send message' : 'Enviar mensaje'),
                        style: IconButton.styleFrom(
                          minimumSize: const Size(44, 44),
                          fixedSize: const Size(44, 44),
                          padding: EdgeInsets.zero,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(13),
                          ),
                        ),
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
                            isSending
                                ? LucideIcons.square
                                : LucideIcons.arrowUp,
                            key: ValueKey(isSending),
                            size: 20,
                          ),
                        ),
                      ),
                    ),
                  ],
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
