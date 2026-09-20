import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/i18n.dart';
import '../../core/theme_controller.dart';

class PrivacyScreen extends ConsumerStatefulWidget {
  const PrivacyScreen({super.key});

  @override
  ConsumerState<PrivacyScreen> createState() => _PrivacyScreenState();
}

class _PrivacyScreenState extends ConsumerState<PrivacyScreen> {
  bool _shareUsageData = false;
  bool _saveHistory = true;

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
          AppLocale.t('privacy'),
          style: TextStyle(color: palette.textPrimary),
        ),
      ),
      body: ListView(
        children: [
          SwitchListTile(
            value: _saveHistory,
            onChanged: (v) => setState(() => _saveHistory = v),
            activeThumbColor: palette.accent,
            title: Text(
              'Guardar historial de chats',
              style: TextStyle(color: palette.textPrimary),
            ),
            subtitle: Text(
              'Tus chats normales (no incógnito) se guardan en tu cuenta',
              style: TextStyle(color: palette.textSecondary, fontSize: 12),
            ),
          ),
          SwitchListTile(
            value: _shareUsageData,
            onChanged: (v) => setState(() => _shareUsageData = v),
            activeThumbColor: palette.accent,
            title: Text(
              'Compartir datos de uso anónimos',
              style: TextStyle(color: palette.textPrimary),
            ),
            subtitle: Text(
              'Ayuda a mejorar Numination',
              style: TextStyle(color: palette.textSecondary, fontSize: 12),
            ),
          ),
          const SizedBox(height: 8),
          ListTile(
            leading: Icon(Icons.delete_outline, color: Colors.redAccent),
            title: const Text(
              'Eliminar todos mis chats',
              style: TextStyle(color: Colors.redAccent),
            ),
            onTap: () {},
          ),
        ],
      ),
    );
  }
}
