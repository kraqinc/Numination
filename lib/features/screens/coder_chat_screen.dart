import 'dart:io';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lucide_flutter/lucide_flutter.dart';
import 'package:path_provider/path_provider.dart';
import 'package:speech_to_text/speech_to_text.dart' as stt;

import '../../core/api.dart';
import '../../core/models.dart';
import '../../core/theme_controller.dart';
import '../widgets/coder_preview_screen.dart';

class CoderChatScreen extends ConsumerStatefulWidget {
  const CoderChatScreen({
    super.key,
    required this.projectId,
    required this.projectName,
    this.chatId,
  });

  final String projectId;
  final String projectName;
  final String? chatId;

  @override
  ConsumerState<CoderChatScreen> createState() => _CoderChatScreenState();
}

class _CoderMessage {
  final String text;
  final bool fromUser;
  final String? id;

  const _CoderMessage({required this.text, required this.fromUser, this.id});
}

class _CoderAttachment {
  final String name;
  final String content;
  final int sizeBytes;

  const _CoderAttachment({
    required this.name,
    required this.content,
    required this.sizeBytes,
  });
}

class _CoderChatScreenState extends ConsumerState<CoderChatScreen> {
  final _scaffoldKey = GlobalKey<ScaffoldState>();
  final _messageController = TextEditingController();
  final _scrollController = ScrollController();
  final stt.SpeechToText _speech = stt.SpeechToText();

  final List<_CoderMessage> _messages = [];
  final List<_CoderAttachment> _pendingAttachments = [];

  List<FileItem> _files = [];
  String? _chatId;
  String? _errorText;
  String? _savedZipPath;
  String? _previewUrl;

  bool _loadingFiles = true;
  bool _isSending = false;
  bool _isListening = false;
  bool _speechAvailable = false;
  bool _showFiles = false;
  bool _overthink = false;
  bool _hasChanges = false;
  bool _previewReady = false;

  ApiCancelToken? _generationToken;

  @override
  void initState() {
    super.initState();
    _chatId = widget.chatId;
    _loadFiles();
    _initSpeech();
  }

  @override
  void dispose() {
    _generationToken?.cancel();
    _speech.stop();
    _messageController.dispose();
    _scrollController.dispose();
    super.dispose();
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
      onError: (_) {
        if (mounted) {
          setState(() => _isListening = false);
        }
      },
    );

    if (mounted) {
      setState(() {});
    }
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
      listenOptions: stt.SpeechListenOptions(localeId: 'es_ES'),
      onResult: (result) {
        if (!mounted) return;

        setState(() {
          _messageController.text = result.recognizedWords;
          _messageController.selection = TextSelection.fromPosition(
            TextPosition(offset: _messageController.text.length),
          );
        });
      },
    );
  }

  Future<void> _loadFiles() async {
    if (mounted) {
      setState(() {
        _loadingFiles = true;
        _errorText = null;
      });
    }

    try {
      final response = await ApiClient.get(
        '/projects/${Uri.encodeComponent(widget.projectId)}/files',
      );

      final data = ApiClient.decode(response) as Map<String, dynamic>;

      final files = (data['files'] as List? ?? [])
          .whereType<Map>()
          .map((row) => FileItem.fromJson(Map<String, dynamic>.from(row)))
          .toList();

      if (!mounted) return;

      setState(() {
        _files = files;
        _loadingFiles = false;
      });
    } catch (e) {
      if (!mounted) return;

      setState(() {
        _loadingFiles = false;
        _errorText = 'No se pudieron cargar los archivos: $e';
      });
    }
  }

  Future<void> _attachFile() async {
    final picked = await FilePicker.pickFile();

    if (picked == null || picked.path == null) return;

    try {
      const extensions = <String>{
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

      if (!extensions.contains((picked.extension ?? '').toLowerCase())) {
        throw Exception(
          'Por ahora Coder admite archivos de texto y código en la vista previa.',
        );
      }

      final file = File(picked.path!);
      final size = await file.length();

      if (size <= 0 || size > 1024 * 1024) {
        throw Exception('El archivo debe pesar entre 1 byte y 1 MB.');
      }

      final content = await file.readAsString();

      if (content.length > 100000) {
        throw Exception('El archivo es demasiado largo para adjuntarlo.');
      }

      if (!mounted) return;

      setState(() {
        _pendingAttachments.add(
          _CoderAttachment(
            name: picked.name,
            content: content,
            sizeBytes: size,
          ),
        );
      });
    } catch (e) {
      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('$e')));
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
                      'Se mantienen como vista previa hasta enviar',
                    ),
                    onTap: () {
                      Navigator.pop(sheetContext);
                      _attachFile();
                    },
                  ),
                  ListTile(
                    leading: const Icon(LucideIcons.messageCircle),
                    title: const Text('Cambiar a chat'),
                    trailing: const Icon(LucideIcons.chevronRight),
                    onTap: () {
                      Navigator.pop(sheetContext);
                      Navigator.of(context).maybePop();
                    },
                  ),
                  SwitchListTile(
                    secondary: const Icon(LucideIcons.brain),
                    title: const Text('Sobrepensar'),
                    subtitle: const Text(
                      'Revisión más profunda antes de aplicar cambios',
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

  void _cancelGeneration() {
    _generationToken?.cancel();
  }

  Future<void> _sendMessage() async {
    final text = _messageController.text.trim();
    final attachments = List<_CoderAttachment>.from(_pendingAttachments);

    if ((text.isEmpty && attachments.isEmpty) || _isSending) {
      return;
    }

    final prompt = text.isEmpty
        ? 'Revisa los archivos adjuntos y dime qué cambios recomiendas.'
        : text;

    final token = ApiCancelToken();
    final userIndex = _messages.length;

    setState(() {
      _messages.add(
        _CoderMessage(
          text: attachments.isEmpty
              ? prompt
              : '$prompt\n\n${attachments.length} archivo(s) adjunto(s)',
          fromUser: true,
        ),
      );

      _pendingAttachments.clear();
      _messageController.clear();
      _isSending = true;
      _generationToken = token;
      _errorText = null;
    });

    _scrollToBottom();

    try {
      if (_chatId == null) {
        final response = await ApiClient.post('/chats', {
          'title': prompt.length > 60
              ? '${prompt.substring(0, 60)}...'
              : prompt,
          'mode': 'coder',
          'projectId': widget.projectId,
        });

        final data = ApiClient.decode(response) as Map<String, dynamic>;

        final chat = Map<String, dynamic>.from(data['chat'] as Map);

        _chatId = '${chat['id']}';
      }

      if (token.isCancelled) {
        throw const ApiRequestCancelled();
      }

      final response = await ApiClient.postCancelable('/ai/coder', {
        'prompt': prompt,
        'projectId': widget.projectId,
        'chatId': _chatId,
        'overthink': _overthink,
        'attachments': attachments
            .map((file) => {'name': file.name, 'content': file.content})
            .toList(),
      }, token);

      final data = ApiClient.decode(response) as Map<String, dynamic>;

      if (!mounted || token.isCancelled) return;

      final changed = data['changedFiles'] as List? ?? [];
      final deleted = data['deletedFiles'] as List? ?? [];

      final previewReady = data['previewReady'] == true;
      final previewUrl = data['previewUrl']?.toString().trim();

      setState(() {
        _previewReady = previewReady;
        _previewUrl =
            previewReady && previewUrl != null && previewUrl.isNotEmpty
            ? previewUrl
            : null;

        if (userIndex < _messages.length) {
          final old = _messages[userIndex];

          _messages[userIndex] = _CoderMessage(
            text: old.text,
            fromUser: true,
            id: data['userMessageId']?.toString(),
          );
        }

        _messages.add(
          _CoderMessage(
            text: '${data['response'] ?? ''}',
            fromUser: false,
            id: data['assistantMessageId']?.toString(),
          ),
        );

        _hasChanges = changed.isNotEmpty || deleted.isNotEmpty;
      });

      await _loadFiles();
    } on ApiRequestCancelled {
      // No se añade una respuesta inventada al cancelar.
    } on ApiException catch (e) {
      if (!mounted || token.isCancelled) return;

      setState(() {
        _messages.add(
          _CoderMessage(text: 'Error: ${e.message}', fromUser: false),
        );
      });
    } catch (_) {
      if (!mounted || token.isCancelled) return;

      setState(() {
        _messages.add(
          const _CoderMessage(
            text: 'No se pudo contactar con Coder.',
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

  Future<void> _undoChanges() async {
    try {
      final response = await ApiClient.post(
        '/projects/${Uri.encodeComponent(widget.projectId)}/undo',
        {},
      );

      ApiClient.decode(response);

      if (!mounted) return;

      setState(() {
        _hasChanges = false;
        _previewReady = false;
        _previewUrl = null;
      });

      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Cambios revertidos')));

      await _loadFiles();
    } on ApiException catch (e) {
      if (!mounted) return;

      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(e.message)));
    } catch (_) {
      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('No se pudieron revertir los cambios')),
      );
    }
  }

  Future<void> _downloadProject() async {
    try {
      final response = await ApiClient.get(
        '/projects/${Uri.encodeComponent(widget.projectId)}/download',
      );

      if (response.statusCode < 200 || response.statusCode >= 300) {
        ApiClient.decode(response);
        return;
      }

      final directory = await getApplicationDocumentsDirectory();

      final safeName = widget.projectName.replaceAll(
        RegExp(r'[^A-Za-z0-9._-]'),
        '-',
      );

      final file = File('${directory.path}/$safeName.zip');

      await file.writeAsBytes(response.bodyBytes, flush: true);

      if (!mounted) return;

      setState(() => _savedZipPath = file.path);

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Proyecto guardado en: ${file.path}'),
          duration: const Duration(seconds: 6),
        ),
      );
    } on ApiException catch (e) {
      if (!mounted) return;

      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(e.message)));
    } catch (_) {
      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('No se pudo descargar el proyecto')),
      );
    }
  }

  void _previewFile(FileItem file) {
    final palette = ref.read(appPaletteProvider);

    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: palette.surface,
      showDragHandle: true,
      builder: (sheetContext) {
        return SafeArea(
          child: SizedBox(
            height: MediaQuery.sizeOf(context).height * .78,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Padding(
                  padding: const EdgeInsets.all(16),
                  child: Row(
                    children: [
                      const Icon(LucideIcons.fileCode2),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Text(
                          file.path,
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(fontWeight: FontWeight.w700),
                        ),
                      ),
                      IconButton(
                        tooltip: 'Copiar archivo',
                        onPressed: () {
                          Clipboard.setData(ClipboardData(text: file.content));
                        },
                        icon: const Icon(LucideIcons.copy),
                      ),
                    ],
                  ),
                ),
                const Divider(height: 1),
                Expanded(
                  child: SingleChildScrollView(
                    padding: const EdgeInsets.all(16),
                    child: SelectableText(
                      file.isDirectory ? 'Directorio' : file.content,
                      style: const TextStyle(
                        fontFamily: 'monospace',
                        fontSize: 13,
                        height: 1.45,
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Future<void> _feedback(_CoderMessage message, String kind) async {
    if (message.id == null || message.id!.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Este mensaje todavía no tiene un ID guardado.'),
        ),
      );

      return;
    }

    String? note;
    final controller = TextEditingController();

    if (kind == 'negative') {
      note = await showDialog<String>(
        context: context,
        builder: (dialogContext) => AlertDialog(
          title: const Text('¿Qué falló en esta respuesta?'),
          content: TextField(
            controller: controller,
            minLines: 2,
            maxLines: 5,
            decoration: const InputDecoration(
              hintText: 'Describe qué salió mal...',
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dialogContext),
              child: const Text('Cancelar'),
            ),
            FilledButton(
              onPressed: () =>
                  Navigator.pop(dialogContext, controller.text.trim()),
              child: const Text('Enviar'),
            ),
          ],
        ),
      );

      if (note == null) {
        controller.dispose();
        return;
      }
    }

    controller.dispose();

    try {
      await ApiClient.post('/feedback', {
        'messageId': message.id,
        'kind': kind,
        if (note != null && note.isNotEmpty) 'note': note,
      });

      if (!mounted) return;

      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Feedback enviado')));
    } catch (e) {
      if (!mounted) return;

      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('No se pudo enviar feedback: $e')));
    }
  }

  void _editMessage(_CoderMessage message) {
    setState(() {
      _messageController.text = message.text;
      _messageController.selection = TextSelection.fromPosition(
        TextPosition(offset: _messageController.text.length),
      );
    });
  }

  void _copyMessage(_CoderMessage message) {
    Clipboard.setData(ClipboardData(text: message.text));

    ScaffoldMessenger.of(
      context,
    ).showSnackBar(const SnackBar(content: Text('Mensaje copiado')));
  }

  void _openPreview() {
    final url = _previewUrl;

    if (!_previewReady || url == null || url.isEmpty) {
      return;
    }

    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => CoderPreviewScreen(
          previewUrl: url,
          projectName: widget.projectName,
        ),
      ),
    );
  }

  void _scrollToBottom() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!_scrollController.hasClients) return;

      _scrollController.animateTo(
        _scrollController.position.maxScrollExtent,
        duration: const Duration(milliseconds: 220),
        curve: Curves.easeOut,
      );
    });
  }

  @override
  Widget build(BuildContext context) {
    final palette = ref.watch(appPaletteProvider);

    return Scaffold(
      key: _scaffoldKey,
      backgroundColor: palette.background,
      drawer: Drawer(
        backgroundColor: palette.surface,
        child: SafeArea(
          child: ListView(
            children: [
              ListTile(
                leading: const Icon(LucideIcons.arrowLeft),
                title: const Text('Volver a tus chats'),
                onTap: () {
                  Navigator.pop(context);
                  Navigator.of(context).maybePop();
                },
              ),
              const Divider(),
              const ListTile(
                title: Text(
                  'Archivos del proyecto',
                  style: TextStyle(fontWeight: FontWeight.w700),
                ),
              ),
              ..._files.map(
                (file) => ListTile(
                  leading: Icon(
                    file.isDirectory
                        ? LucideIcons.folder
                        : LucideIcons.fileCode2,
                  ),
                  title: Text(file.path),
                  onTap: () {
                    Navigator.pop(context);
                    _previewFile(file);
                  },
                ),
              ),
            ],
          ),
        ),
      ),
      appBar: AppBar(
        backgroundColor: palette.background,
        leading: IconButton(
          tooltip: 'Menú',
          onPressed: () => _scaffoldKey.currentState?.openDrawer(),
          icon: const Icon(LucideIcons.menu),
        ),
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              widget.projectName,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(fontSize: 16),
            ),
            const Text('Mistral · Sandbox', style: TextStyle(fontSize: 11)),
          ],
        ),
        actions: [
          IconButton(
            tooltip: 'Deshacer cambios',
            onPressed: _hasChanges ? _undoChanges : null,
            icon: const Icon(LucideIcons.undo2),
          ),
          TextButton.icon(
            onPressed: () {
              setState(() => _showFiles = !_showFiles);
            },
            icon: Icon(
              _showFiles ? LucideIcons.chevronUp : LucideIcons.chevronDown,
            ),
            label: const Text('Ver archivos'),
          ),
          IconButton(
            tooltip: 'Descargar proyecto ZIP',
            onPressed: _downloadProject,
            icon: const Icon(LucideIcons.download),
          ),
        ],
      ),
      body: SafeArea(
        child: Column(
          children: [
            if (_showFiles)
              Container(
                height: 190,
                decoration: BoxDecoration(
                  color: palette.surface,
                  border: Border(bottom: BorderSide(color: palette.border)),
                ),
                child: _loadingFiles
                    ? const Center(child: CircularProgressIndicator())
                    : _files.isEmpty
                    ? Center(
                        child: Text(
                          _errorText ?? 'Este proyecto aún no tiene archivos.',
                        ),
                      )
                    : ListView.builder(
                        itemCount: _files.length,
                        itemBuilder: (context, index) {
                          final file = _files[index];

                          return ListTile(
                            dense: true,
                            leading: Icon(
                              file.isDirectory
                                  ? LucideIcons.folder
                                  : LucideIcons.fileCode2,
                              size: 19,
                            ),
                            title: Text(
                              file.path,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                            onTap: () => _previewFile(file),
                          );
                        },
                      ),
              ),
            Expanded(
              child: ListView.builder(
                controller: _scrollController,
                padding: const EdgeInsets.all(14),
                itemCount:
                    _messages.length +
                    (_isSending ? 1 : 0) +
                    (!_isSending ? 1 : 0),
                itemBuilder: (context, index) {
                  if (!_isSending && index == _messages.length) {
                    return CoderPreviewCard(
                      ready: _previewReady,
                      onOpen: _openPreview,
                    );
                  }

                  if (_isSending && index == _messages.length) {
                    return const _CoderThinking();
                  }

                  final message = _messages[index];

                  return _CoderMessageBubble(
                    message: message,
                    onCopy: _copyMessage,
                    onEdit: _editMessage,
                    onFeedback: _feedback,
                  );
                },
              ),
            ),
            if (_pendingAttachments.isNotEmpty)
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 12),
                child: Align(
                  alignment: Alignment.centerLeft,
                  child: Wrap(
                    spacing: 6,
                    children: _pendingAttachments.map((file) {
                      return InputChip(
                        avatar: const Icon(LucideIcons.fileText, size: 16),
                        label: Text(file.name),
                        onDeleted: () {
                          setState(() => _pendingAttachments.remove(file));
                        },
                      );
                    }).toList(),
                  ),
                ),
              ),
            if (_overthink)
              const Padding(
                padding: EdgeInsets.only(top: 6),
                child: Align(
                  alignment: Alignment.centerLeft,
                  child: Padding(
                    padding: EdgeInsets.symmetric(horizontal: 16),
                    child: Chip(
                      avatar: Icon(LucideIcons.brain, size: 16),
                      label: Text('Sobrepensar activado'),
                    ),
                  ),
                ),
              ),
            Padding(
              padding: const EdgeInsets.fromLTRB(10, 6, 10, 12),
              child: Container(
                decoration: BoxDecoration(
                  color: palette.surface,
                  borderRadius: BorderRadius.circular(26),
                  border: Border.all(color: palette.border),
                ),
                child: Row(
                  children: [
                    IconButton(
                      tooltip: 'Más herramientas',
                      onPressed: _openAddMenu,
                      icon: const Icon(LucideIcons.plus),
                    ),
                    Expanded(
                      child: TextField(
                        controller: _messageController,
                        enabled: !_isSending,
                        minLines: 1,
                        maxLines: 5,
                        decoration: const InputDecoration(
                          hintText: 'Describe qué quieres construir...',
                          border: InputBorder.none,
                        ),
                        onSubmitted: (_) {
                          if (!_isSending) {
                            _sendMessage();
                          }
                        },
                      ),
                    ),
                    IconButton(
                      tooltip: _isListening
                          ? 'Detener dictado'
                          : 'Dictar mensaje',
                      onPressed: _toggleListening,
                      icon: Icon(
                        _isListening ? LucideIcons.micOff : LucideIcons.mic,
                      ),
                    ),
                    Padding(
                      padding: const EdgeInsets.only(right: 5),
                      child: IconButton.filled(
                        tooltip: _isSending ? 'Detener' : 'Enviar',
                        onPressed: _isSending
                            ? _cancelGeneration
                            : _sendMessage,
                        icon: Icon(
                          _isSending ? LucideIcons.square : LucideIcons.arrowUp,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
            if (_savedZipPath != null)
              Padding(
                padding: const EdgeInsets.only(bottom: 6),
                child: Text(
                  'ZIP guardado: $_savedZipPath',
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(color: palette.textSecondary, fontSize: 11),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

class _CoderMessageBubble extends StatelessWidget {
  const _CoderMessageBubble({
    required this.message,
    required this.onCopy,
    required this.onEdit,
    required this.onFeedback,
  });

  final _CoderMessage message;
  final ValueChanged<_CoderMessage> onCopy;
  final ValueChanged<_CoderMessage> onEdit;
  final void Function(_CoderMessage, String) onFeedback;

  @override
  Widget build(BuildContext context) {
    return Align(
      alignment: message.fromUser
          ? Alignment.centerRight
          : Alignment.centerLeft,
      child: Container(
        margin: const EdgeInsets.symmetric(vertical: 5),
        constraints: BoxConstraints(
          maxWidth: MediaQuery.sizeOf(context).width * .9,
        ),
        child: Column(
          crossAxisAlignment: message.fromUser
              ? CrossAxisAlignment.end
              : CrossAxisAlignment.start,
          children: [
            Container(
              padding: const EdgeInsets.all(13),
              decoration: BoxDecoration(
                color: message.fromUser
                    ? Theme.of(
                        context,
                      ).colorScheme.primary.withValues(alpha: .12)
                    : Theme.of(context).colorScheme.surface,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: Theme.of(context).dividerColor),
              ),
              child: SelectableText(message.text),
            ),
            Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                if (message.fromUser)
                  IconButton(
                    tooltip: 'Editar',
                    visualDensity: VisualDensity.compact,
                    onPressed: () => onEdit(message),
                    icon: const Icon(LucideIcons.pencil, size: 17),
                  ),
                IconButton(
                  tooltip: 'Copiar',
                  visualDensity: VisualDensity.compact,
                  onPressed: () => onCopy(message),
                  icon: const Icon(LucideIcons.copy, size: 17),
                ),
                if (!message.fromUser) ...[
                  IconButton(
                    tooltip: 'Buena respuesta',
                    visualDensity: VisualDensity.compact,
                    onPressed: () => onFeedback(message, 'positive'),
                    icon: const Icon(LucideIcons.thumbsUp, size: 17),
                  ),
                  IconButton(
                    tooltip: 'Reportar respuesta',
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

class _CoderThinking extends StatefulWidget {
  const _CoderThinking();

  @override
  State<_CoderThinking> createState() => _CoderThinkingState();
}

class _CoderThinkingState extends State<_CoderThinking>
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
    return AnimatedBuilder(
      animation: _controller,
      builder: (context, _) {
        return Align(
          alignment: Alignment.centerLeft,
          child: Padding(
            padding: const EdgeInsets.all(14),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: List.generate(3, (index) {
                final phase = (_controller.value * 3 - index).abs();

                return Opacity(
                  opacity: (1 - phase).clamp(.25, 1.0),
                  child: Container(
                    width: 7,
                    height: 7,
                    margin: const EdgeInsets.symmetric(horizontal: 3),
                    decoration: BoxDecoration(
                      color: Theme.of(context).colorScheme.onSurface,
                      shape: BoxShape.circle,
                    ),
                  ),
                );
              }),
            ),
          ),
        );
      },
    );
  }
}
