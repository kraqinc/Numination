import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/auth_controller.dart';
import '../../core/i18n.dart';
import '../../core/theme_controller.dart';
import '../../core/update_controller.dart';
import 'custom_strings.dart';
import 'memory_screen.dart';
import 'notification_screen.dart';
import 'privacy_screen.dart';
import 'subscription_coder_screen.dart';
import 'theme_screen.dart';
import 'package:numination/core/numi_icons.dart';

class SettingsScreen extends ConsumerWidget {
  const SettingsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final auth = ref.watch(authControllerProvider);
    final palette = ref.watch(appPaletteProvider);
    final email = auth is AuthAuthenticated ? auth.email : '';
    final autoUpdatesEnabled = ref.watch(autoUpdateProvider);

    return Scaffold(
      backgroundColor: palette.background,
      appBar: AppBar(
        backgroundColor: palette.background,
        elevation: 0,
        iconTheme: IconThemeData(color: palette.textPrimary),
        title: Text(
          AppLocale.t('settings'),
          style: TextStyle(color: palette.textPrimary),
        ),
      ),
      body: ListView(
        padding: const EdgeInsets.symmetric(vertical: 12),
        children: [
          _SettingsTile(
            icon: NumiIcons.person_outline,
            label: AppLocale.t('profile'),
            subtitle: email,
            onTap: () => Navigator.of(context).push(
              MaterialPageRoute(builder: (_) => const CustomStringsScreen()),
            ),
          ),
          _SettingsSectionDivider(color: palette.border),
          _SettingsTile(
            icon: NumiIcons.memory_outlined,
            label: AppLocale.t('memory'),
            subtitle: 'Lo que Numination recuerda de tus chats',
            onTap: () => Navigator.of(
              context,
            ).push(MaterialPageRoute(builder: (_) => const MemoryScreen())),
          ),
          _SettingsTile(
            icon: NumiIcons.notifications_outlined,
            label: AppLocale.t('notifications'),
            onTap: () => Navigator.of(context).push(
              MaterialPageRoute(builder: (_) => const NotificationScreen()),
            ),
          ),
          _SettingsTile(
            icon: NumiIcons.privacy_tip_outlined,
            label: AppLocale.t('privacy'),
            onTap: () => Navigator.of(
              context,
            ).push(MaterialPageRoute(builder: (_) => const PrivacyScreen())),
          ),
          _SettingsSectionDivider(color: palette.border),
          _SettingsTile(
            icon: NumiIcons.palette_outlined,
            label: AppLocale.t('change_theme'),
            onTap: () => Navigator.of(
              context,
            ).push(MaterialPageRoute(builder: (_) => const ThemeScreen())),
          ),
          _SettingsSectionDivider(color: palette.border),

          SwitchListTile(
            value: autoUpdatesEnabled,
            onChanged: (value) {
              ref.read(autoUpdateProvider.notifier).setEnabled(value);
            },
            activeThumbColor: palette.accent,
            title: Text(
              'Actualizaciones automáticas',
              style: TextStyle(color: palette.textPrimary, fontSize: 16),
            ),
            subtitle: Text(
              'Detecta y descarga nuevas versiones de Numination automáticamente',
              style: TextStyle(color: palette.textSecondary, fontSize: 12),
            ),
          ),

          _SettingsSectionDivider(color: palette.border),
          _SettingsTile(
            icon: NumiIcons.workspace_premium_outlined,
            label: AppLocale.t('coder_subscription'),
            onTap: () => Navigator.of(context).push(
              MaterialPageRoute(
                builder: (_) => const SubscriptionCoderScreen(),
              ),
            ),
          ),
          _SettingsSectionDivider(color: palette.border),
          _SettingsTile(
            icon: NumiIcons.logout,
            label: AppLocale.t('log_out'),
            iconColor: Colors.redAccent,
            labelColor: Colors.redAccent,
            onTap: () async {
              await ref.read(authControllerProvider.notifier).signOut();
            },
          ),
        ],
      ),
    );
  }
}

class _SettingsSectionDivider extends StatelessWidget {
  const _SettingsSectionDivider({required this.color});
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Divider(color: color, height: 1),
    );
  }
}

class _SettingsTile extends ConsumerWidget {
  const _SettingsTile({
    required this.icon,
    required this.label,
    this.subtitle,
    this.iconColor,
    this.labelColor,
    required this.onTap,
  });

  final IconData icon;
  final String label;
  final String? subtitle;
  final Color? iconColor;
  final Color? labelColor;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final palette = ref.watch(appPaletteProvider);
    return ListTile(
      leading: Icon(icon, color: iconColor ?? palette.textPrimary),
      title: Text(
        label,
        style: TextStyle(
          color: labelColor ?? palette.textPrimary,
          fontSize: 16,
        ),
      ),
      subtitle: subtitle != null && subtitle!.isNotEmpty
          ? Text(
              subtitle!,
              style: TextStyle(color: palette.textSecondary, fontSize: 13),
            )
          : null,
      trailing: Icon(NumiIcons.chevron_right, color: palette.textSecondary),
      onTap: onTap,
    );
  }
}
