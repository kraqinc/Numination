import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lucide_flutter/lucide_flutter.dart';

import '../../core/api.dart';
import '../../core/theme_controller.dart';

class NotificationScreen extends ConsumerStatefulWidget {
  const NotificationScreen({super.key});

  @override
  ConsumerState<NotificationScreen> createState() => _NotificationScreenState();
}

class _NotificationScreenState extends ConsumerState<NotificationScreen>
    with WidgetsBindingObserver {
  final List<Map<String, dynamic>> _items = <Map<String, dynamic>>[];
  Timer? _refreshTimer;
  bool _loading = true;
  bool _busy = false;
  String? _error;
  int _unread = 0;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _load();
    _refreshTimer = Timer.periodic(const Duration(seconds: 35), (_) {
      unawaited(_load(silent: true));
    });
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _refreshTimer?.cancel();
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      unawaited(_load(silent: true));
    }
  }

  Future<void> _load({bool silent = false}) async {
    if (_busy) {
      return;
    }
    _busy = true;
    if (!silent && mounted) {
      setState(() {
        _loading = true;
        _error = null;
      });
    }

    try {
      final response = await ApiClient.get('/notifications');
      final decoded = ApiClient.decode(response) as Map<String, dynamic>;
      final rows = (decoded['notifications'] as List? ?? const [])
          .whereType<Map>()
          .map((row) => Map<String, dynamic>.from(row))
          .toList(growable: false);
      if (!mounted) {
        return;
      }
      setState(() {
        _items
          ..clear()
          ..addAll(rows);
        _unread =
            (decoded['unread'] as num?)?.toInt() ??
            rows.where((row) => row['read'] != true).length;
        _error = null;
        _loading = false;
      });
    } catch (error) {
      if (!mounted) {
        return;
      }
      setState(() {
        _error = error is ApiException
            ? error.message
            : 'No pudimos cargar las notificaciones.';
        _loading = false;
      });
    } finally {
      _busy = false;
    }
  }

  Future<void> _markRead(Map<String, dynamic> item) async {
    if (item['read'] == true) {
      return;
    }
    final id = item['id']?.toString();
    if (id == null || id.isEmpty) {
      return;
    }
    setState(() {
      item['read'] = true;
      if (_unread > 0) {
        _unread -= 1;
      }
    });
    try {
      final response = await ApiClient.post('/notifications', {
        'action': 'mark_read',
        'id': id,
      });
      ApiClient.decode(response);
    } catch (_) {
      if (!mounted) {
        return;
      }
      await _load(silent: true);
      if (!mounted) {
        return;
      }
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('No se pudo marcar como leída.')),
      );
    }
  }

  Future<void> _markAllRead() async {
    if (_unread == 0) {
      return;
    }
    try {
      final response = await ApiClient.post('/notifications', {
        'action': 'mark_all_read',
      });
      ApiClient.decode(response);
      if (!mounted) {
        return;
      }
      setState(() {
        for (final item in _items) {
          item['read'] = true;
        }
        _unread = 0;
      });
    } catch (_) {
      if (!mounted) {
        return;
      }
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('No se pudieron marcar todas como leídas.'),
        ),
      );
    }
  }

  IconData _iconFor(String type) {
    final normalized = type.toUpperCase();
    if (normalized.contains('FEEDBACK')) {
      return LucideIcons.messageSquare;
    }
    if (normalized.contains('PROJECT')) {
      return LucideIcons.folder;
    }
    if (normalized.contains('SECURITY') || normalized.contains('AUTH')) {
      return LucideIcons.shieldCheck;
    }
    if (normalized.contains('CREDIT') || normalized.contains('BILLING')) {
      return LucideIcons.coins;
    }
    if (normalized.contains('UPDATE') || normalized.contains('VERSION')) {
      return LucideIcons.packageCheck;
    }
    return LucideIcons.bell;
  }

  String _relativeTime(dynamic value) {
    final parsed = DateTime.tryParse(value?.toString() ?? '')?.toLocal();
    if (parsed == null) {
      return 'Fecha no disponible';
    }
    final elapsed = DateTime.now().difference(parsed);
    if (elapsed.inSeconds < 60) {
      return 'Ahora';
    }
    if (elapsed.inMinutes < 60) {
      return 'Hace ${elapsed.inMinutes} min';
    }
    if (elapsed.inHours < 24) {
      return 'Hace ${elapsed.inHours} h';
    }
    if (elapsed.inDays < 7) {
      return 'Hace ${elapsed.inDays} días';
    }
    return '${parsed.day.toString().padLeft(2, '0')}/${parsed.month.toString().padLeft(2, '0')}/${parsed.year}';
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
          children: [
            const Icon(LucideIcons.bellRing, size: 21),
            const SizedBox(width: 10),
            const Text('Notificaciones'),
            if (_unread > 0) ...[
              const SizedBox(width: 9),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  color: palette.accent.withValues(alpha: .16),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Text(
                  '$_unread',
                  style: TextStyle(
                    color: palette.accent,
                    fontSize: 12,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ),
            ],
          ],
        ),
        actions: [
          IconButton(
            tooltip: 'Actualizar',
            onPressed: () => _load(),
            icon: const Icon(LucideIcons.refreshCw),
          ),
          if (_unread > 0)
            IconButton(
              tooltip: 'Marcar todo como leído',
              onPressed: _markAllRead,
              icon: const Icon(LucideIcons.checkCheck),
            ),
        ],
      ),
      body: AnimatedSwitcher(
        duration: const Duration(milliseconds: 260),
        switchInCurve: Curves.easeOutCubic,
        child: _loading && _items.isEmpty
            ? const Center(
                key: ValueKey('loading'),
                child: CircularProgressIndicator(),
              )
            : _error != null && _items.isEmpty
            ? Center(
                key: const ValueKey('error'),
                child: Padding(
                  padding: const EdgeInsets.all(28),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(LucideIcons.cloudOff, size: 38),
                      const SizedBox(height: 14),
                      Text(_error!, textAlign: TextAlign.center),
                      const SizedBox(height: 14),
                      FilledButton.icon(
                        onPressed: () => _load(),
                        icon: const Icon(LucideIcons.refreshCw),
                        label: const Text('Intentar de nuevo'),
                      ),
                    ],
                  ),
                ),
              )
            : RefreshIndicator(
                key: const ValueKey('feed'),
                onRefresh: _load,
                child: _items.isEmpty
                    ? ListView(
                        physics: const AlwaysScrollableScrollPhysics(),
                        children: [
                          const SizedBox(height: 100),
                          Icon(
                            LucideIcons.bellOff,
                            size: 42,
                            color: palette.textSecondary,
                          ),
                          const SizedBox(height: 16),
                          Text(
                            'Todo al día',
                            textAlign: TextAlign.center,
                            style: TextStyle(
                              color: palette.textPrimary,
                              fontSize: 18,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                          const SizedBox(height: 6),
                          Text(
                            'Aquí aparecerán los avisos reales de tu cuenta y tus proyectos.',
                            textAlign: TextAlign.center,
                            style: TextStyle(color: palette.textSecondary),
                          ),
                        ],
                      )
                    : ListView.separated(
                        physics: const AlwaysScrollableScrollPhysics(),
                        padding: const EdgeInsets.fromLTRB(16, 10, 16, 28),
                        itemCount: _items.length,
                        separatorBuilder: (_, _) => const SizedBox(height: 9),
                        itemBuilder: (context, index) {
                          final item = _items[index];
                          final read = item['read'] == true;
                          final title =
                              item['title']?.toString() ?? 'Notificación';
                          final message = item['message']?.toString() ?? '';
                          return TweenAnimationBuilder<double>(
                            key: ValueKey(item['id'] ?? index),
                            tween: Tween(begin: .94, end: 1),
                            duration: Duration(
                              milliseconds:
                                  190 + (index.clamp(0, 8).toInt() * 35),
                            ),
                            curve: Curves.easeOutCubic,
                            builder: (context, value, child) => Opacity(
                              opacity: value.clamp(0, 1),
                              child: Transform.translate(
                                offset: Offset(0, (1 - value) * 14),
                                child: Transform.scale(
                                  scale: value,
                                  child: child,
                                ),
                              ),
                            ),
                            child: Material(
                              color: Colors.transparent,
                              child: InkWell(
                                borderRadius: BorderRadius.circular(18),
                                onTap: () => _markRead(item),
                                child: AnimatedContainer(
                                  duration: const Duration(milliseconds: 220),
                                  padding: const EdgeInsets.all(14),
                                  decoration: BoxDecoration(
                                    color: read
                                        ? palette.surface
                                        : palette.accent.withValues(alpha: .09),
                                    borderRadius: BorderRadius.circular(18),
                                    border: Border.all(
                                      color: read
                                          ? palette.border
                                          : palette.accent.withValues(
                                              alpha: .42,
                                            ),
                                    ),
                                  ),
                                  child: Row(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      Container(
                                        width: 42,
                                        height: 42,
                                        decoration: BoxDecoration(
                                          color: palette.accent.withValues(
                                            alpha: .12,
                                          ),
                                          borderRadius: BorderRadius.circular(
                                            13,
                                          ),
                                        ),
                                        child: Icon(
                                          _iconFor(
                                            item['type']?.toString() ?? '',
                                          ),
                                          color: palette.accent,
                                          size: 20,
                                        ),
                                      ),
                                      const SizedBox(width: 12),
                                      Expanded(
                                        child: Column(
                                          crossAxisAlignment:
                                              CrossAxisAlignment.start,
                                          children: [
                                            Row(
                                              children: [
                                                Expanded(
                                                  child: Text(
                                                    title,
                                                    maxLines: 2,
                                                    overflow:
                                                        TextOverflow.ellipsis,
                                                    style: TextStyle(
                                                      color:
                                                          palette.textPrimary,
                                                      fontWeight: read
                                                          ? FontWeight.w600
                                                          : FontWeight.w800,
                                                    ),
                                                  ),
                                                ),
                                                if (!read)
                                                  Container(
                                                    width: 7,
                                                    height: 7,
                                                    decoration: BoxDecoration(
                                                      color: palette.accent,
                                                      shape: BoxShape.circle,
                                                    ),
                                                  ),
                                              ],
                                            ),
                                            if (message.isNotEmpty) ...[
                                              const SizedBox(height: 5),
                                              Text(
                                                message,
                                                style: TextStyle(
                                                  color: palette.textSecondary,
                                                  height: 1.4,
                                                ),
                                              ),
                                            ],
                                            const SizedBox(height: 8),
                                            Text(
                                              _relativeTime(
                                                item['createdAt'] ??
                                                    item['created_at'],
                                              ),
                                              style: TextStyle(
                                                color: palette.textSecondary
                                                    .withValues(alpha: .85),
                                                fontSize: 11,
                                              ),
                                            ),
                                          ],
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                            ),
                          );
                        },
                      ),
              ),
      ),
    );
  }
}
