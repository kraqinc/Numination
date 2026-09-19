import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/auth_controller.dart';
import '../../core/theme.dart';
import 'custom_strings.dart';

class SettingsScreen extends ConsumerWidget {
  const SettingsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final auth = ref.watch(authControllerProvider);
    final email = auth is AuthAuthenticated ? auth.email : '';

    return Scaffold(
      backgroundColor: AppColors.screenBackground,
      appBar: AppBar(
        backgroundColor: AppColors.screenBackground,
        elevation: 0,
        iconTheme: const IconThemeData(color: Colors.black),
        title: const Text('Ajustes', style: TextStyle(color: Colors.black)),
      ),
      body: ListView(
        padding: const EdgeInsets.symmetric(vertical: 12),
        children: [
          _SettingsTile(
            icon: Icons.person_outline,
            label: 'Perfil',
            subtitle: email,
            onTap: () {
              Navigator.of(context).push(
                MaterialPageRoute(builder: (_) => const CustomStringsScreen()),
              );
            },
          ),
          const _SettingsSectionDivider(),
          _SettingsTile(
            icon: Icons.memory_outlined,
            label: 'Memorias',
            subtitle: 'Lo que Numination recuerda de tus chats',
            onTap: () {},
          ),
          _SettingsTile(
            icon: Icons.notifications_outlined,
            label: 'Notificaciones',
            onTap: () {},
          ),
          _SettingsTile(
            icon: Icons.privacy_tip_outlined,
            label: 'Privacidad',
            onTap: () {},
          ),
          const _SettingsSectionDivider(),
          _SettingsTile(
            icon: Icons.workspace_premium_outlined,
            label: 'Suscripción Coder',
            onTap: () {},
          ),
          const _SettingsSectionDivider(),
          _SettingsTile(
            icon: Icons.logout,
            label: 'Cerrar sesión',
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
  const _SettingsSectionDivider();

  @override
  Widget build(BuildContext context) {
    return const Padding(
      padding: EdgeInsets.symmetric(vertical: 8),
      child: Divider(color: Color(0xFFD8D8D8), height: 1),
    );
  }
}

class _SettingsTile extends StatelessWidget {
  const _SettingsTile({
    required this.icon,
    required this.label,
    this.subtitle,
    this.iconColor = Colors.black,
    this.labelColor = Colors.black,
    required this.onTap,
  });

  final IconData icon;
  final String label;
  final String? subtitle;
  final Color iconColor;
  final Color labelColor;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return ListTile(
      leading: Icon(icon, color: iconColor),
      title: Text(label, style: TextStyle(color: labelColor, fontSize: 16)),
      subtitle: subtitle != null && subtitle!.isNotEmpty
          ? Text(subtitle!, style: const TextStyle(color: Color(0xFF8A8A8A), fontSize: 13))
          : null,
      trailing: const Icon(Icons.chevron_right, color: Color(0xFF5C5C5C)),
      onTap: onTap,
    );
  }
}