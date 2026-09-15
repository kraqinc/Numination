import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/api.dart';
import '../../core/auth_controller.dart';
import '../../core/models.dart';
import '../../core/theme.dart';
import '../controllers.dart';
import 'chat_screen.dart';
import 'credits_screen.dart';
import 'memory_screen.dart';
import 'notifications_screen.dart';
import 'owner_screen.dart';
import 'profile_screen.dart';
import 'settings_screen.dart';
import 'workspace_screen.dart';

// ---------------------------------------------------------------------------
// Local palette
// ---------------------------------------------------------------------------

/// Monochrome palette used exclusively by the chat-first home shell.
///
/// Kept separate from [AppColors] and [AuthColors] so the rest of the app
/// keeps its cyan/purple identity while this screen matches the near-black
/// reference design: pure black background, dark grey pills, bright chip
/// buttons for the mode selector, and no color accents at all.
class HomePalette {
  const HomePalette._();

  static const background = Color(0xFF000000);
  static const surface = Color(0xFF0A0A0A);
  static const pill = Color(0xFF1C1C1C);
  static const pillSoft = Color(0xFF262626);
  static const composer = Color(0xFF161616);
  static const composerEdge = Color(0xFF232323);
  static const border = Color(0xFF2A2A2A);
  static const divider = Color(0xFF181818);
  static const text = Color(0xFFF5F5F5);
  static const muted = Color(0xFF8A8A8A);
  static const mutedSoft = Color(0xFF5C5C5C);
  static const chip = Color(0xFFDADADA);
  static const chipText = Color(0xFF111111);
  static const accent = Color(0xFF7C5CFC);
  static const danger = Color(0xFFFF6B6B);
  static const userBubble = Color(0xFF1F1F1F);
  static const botBubble = Color(0xFF111111);
}

// ---------------------------------------------------------------------------
// Modes and models
// ---------------------------------------------------------------------------

/// The two answer modes offered by the composer chips.
enum AgentMode {
  chat('chat', 'Chat', Icons.chat_bubble_outline_rounded),
  coder('editor', 'Coder', Icons.code_rounded);

  const AgentMode(this.apiValue, this.label, this.icon);

  /// Value forwarded to `POST /ai/chat` as `mode`.
  final String apiValue;

  /// Label rendered inside the chip.
  final String label;

  /// Leading icon for the chip.
  final IconData icon;
}

/// A single turn shown in the home conversation.
class _ChatMessage {
  _ChatMessage({
    required this.author,
    required this.text,
    required this.mine,
    DateTime? timestamp,
  }) : timestamp = timestamp ?? DateTime.now();

  final String author;
  final String text;
  final bool mine;
  final DateTime timestamp;
}

/// Compact representation of a previously opened chat, used by the empty
/// state to give the user a way back into their history.
class _RecentChat {
  const _RecentChat({
    required this.title,
    required this.preview,
    required this.mode,
    required this.when,
  });

  final String title;
  final String preview;
  final AgentMode mode;
  final String when;
}

List<_RecentChat> _seedRecentChats() {
  return const [
    _RecentChat(
      title: 'Refactor de auth_controller',
      preview: 'Separa el flujo OTP del flujo email + password.',
      mode: AgentMode.coder,
      when: 'Hace 2 h',
    ),
    _RecentChat(
      title: 'Diseño del workspace',
      preview: 'Editor, terminal y memoria en una sola vista.',
      mode: AgentMode.chat,
      when: 'Ayer',
    ),
    _RecentChat(
      title: 'Migraciones Supabase',
      preview: 'Revisar triggers de profiles y Credits.',
      mode: AgentMode.coder,
      when: 'Hace 3 días',
    ),
  ];
}

// ---------------------------------------------------------------------------
// HomeScreen
// ---------------------------------------------------------------------------

/// Chat-first home shell for Numination.
///
/// Layout, top to bottom:
///
///  * a custom top bar with the drawer handle, a search pill and the ghost
///    assistant shortcut;
///  * a conversation area that is intentionally empty on a fresh install;
///  * a composer with an attachment action, a mode selector (`Chat` /
///    `Coder`), a microphone button and a live waveform button.
///
/// Navigation to the rest of the application lives in the drawer so the
/// screen itself stays focused on the current conversation.
class HomeScreen extends ConsumerStatefulWidget {
  const HomeScreen({super.key});

  @override
  ConsumerState<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends ConsumerState<HomeScreen>
    with TickerProviderStateMixin {
  final _scaffoldKey = GlobalKey<ScaffoldState>();
  final _composer = TextEditingController();
  final _composerFocus = FocusNode();
  final _search = TextEditingController();
  final _scroll = ScrollController();

  final List<_ChatMessage> _messages = <_ChatMessage>[];
  final List<_RecentChat> _recentChats = _seedRecentChats();

  AgentMode _mode = AgentMode.chat;
  bool _sending = false;
  bool _voiceActive = false;
  String _searchQuery = '';

  late final AnimationController _pulseController;

  @override
  void initState() {
    super.initState();
    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1400),
    )..repeat(reverse: true);
    _search.addListener(_onSearchChanged);
  }

  @override
  void dispose() {
    _pulseController.dispose();
    _search.removeListener(_onSearchChanged);
    _search.dispose();
    _composer.dispose();
    _composerFocus.dispose();
    _scroll.dispose();
    super.dispose();
  }

  void _onSearchChanged() {
    final next = _search.text.trim().toLowerCase();
    if (next == _searchQuery) return;
    setState(() => _searchQuery = next);
  }

  void _openDrawer() => _scaffoldKey.currentState?.openDrawer();

  void _closeDrawer() {
    if (_scaffoldKey.currentState?.isDrawerOpen ?? false) {
      Navigator.of(context).pop();
    }
  }

  Future<void> _send() async {
    final text = _composer.text.trim();
    if (text.isEmpty || _sending) return;

    _composer.clear();
    setState(() {
      _messages.add(_ChatMessage(author: 'Tú', text: text, mine: true));
      _sending = true;
    });
    _scrollToEnd();

    try {
      final data = ApiClient.decode(
        await ApiClient.post(
          '/ai/chat',
          {'prompt': text, 'mode': _mode.apiValue},
        ),
      ) as Map;

      final parsed = ChatResponse.fromJson(Map<String, dynamic>.from(data));

      if (!mounted) return;
      setState(() {
        _messages.add(
          _ChatMessage(
            author: 'Numination',
            text: parsed.response.isEmpty
                ? 'Sin respuesta del modelo.'
                : parsed.response,
            mine: false,
          ),
        );
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _messages.add(
          _ChatMessage(
            author: 'Error',
            text: '$e',
            mine: false,
          ),
        );
      });
    } finally {
      if (mounted) {
        setState(() => _sending = false);
        _scrollToEnd();
      }
    }
  }

  void _scrollToEnd() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!_scroll.hasClients) return;
      _scroll.animateTo(
        _scroll.position.maxScrollExtent + 120,
        duration: const Duration(milliseconds: 260),
        curve: Curves.easeOutCubic,
      );
    });
  }

  void _setMode(AgentMode next) {
    if (_mode == next) return;
    HapticFeedback.selectionClick();
    setState(() => _mode = next);
  }

  void _toggleVoice() {
    HapticFeedback.lightImpact();
    setState(() => _voiceActive = !_voiceActive);
  }

  Future<void> _showAttachments() async {
    await showModalBottomSheet<void>(
      context: context,
      backgroundColor: HomePalette.pill,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(22)),
      ),
      builder: (_) => _AttachmentSheet(
        onPick: (kind) {
          Navigator.of(context).pop();
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              backgroundColor: HomePalette.pillSoft,
              content: Text('Adjunto: $kind (pendiente de backend)'),
            ),
          );
        },
      ),
    );
  }

  void _openRecent(_RecentChat chat) {
    setState(() {
      _mode = chat.mode;
      _messages
        ..clear()
        ..add(
          _ChatMessage(
            author: 'Numination',
            text: 'Retomando "${chat.title}".\n\n${chat.preview}',
            mine: false,
          ),
        );
    });
  }

  @override
  Widget build(BuildContext context) {
    final auth = ref.watch(authControllerProvider);
    final user = auth is AuthAuthenticated ? auth.user : null;

    return Scaffold(
      key: _scaffoldKey,
      backgroundColor: HomePalette.background,
      drawer: _NavDrawer(
        user: user,
        onOpenProjects: () => _navigateTab(const DashboardTab()),
        onOpenWorkspace: () => _navigateTab(const WorkspaceScreen()),
        onOpenChat: () => _navigateTab(const ChatScreen()),
        onOpenMemory: () => _navigateTab(const MemoryScreen()),
        onOpenCredits: () => _navigateTab(const CreditsScreen()),
        onOpenSettings: () => _navigateTab(const SettingsScreen()),
        onOpenNotifications: () => _navigateTab(const NotificationsScreen()),
        onOpenProfile: () => _navigateTab(ProfileScreen(user: user)),
        onOpenOwner: user?.role.toUpperCase() == 'OWNER'
            ? () => _navigateTab(const OwnerScreen())
            : null,
      ),
      body: SafeArea(
        bottom: false,
        child: Column(
          children: [
            _TopSearchBar(
              controller: _search,
              onMenu: _openDrawer,
              onGhost: () => _navigateTab(const ChatScreen()),
            ),
            Expanded(
              child: _messages.isEmpty
                  ? _EmptyConversation(
                      query: _searchQuery,
                      recent: _filterRecent(_recentChats, _searchQuery),
                      onRecent: _openRecent,
                      mode: _mode,
                    )
                  : _ConversationList(
                      controller: _scroll,
                      messages: _messages,
                      sending: _sending,
                    ),
            ),
            if (_voiceActive)
              _VoiceOverlay(
                pulse: _pulseController,
                onCancel: _toggleVoice,
                onSend: () {
                  _toggleVoice();
                  _composer.text = 'Nota de voz';
                  _send();
                },
              ),
            _Composer(
              controller: _composer,
              focusNode: _composerFocus,
              mode: _mode,
              sending: _sending,
              onMode: _setMode,
              onAttach: _showAttachments,
              onMic: _toggleVoice,
              onWave: _toggleVoice,
              onSubmit: _send,
            ),
          ],
        ),
      ),
    );
  }

  List<_RecentChat> _filterRecent(List<_RecentChat> source, String query) {
    if (query.isEmpty) return source;
    return source
        .where(
          (c) =>
              c.title.toLowerCase().contains(query) ||
              c.preview.toLowerCase().contains(query),
        )
        .toList();
  }

  void _navigateTab(Widget screen) {
    _closeDrawer();
    Navigator.of(context).push(
      MaterialPageRoute(builder: (_) => screen),
    );
  }
}

// ---------------------------------------------------------------------------
// Top search bar
// ---------------------------------------------------------------------------

/// Custom top bar matching the reference: hamburger, a wide rounded search
/// pill labelled "Buscar chats" with a keyboard shortcut glyph on the right
/// side, and a ghost assistant button anchored to the far right.
class _TopSearchBar extends StatelessWidget {
  const _TopSearchBar({
    required this.controller,
    required this.onMenu,
    required this.onGhost,
  });

  final TextEditingController controller;
  final VoidCallback onMenu;
  final VoidCallback onGhost;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(8, 10, 8, 12),
      child: Row(
        children: [
          _IconTap(
            icon: Icons.menu_rounded,
            onTap: onMenu,
            tooltip: 'Menú',
            size: 26,
          ),
          const SizedBox(width: 4),
          Expanded(
            child: Container(
              height: 46,
              decoration: BoxDecoration(
                color: HomePalette.pill,
                borderRadius: BorderRadius.circular(26),
              ),
              padding: const EdgeInsets.symmetric(horizontal: 14),
              child: Row(
                children: [
                  const Icon(
                    Icons.search_rounded,
                    size: 20,
                    color: HomePalette.muted,
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: TextField(
                      controller: controller,
                      cursorColor: HomePalette.text,
                      textInputAction: TextInputAction.search,
                      style: const TextStyle(
                        color: HomePalette.text,
                        fontSize: 15,
                        fontWeight: FontWeight.w500,
                      ),
                      decoration: const InputDecoration(
                        isDense: true,
                        border: InputBorder.none,
                        enabledBorder: InputBorder.none,
                        focusedBorder: InputBorder.none,
                        filled: false,
                        hintText: 'Buscar chats',
                        hintStyle: TextStyle(
                          color: HomePalette.muted,
                          fontSize: 15,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Container(
                    width: 30,
                    height: 22,
                    decoration: BoxDecoration(
                      color: HomePalette.pillSoft,
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: const Center(
                      child: Icon(
                        Icons.keyboard_alt_outlined,
                        size: 14,
                        color: HomePalette.muted,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(width: 4),
          _GhostButton(onTap: onGhost),
        ],
      ),
    );
  }
}

/// Small ghost-shaped assistant launcher drawn with a [CustomPainter] so it
/// matches the reference glyph without shipping an SVG asset.
class _GhostButton extends StatelessWidget {
  const _GhostButton({required this.onTap});

  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return InkResponse(
      onTap: onTap,
      radius: 22,
      child: Padding(
        padding: const EdgeInsets.all(6),
        child: SizedBox(
          width: 28,
          height: 28,
          child: CustomPaint(
            painter: _GhostPainter(color: HomePalette.text),
          ),
        ),
      ),
    );
  }
}

class _GhostPainter extends CustomPainter {
  const _GhostPainter({required this.color});

  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    final stroke = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.6
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round;

    final w = size.width;
    final h = size.height;
    final body = Path()
      ..moveTo(w * 0.18, h * 0.9)
      ..lineTo(w * 0.18, h * 0.42)
      ..quadraticBezierTo(w * 0.18, h * 0.14, w * 0.5, h * 0.14)
      ..quadraticBezierTo(w * 0.82, h * 0.14, w * 0.82, h * 0.42)
      ..lineTo(w * 0.82, h * 0.9)
      ..lineTo(w * 0.68, h * 0.78)
      ..lineTo(w * 0.5, h * 0.9)
      ..lineTo(w * 0.32, h * 0.78)
      ..close();

    canvas.drawPath(body, stroke);

    final eyes = Paint()
      ..color = color
      ..style = PaintingStyle.fill;

    canvas.drawCircle(Offset(w * 0.38, h * 0.45), 1.6, eyes);
    canvas.drawCircle(Offset(w * 0.62, h * 0.45), 1.6, eyes);
  }

  @override
  bool shouldRepaint(covariant _GhostPainter oldDelegate) =>
      oldDelegate.color != color;
}

class _IconTap extends StatelessWidget {
  const _IconTap({
    required this.icon,
    required this.onTap,
    this.tooltip,
    this.size = 22,
    this.color = HomePalette.text,
  });

  final IconData icon;
  final VoidCallback onTap;
  final String? tooltip;
  final double size;
  final Color color;

  @override
  Widget build(BuildContext context) {
    final child = InkResponse(
      onTap: onTap,
      radius: 22,
      child: Padding(
        padding: const EdgeInsets.all(6),
        child: Icon(icon, size: size, color: color),
      ),
    );
    if (tooltip == null) return child;
    return Tooltip(message: tooltip!, child: child);
  }
}

// ---------------------------------------------------------------------------
// Conversation
// ---------------------------------------------------------------------------

/// Empty conversation: either the recent chats grid (when no search query
/// is active) or a filtered list, with a subtle hint when nothing matches.
class _EmptyConversation extends StatelessWidget {
  const _EmptyConversation({
    required this.query,
    required this.recent,
    required this.onRecent,
    required this.mode,
  });

  final String query;
  final List<_RecentChat> recent;
  final ValueChanged<_RecentChat> onRecent;
  final AgentMode mode;

  @override
  Widget build(BuildContext context) {
    if (recent.isEmpty && query.isNotEmpty) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(
              Icons.search_off_rounded,
              size: 46,
              color: HomePalette.mutedSoft,
            ),
            const SizedBox(height: 12),
            Text(
              'Sin resultados para "$query"',
              style: const TextStyle(
                color: HomePalette.muted,
                fontSize: 14,
              ),
            ),
          ],
        ),
      );
    }

    if (recent.isEmpty) {
      return const _BlankCanvas();
    }

    return ListView(
      padding: const EdgeInsets.fromLTRB(18, 4, 18, 18),
      children: [
        Row(
          children: [
            const Icon(
              Icons.history_rounded,
              size: 15,
              color: HomePalette.muted,
            ),
            const SizedBox(width: 6),
            Text(
              query.isEmpty ? 'Recientes' : 'Resultados',
              style: const TextStyle(
                color: HomePalette.muted,
                fontSize: 12,
                fontWeight: FontWeight.w700,
                letterSpacing: 0.4,
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),
        for (final c in recent)
          Padding(
            padding: const EdgeInsets.only(bottom: 8),
            child: _RecentCard(chat: c, onTap: () => onRecent(c)),
          ),
        const SizedBox(height: 10),
        Text(
          'Modo actual: ${mode.label}',
          style: const TextStyle(
            color: HomePalette.mutedSoft,
            fontSize: 11,
          ),
        ),
      ],
    );
  }
}

class _BlankCanvas extends StatelessWidget {
  const _BlankCanvas();

  @override
  Widget build(BuildContext context) {
    // Intentionally empty: matches the reference which shows a clean canvas
    // waiting for the first prompt. We only draw a very subtle watermark so
    // the user does not feel the screen is broken.
    return Center(
      child: Opacity(
        opacity: 0.08,
        child: Image.asset(
          'assets/images/numination_logo_wordmark.png',
          width: 240,
          fit: BoxFit.contain,
        ),
      ),
    );
  }
}

class _RecentCard extends StatelessWidget {
  const _RecentCard({required this.chat, required this.onTap});

  final _RecentChat chat;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: HomePalette.surface,
      borderRadius: BorderRadius.circular(14),
      child: InkWell(
        borderRadius: BorderRadius.circular(14),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(14, 12, 14, 12),
          child: Row(
            children: [
              Container(
                width: 34,
                height: 34,
                decoration: BoxDecoration(
                  color: HomePalette.pill,
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Icon(
                  chat.mode.icon,
                  size: 16,
                  color: HomePalette.text,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      chat.title,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        color: HomePalette.text,
                        fontSize: 14,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      chat.preview,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        color: HomePalette.muted,
                        fontSize: 12,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              Text(
                chat.when,
                style: const TextStyle(
                  color: HomePalette.mutedSoft,
                  fontSize: 11,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _ConversationList extends StatelessWidget {
  const _ConversationList({
    required this.controller,
    required this.messages,
    required this.sending,
  });

  final ScrollController controller;
  final List<_ChatMessage> messages;
  final bool sending;

  @override
  Widget build(BuildContext context) {
    return ListView.builder(
      controller: controller,
      padding: const EdgeInsets.fromLTRB(16, 4, 16, 16),
      itemCount: messages.length + (sending ? 1 : 0),
      itemBuilder: (context, index) {
        if (index == messages.length) {
          return const _TypingIndicator();
        }
        final m = messages[index];
        return _Bubble(message: m);
      },
    );
  }
}

class _Bubble extends StatelessWidget {
  const _Bubble({required this.message});

  final _ChatMessage message;

  @override
  Widget build(BuildContext context) {
    final mine = message.mine;
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Align(
        alignment: mine ? Alignment.centerRight : Alignment.centerLeft,
        child: ConstrainedBox(
          constraints: BoxConstraints(
            maxWidth: MediaQuery.of(context).size.width * 0.82,
          ),
          child: Container(
            padding: const EdgeInsets.fromLTRB(14, 10, 14, 12),
            decoration: BoxDecoration(
              color: mine ? HomePalette.userBubble : HomePalette.botBubble,
              borderRadius: BorderRadius.only(
                topLeft: const Radius.circular(16),
                topRight: const Radius.circular(16),
                bottomLeft: Radius.circular(mine ? 16 : 4),
                bottomRight: Radius.circular(mine ? 4 : 16),
              ),
              border: Border.all(
                color: HomePalette.border,
                width: 0.6,
              ),
            ),
            child: Column(
              crossAxisAlignment:
                  mine ? CrossAxisAlignment.end : CrossAxisAlignment.start,
              children: [
                if (!mine)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 4),
                    child: Text(
                      message.author.toUpperCase(),
                      style: const TextStyle(
                        color: HomePalette.muted,
                        fontSize: 10,
                        letterSpacing: 0.6,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                  ),
                SelectableText(
                  message.text,
                  style: const TextStyle(
                    color: HomePalette.text,
                    fontSize: 14.5,
                    height: 1.42,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _TypingIndicator extends StatelessWidget {
  const _TypingIndicator();

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Align(
        alignment: Alignment.centerLeft,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
          decoration: BoxDecoration(
            color: HomePalette.botBubble,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: HomePalette.border, width: 0.6),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: const [
              _PulseDot(delay: 0),
              SizedBox(width: 5),
              _PulseDot(delay: 120),
              SizedBox(width: 5),
              _PulseDot(delay: 240),
            ],
          ),
        ),
      ),
    );
  }
}

class _PulseDot extends StatefulWidget {
  const _PulseDot({required this.delay});

  final int delay;

  @override
  State<_PulseDot> createState() => _PulseDotState();
}

class _PulseDotState extends State<_PulseDot>
    with SingleTickerProviderStateMixin {
  late final AnimationController _c;

  @override
  void initState() {
    super.initState();
    _c = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 700),
    );
    Future<void>.delayed(Duration(milliseconds: widget.delay), () {
      if (mounted) _c.repeat(reverse: true);
    });
  }

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return FadeTransition(
      opacity: Tween<double>(begin: 0.25, end: 1).animate(_c),
      child: const SizedBox(
        width: 6,
        height: 6,
        child: DecoratedBox(
          decoration: BoxDecoration(
            color: HomePalette.text,
            shape: BoxShape.circle,
          ),
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Composer
// ---------------------------------------------------------------------------

/// Bottom composer: a rounded dark card with the prompt field, an attachment
/// action, the `Chat` / `Coder` mode chips, and the microphone + waveform
/// voice actions on the right.
class _Composer extends StatelessWidget {
  const _Composer({
    required this.controller,
    required this.focusNode,
    required this.mode,
    required this.sending,
    required this.onMode,
    required this.onAttach,
    required this.onMic,
    required this.onWave,
    required this.onSubmit,
  });

  final TextEditingController controller;
  final FocusNode focusNode;
  final AgentMode mode;
  final bool sending;
  final ValueChanged<AgentMode> onMode;
  final VoidCallback onAttach;
  final VoidCallback onMic;
  final VoidCallback onWave;
  final VoidCallback onSubmit;

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      top: false,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(12, 6, 12, 12),
        child: Container(
          decoration: BoxDecoration(
            color: HomePalette.composer,
            borderRadius: BorderRadius.circular(24),
            border: Border.all(color: HomePalette.composerEdge),
          ),
          padding: const EdgeInsets.fromLTRB(14, 12, 12, 10),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              TextField(
                controller: controller,
                focusNode: focusNode,
                minLines: 1,
                maxLines: 5,
                cursorColor: HomePalette.text,
                style: const TextStyle(
                  color: HomePalette.text,
                  fontSize: 15.5,
                  height: 1.35,
                ),
                onSubmitted: (_) => onSubmit(),
                decoration: const InputDecoration(
                  isDense: true,
                  border: InputBorder.none,
                  enabledBorder: InputBorder.none,
                  focusedBorder: InputBorder.none,
                  filled: false,
                  hintText: 'Pregunta algo...',
                  hintStyle: TextStyle(
                    color: HomePalette.muted,
                    fontSize: 15.5,
                    fontWeight: FontWeight.w400,
                  ),
                ),
              ),
              const SizedBox(height: 10),
              Row(
                children: [
                  _RoundIconButton(
                    icon: Icons.add_rounded,
                    onTap: onAttach,
                    diameter: 32,
                    background: HomePalette.pillSoft,
                  ),
                  const SizedBox(width: 8),
                  _ModeChip(
                    label: AgentMode.chat.label,
                    selected: mode == AgentMode.chat,
                    onTap: () => onMode(AgentMode.chat),
                  ),
                  const SizedBox(width: 6),
                  _ModeChip(
                    label: AgentMode.coder.label,
                    selected: mode == AgentMode.coder,
                    onTap: () => onMode(AgentMode.coder),
                  ),
                  const Spacer(),
                  if (sending)
                    const Padding(
                      padding: EdgeInsets.symmetric(horizontal: 6),
                      child: SizedBox(
                        width: 16,
                        height: 16,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: HomePalette.text,
                        ),
                      ),
                    ),
                  _PlainIconButton(
                    icon: Icons.mic_none_rounded,
                    onTap: onMic,
                  ),
                  const SizedBox(width: 4),
                  _PlainIconButton(
                    icon: Icons.graphic_eq_rounded,
                    onTap: onWave,
                  ),
                ],
              ),
            ],
          ),
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
      behavior: HitTestBehavior.opaque,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 140),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 7),
        decoration: BoxDecoration(
          color: selected ? HomePalette.chip : HomePalette.pillSoft,
          borderRadius: BorderRadius.circular(18),
        ),
        child: Text(
          label,
          style: TextStyle(
            color: selected ? HomePalette.chipText : HomePalette.muted,
            fontSize: 13,
            fontWeight: FontWeight.w700,
          ),
        ),
      ),
    );
  }
}

class _RoundIconButton extends StatelessWidget {
  const _RoundIconButton({
    required this.icon,
    required this.onTap,
    this.diameter = 34,
    this.background = HomePalette.pillSoft,
    this.iconColor = HomePalette.text,
    this.iconSize = 18,
  });

  final IconData icon;
  final VoidCallback onTap;
  final double diameter;
  final Color background;
  final Color iconColor;
  final double iconSize;

  @override
  Widget build(BuildContext context) {
    return InkResponse(
      onTap: onTap,
      radius: diameter,
      child: Container(
        width: diameter,
        height: diameter,
        decoration: BoxDecoration(
          color: background,
          shape: BoxShape.circle,
          border: Border.all(color: HomePalette.border, width: 0.6),
        ),
        child: Icon(icon, size: iconSize, color: iconColor),
      ),
    );
  }
}

class _PlainIconButton extends StatelessWidget {
  const _PlainIconButton({
    required this.icon,
    required this.onTap,
    this.color = HomePalette.text,
    this.size = 22,
  });

  final IconData icon;
  final VoidCallback onTap;
  final Color color;
  final double size;

  @override
  Widget build(BuildContext context) {
    return InkResponse(
      onTap: onTap,
      radius: 22,
      child: Padding(
        padding: const EdgeInsets.all(6),
        child: Icon(icon, size: size, color: color),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Attachment sheet
// ---------------------------------------------------------------------------

class _AttachmentSheet extends StatelessWidget {
  const _AttachmentSheet({required this.onPick});

  final ValueChanged<String> onPick;

  static const _options = <(IconData, String, String)>[
    (Icons.photo_outlined, 'Foto', 'Adjuntar una imagen del carrete'),
    (Icons.attach_file_rounded, 'Archivo', 'Subir cualquier documento'),
    (Icons.code_rounded, 'Snippet', 'Pegar un fragmento de código'),
    (Icons.folder_outlined, 'Proyecto', 'Añadir un proyecto existente'),
    (Icons.terminal_rounded, 'Comando', 'Insertar un comando de terminal'),
    (Icons.psychology_outlined, 'Memoria', 'Guardar en la memoria de Numi'),
  ];

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(18, 18, 18, 12),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Center(
              child: Container(
                width: 42,
                height: 4,
                decoration: BoxDecoration(
                  color: HomePalette.mutedSoft,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),
            const SizedBox(height: 16),
            const Text(
              'Adjuntar',
              style: TextStyle(
                color: HomePalette.text,
                fontSize: 16,
                fontWeight: FontWeight.w800,
              ),
            ),
            const SizedBox(height: 10),
            for (final (icon, title, subtitle) in _options)
              ListTile(
                contentPadding: EdgeInsets.zero,
                leading: Container(
                  width: 38,
                  height: 38,
                  decoration: BoxDecoration(
                    color: HomePalette.pillSoft,
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Icon(icon, size: 18, color: HomePalette.text),
                ),
                title: Text(
                  title,
                  style: const TextStyle(
                    color: HomePalette.text,
                    fontWeight: FontWeight.w700,
                    fontSize: 14,
                  ),
                ),
                subtitle: Text(
                  subtitle,
                  style: const TextStyle(
                    color: HomePalette.muted,
                    fontSize: 12,
                  ),
                ),
                onTap: () => onPick(title),
              ),
          ],
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Voice overlay
// ---------------------------------------------------------------------------

class _VoiceOverlay extends StatelessWidget {
  const _VoiceOverlay({
    required this.pulse,
    required this.onCancel,
    required this.onSend,
  });

  final AnimationController pulse;
  final VoidCallback onCancel;
  final VoidCallback onSend;

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.fromLTRB(12, 0, 12, 8),
      padding: const EdgeInsets.fromLTRB(16, 14, 12, 14),
      decoration: BoxDecoration(
        color: HomePalette.pill,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: HomePalette.border),
      ),
      child: Row(
        children: [
          AnimatedBuilder(
            animation: pulse,
            builder: (_, __) {
              final t = pulse.value;
              return Container(
                width: 12 + 4 * t,
                height: 12 + 4 * t,
                decoration: const BoxDecoration(
                  color: HomePalette.danger,
                  shape: BoxShape.circle,
                ),
              );
            },
          ),
          const SizedBox(width: 14),
          const Expanded(
            child: Text(
              'Grabando…',
              style: TextStyle(
                color: HomePalette.text,
                fontSize: 14,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
          TextButton(
            onPressed: onCancel,
            child: const Text(
              'Cancelar',
              style: TextStyle(color: HomePalette.muted),
            ),
          ),
          const SizedBox(width: 4),
          FilledButton(
            onPressed: onSend,
            style: FilledButton.styleFrom(
              backgroundColor: HomePalette.chip,
              foregroundColor: HomePalette.chipText,
            ),
            child: const Text('Enviar'),
          ),
        ],
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Navigation drawer
// ---------------------------------------------------------------------------

class _NavDrawer extends StatelessWidget {
  const _NavDrawer({
    required this.user,
    required this.onOpenProjects,
    required this.onOpenWorkspace,
    required this.onOpenChat,
    required this.onOpenMemory,
    required this.onOpenCredits,
    required this.onOpenSettings,
    required this.onOpenNotifications,
    required this.onOpenProfile,
    this.onOpenOwner,
  });

  final AppUser? user;
  final VoidCallback onOpenProjects;
  final VoidCallback onOpenWorkspace;
  final VoidCallback onOpenChat;
  final VoidCallback onOpenMemory;
  final VoidCallback onOpenCredits;
  final VoidCallback onOpenSettings;
  final VoidCallback onOpenNotifications;
  final VoidCallback onOpenProfile;
  final VoidCallback? onOpenOwner;

  @override
  Widget build(BuildContext context) {
    return Drawer(
      backgroundColor: HomePalette.surface,
      child: SafeArea(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(18, 20, 18, 12),
              child: Row(
                children: [
                  const Icon(
                    Icons.auto_awesome,
                    color: HomePalette.text,
                    size: 20,
                  ),
                  const SizedBox(width: 10),
                  const Text(
                    'Numination',
                    style: TextStyle(
                      color: HomePalette.text,
                      fontWeight: FontWeight.w800,
                      fontSize: 17,
                    ),
                  ),
                ],
              ),
            ),
            if (user != null)
              Padding(
                padding: const EdgeInsets.fromLTRB(18, 0, 18, 12),
                child: Row(
                  children: [
                    CircleAvatar(
                      radius: 16,
                      backgroundColor: HomePalette.pill,
                      child: Text(
                        user!.email.isNotEmpty
                            ? user!.email[0].toUpperCase()
                            : 'N',
                        style: const TextStyle(
                          color: HomePalette.text,
                          fontWeight: FontWeight.w800,
                          fontSize: 13,
                        ),
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            user!.email.split('@').first,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                              color: HomePalette.text,
                              fontSize: 13,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                          Text(
                            '${user!.tier} · ${user!.balance} créditos',
                            style: const TextStyle(
                              color: HomePalette.muted,
                              fontSize: 11,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            const Divider(color: HomePalette.divider, height: 1),
            const SizedBox(height: 6),
            _DrawerItem(
              icon: Icons.folder_outlined,
              label: 'Proyectos',
              onTap: onOpenProjects,
            ),
            _DrawerItem(
              icon: Icons.code_rounded,
              label: 'Workspace',
              onTap: onOpenWorkspace,
            ),
            _DrawerItem(
              icon: Icons.auto_awesome,
              label: 'AI Chat',
              onTap: onOpenChat,
            ),
            _DrawerItem(
              icon: Icons.psychology_outlined,
              label: 'Memoria',
              onTap: onOpenMemory,
            ),
            _DrawerItem(
              icon: Icons.bolt_outlined,
              label: 'Créditos',
              onTap: onOpenCredits,
            ),
            const Divider(color: HomePalette.divider, height: 20),
            _DrawerItem(
              icon: Icons.notifications_none,
              label: 'Notificaciones',
              onTap: onOpenNotifications,
            ),
            _DrawerItem(
              icon: Icons.account_circle_outlined,
              label: 'Perfil',
              onTap: onOpenProfile,
            ),
            _DrawerItem(
              icon: Icons.settings_outlined,
              label: 'Configuración',
              onTap: onOpenSettings,
            ),
            if (onOpenOwner != null)
              _DrawerItem(
                icon: Icons.admin_panel_settings_outlined,
                label: 'Consola del propietario',
                onTap: onOpenOwner!,
              ),
            const Spacer(),
            const Padding(
              padding: EdgeInsets.fromLTRB(18, 0, 18, 14),
              child: Text(
                'Numination · AI workspace',
                style: TextStyle(
                  color: HomePalette.mutedSoft,
                  fontSize: 11,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _DrawerItem extends StatelessWidget {
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
    return ListTile(
      leading: Icon(icon, color: HomePalette.muted, size: 20),
      title: Text(
        label,
        style: const TextStyle(
          color: HomePalette.text,
          fontSize: 14,
          fontWeight: FontWeight.w600,
        ),
      ),
      onTap: onTap,
    );
  }
}

// ---------------------------------------------------------------------------
// Legacy dashboard (kept, reachable from the drawer)
// ---------------------------------------------------------------------------

/// Original dashboard tab. Preserved verbatim so existing navigation from
/// the drawer (and any deep links that resolve to it) keeps working.
class DashboardTab extends ConsumerWidget {
  const DashboardTab({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final projects = ref.watch(projectsProvider);

    return Scaffold(
      backgroundColor: AppColors.obsidian,
      appBar: AppBar(title: const Text('Proyectos')),
      body: RefreshIndicator(
        onRefresh: () => ref.read(projectsProvider.notifier).refresh(),
        child: ListView(
          padding: const EdgeInsets.all(18),
          children: [
            GlassCard(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    '¿Qué estás construyendo hoy?',
                    style: TextStyle(
                      fontSize: 24,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                  const SizedBox(height: 6),
                  const Text(
                    'Tu workspace, memoria y asistente en un solo lugar.',
                    style: TextStyle(color: AppColors.muted),
                  ),
                  const SizedBox(height: 16),
                  Wrap(
                    spacing: 10,
                    runSpacing: 10,
                    children: [
                      FilledButton.icon(
                        onPressed: () {
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (_) => const WorkspaceScreen(),
                            ),
                          );
                        },
                        icon: const Icon(Icons.add),
                        label: const Text('Nuevo proyecto'),
                      ),
                      OutlinedButton.icon(
                        onPressed: () {
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (_) => const ChatScreen(),
                            ),
                          );
                        },
                        icon: const Icon(Icons.auto_awesome),
                        label: const Text('Preguntar a AI'),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            const SizedBox(height: 14),
            Row(
              children: [
                Expanded(
                  child: GlassCard(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'Créditos',
                          style: TextStyle(color: AppColors.muted),
                        ),
                        Text(
                          ref.watch(authControllerProvider)
                                  is AuthAuthenticated
                              ? (ref.watch(authControllerProvider)
                                      as AuthAuthenticated)
                                  .user
                                  .balance
                                  .toString()
                              : '—',
                          style: const TextStyle(
                            fontSize: 30,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                        const Text(
                          'Plan actual',
                          style: TextStyle(color: AppColors.cyan),
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                const Expanded(
                  child: GlassCard(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Memoria',
                          style: TextStyle(color: AppColors.muted),
                        ),
                        Text(
                          'Persistente',
                          style: TextStyle(
                            fontSize: 22,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                        Text(
                          'NUMINATION.md + recuerdos',
                          style: TextStyle(color: AppColors.muted),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 20),
            const Text(
              'Proyectos recientes',
              style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.w800,
              ),
            ),
            const SizedBox(height: 10),
            ...projects.when(
              data: (items) {
                if (items.isEmpty) {
                  return [
                    const GlassCard(
                      child: Column(
                        children: [
                          Icon(
                            Icons.folder_open,
                            size: 42,
                            color: AppColors.cyan,
                          ),
                          SizedBox(height: 10),
                          Text('Aún no tienes proyectos'),
                          SizedBox(height: 4),
                          Text(
                            'Crea uno y Numination preparará su memoria inicial.',
                            style: TextStyle(color: AppColors.muted),
                          ),
                        ],
                      ),
                    ),
                  ];
                }
                return _projectList(context, items);
              },
              loading: () => [
                const Center(child: CircularProgressIndicator()),
              ],
              error: (e, _) => [
                GlassCard(
                  child: Text(
                    'No se pudieron cargar los proyectos: $e',
                    style: const TextStyle(color: AppColors.red),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  List<Widget> _projectList(BuildContext context, List<Project> items) {
    return items
        .take(8)
        .map(
          (p) => Padding(
            padding: const EdgeInsets.only(bottom: 10),
            child: GlassCard(
              onTap: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) => WorkspaceScreen(initialProject: p),
                  ),
                );
              },
              child: Row(
                children: [
                  Container(
                    width: 44,
                    height: 44,
                    decoration: BoxDecoration(
                      color: AppColors.cyan.withValues(alpha: .12),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: const Icon(Icons.folder, color: AppColors.cyan),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          p.name,
                          style: const TextStyle(fontWeight: FontWeight.w800),
                        ),
                        Text(
                          p.description.isEmpty
                              ? 'Proyecto en Numination'
                              : p.description,
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(color: AppColors.muted),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
        )
        .toList();
  }
}