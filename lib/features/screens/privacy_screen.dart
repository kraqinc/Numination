import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/api.dart';
import '../../core/i18n.dart';
import '../../core/theme_controller.dart';
import 'package:numination/core/numi_icons.dart';

class PrivacyScreen extends ConsumerStatefulWidget {
  const PrivacyScreen({super.key});

  @override
  ConsumerState<PrivacyScreen> createState() => _PrivacyScreenState();
}

class _PrivacyScreenState extends ConsumerState<PrivacyScreen> {
  bool _shareUsageData = false;
  bool _saveHistory = true;
  bool _isDeleting = false;

  Future<void> _deleteAllChats() async {
    if (_isDeleting) return;

    final palette = ref.read(appPaletteProvider);
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        backgroundColor: palette.surface,
        title: Text(
          'Eliminar todos mis chats',
          style: TextStyle(color: palette.textPrimary),
        ),
        content: Text(
          'Se eliminarán permanentemente tus chats normales y sus mensajes. Esta acción no se puede deshacer.',
          style: TextStyle(color: palette.textSecondary, height: 1.4),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(false),
            child: Text(
              'Cancelar',
              style: TextStyle(color: palette.textSecondary),
            ),
          ),
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(true),
            child: const Text(
              'Eliminar todos',
              style: TextStyle(
                color: Colors.redAccent,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
        ],
      ),
    );

    if (confirmed != true || !mounted) return;

    setState(() => _isDeleting = true);
    try {
      final response = await ApiClient.delete('/chats');
      ApiClient.decode(response);

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Se eliminaron todos tus chats.')),
      );
    } on ApiException catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(e.message)));
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('No se pudieron eliminar los chats.')),
      );
    } finally {
      if (mounted) setState(() => _isDeleting = false);
    }
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
            leading: Icon(NumiIcons.delete_outline, color: Colors.redAccent),
            title: const Text(
              'Eliminar todos mis chats',
              style: TextStyle(color: Colors.redAccent),
            ),
            onTap: _isDeleting ? null : _deleteAllChats,
            trailing: _isDeleting
                ? const SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : null,
          ),
        ],
      ),
    );
  }
}
