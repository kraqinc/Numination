import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../core/auth_controller.dart';
import '../../core/i18n.dart';
import '../../core/theme_controller.dart';
import '../../core/update_controller.dart';
import 'custom_strings.dart';
import 'memory_screen.dart';
import 'notification_screen.dart';
import 'privacy_screen.dart';
import 'credits_hub_screen.dart';
import 'email_preferences_screen.dart';
import 'plans_screen.dart';
import 'theme_screen.dart';
import 'package:numination/core/numi_icons.dart';

class SettingsScreen extends ConsumerWidget {
  const SettingsScreen({super.key, this.desktopSheet = false});

  final bool desktopSheet;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final auth = ref.watch(authControllerProvider);
    final palette = ref.watch(appPaletteProvider);
    final email = auth is AuthAuthenticated ? auth.email : '';
    final autoUpdatesEnabled = ref.watch(autoUpdateProvider);

    final settingsList = ListView(
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
          subtitle: AppLocale.t('memory_subtitle'),
          onTap: () => Navigator.of(
            context,
          ).push(MaterialPageRoute(builder: (_) => const MemoryScreen())),
        ),
        _SettingsTile(
          icon: NumiIcons.notifications_outlined,
          label: AppLocale.t('notifications'),
          onTap: () => Navigator.of(
            context,
          ).push(MaterialPageRoute(builder: (_) => const NotificationScreen())),
        ),
        _SettingsTile(
          icon: Icons.mark_email_unread_outlined,
          label: AppLocale.t('email_preferences'),
          subtitle: AppLocale.t('email_preferences_subtitle'),
          onTap: () => Navigator.of(context).push(
            MaterialPageRoute(builder: (_) => const EmailPreferencesScreen()),
          ),
        ),
        _SettingsTile(
          icon: NumiIcons.privacy_tip_outlined,
          label: AppLocale.t('privacy'),
          onTap: () => Navigator.of(
            context,
          ).push(MaterialPageRoute(builder: (_) => const PrivacyScreen())),
        ),
        _SettingsTile(
          icon: NumiIcons.info_outline,
          label: AppLocale.t('terms_of_use'),
          subtitle: AppLocale.t('terms_subtitle'),
          onTap: () async {
            await launchUrl(
              Uri.parse('https://numination-swart.vercel.app/terminos'),
              mode: LaunchMode.externalApplication,
            );
          },
        ),
        _SettingsTile(
          icon: NumiIcons.privacy_tip_outlined,
          label: AppLocale.t('privacy_web_policy'),
          subtitle: AppLocale.t('privacy_web_subtitle'),
          onTap: () async {
            await launchUrl(
              Uri.parse('https://numination-swart.vercel.app/privacidad'),
              mode: LaunchMode.externalApplication,
            );
          },
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
            AppLocale.t('automatic_updates'),
            style: TextStyle(color: palette.textPrimary, fontSize: 16),
          ),
          subtitle: Text(
            AppLocale.t('automatic_updates_subtitle'),
            style: TextStyle(color: palette.textSecondary, fontSize: 12),
          ),
        ),
        _SettingsTile(
          icon: Icons.bolt_rounded,
          label: AppLocale.t('credits'),
          subtitle: AppLocale.t('credits_subtitle'),
          onTap: () => Navigator.of(
            context,
          ).push(MaterialPageRoute(builder: (_) => const CreditsHubScreen())),
        ),
        _SettingsTile(
          icon: Icons.workspace_premium_outlined,
          label: AppLocale.t('subscriptions'),
          subtitle: AppLocale.t('subscriptions_subtitle'),
          onTap: () => Navigator.of(
            context,
          ).push(MaterialPageRoute(builder: (_) => const PlansScreen())),
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
    );

    if (desktopSheet) {
      return Material(
        color: palette.background,
        elevation: 24,
        borderRadius: BorderRadius.circular(22),
        clipBehavior: Clip.antiAlias,
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(22, 15, 14, 13),
              child: Row(
                children: [
                  Container(
                    width: 34,
                    height: 4,
                    decoration: BoxDecoration(
                      color: palette.textSecondary.withValues(alpha: 0.35),
                      borderRadius: BorderRadius.circular(10),
                    ),
                  ),
                  const SizedBox(width: 13),
                  Expanded(
                    child: Text(
                      AppLocale.t('settings'),
                      style: TextStyle(
                        color: palette.textPrimary,
                        fontSize: 18,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                  ),
                  IconButton(
                    tooltip: 'Cerrar',
                    onPressed: () => Navigator.of(context).pop(),
                    icon: Icon(
                      Icons.close_rounded,
                      color: palette.textSecondary,
                    ),
                  ),
                ],
              ),
            ),
            Divider(height: 1, color: palette.border),
            Expanded(child: settingsList),
          ],
        ),
      );
    }

    return Scaffold(
      backgroundColor: palette.background,
      appBar: AppBar(
        automaticallyImplyLeading: !desktopSheet,
        backgroundColor: palette.background,
        elevation: 0,
        iconTheme: IconThemeData(color: palette.textPrimary),
        title: Text(
          AppLocale.t('settings'),
          style: TextStyle(color: palette.textPrimary),
        ),

        actions: [
          if (desktopSheet)
            IconButton(
              tooltip: 'Cerrar',
              onPressed: () => Navigator.of(context).pop(),
              icon: const Icon(Icons.close_rounded),
            ),
        ],
      ),
      body: settingsList,
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
