import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/i18n.dart';
import '../../core/theme_controller.dart';

class NotificationScreen extends ConsumerStatefulWidget {
  const NotificationScreen({super.key});

  @override
  ConsumerState<NotificationScreen> createState() => _NotificationScreenState();
}

class _NotificationScreenState extends ConsumerState<NotificationScreen> {
  bool _chatReplies = true;
  bool _productUpdates = true;
  bool _security = true;

  @override
  Widget build(BuildContext context) {
    final palette = ref.watch(appPaletteProvider);

    return Scaffold(
      backgroundColor: palette.background,
      appBar: AppBar(
        backgroundColor: palette.background,
        elevation: 0,
        iconTheme: IconThemeData(color: palette.textPrimary),
        title: Text(
          AppLocale.t('notifications'),
          style: TextStyle(color: palette.textPrimary),
        ),
      ),
      body: ListView(
        children: [
          SwitchListTile(
            value: _chatReplies,
            onChanged: (v) => setState(() => _chatReplies = v),
            activeThumbColor: palette.accent,
            title: Text(
              'Respuestas de chat',
              style: TextStyle(color: palette.textPrimary),
            ),
            subtitle: Text(
              'Avisar cuando Numination termine de responder',
              style: TextStyle(color: palette.textSecondary, fontSize: 12),
            ),
          ),
          SwitchListTile(
            value: _productUpdates,
            onChanged: (v) => setState(() => _productUpdates = v),
            activeThumbColor: palette.accent,
            title: Text(
              'Novedades del producto',
              style: TextStyle(color: palette.textPrimary),
            ),
            subtitle: Text(
              'Nuevas funciones y anuncios',
              style: TextStyle(color: palette.textSecondary, fontSize: 12),
            ),
          ),
          SwitchListTile(
            value: _security,
            onChanged: (v) => setState(() => _security = v),
            activeThumbColor: palette.accent,
            title: Text(
              'Seguridad de la cuenta',
              style: TextStyle(color: palette.textPrimary),
            ),
            subtitle: Text(
              'Inicios de sesión y cambios importantes',
              style: TextStyle(color: palette.textSecondary, fontSize: 12),
            ),
          ),
        ],
      ),
    );
  }
}
