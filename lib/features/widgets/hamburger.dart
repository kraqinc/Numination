import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/auth_controller.dart';
import '../../core/models.dart' show ChatMode;

class AppDrawer extends ConsumerWidget {
  const AppDrawer({
    super.key,
    required this.email,
    required this.mode,
    required this.onSelectMode,
  });

  final String email;
  final ChatMode mode;
  final ValueChanged<ChatMode> onSelectMode;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final username = email.isNotEmpty ? email.split('@').first : 'Usuario';

    return Drawer(
      backgroundColor: Colors.black,
      child: SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  IconButton(
                    onPressed: () {},
                    icon: const Icon(Icons.settings_outlined, color: Colors.white),
                  ),
                  const SizedBox(width: 4),
                  Expanded(
                    child: Text(
                      username,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 20,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                  IconButton(
                    onPressed: () {},
                    icon: const Icon(Icons.search, color: Colors.white),
                  ),
                  IconButton(
                    onPressed: () async {
                      await ref.read(authControllerProvider.notifier).signOut();
                    },
                    icon: const Icon(Icons.logout, color: Colors.white),
                  ),
                ],
              ),
              const SizedBox(height: 24),
              _DrawerItem(icon: Icons.folder_copy_outlined, label: 'Proyectos', onTap: () {}),
              const SizedBox(height: 18),
              _DrawerItem(icon: Icons.description_outlined, label: 'Artefactos', onTap: () {}),
              const SizedBox(height: 18),
              _DrawerItem(icon: Icons.power_off_outlined, label: 'Conectores', onTap: () {}),
              const SizedBox(height: 16),
              const Divider(color: Color(0xFF232323)),
              const SizedBox(height: 8),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text('Sesiones', style: TextStyle(color: Colors.white, fontSize: 18)),
                  ModePillDropdown(mode: mode, onSelectMode: onSelectMode),
                ],
              ),
              const SizedBox(height: 40),
              const Expanded(
                child: Center(
                  child: Text(
                    'Sin resultados',
                    style: TextStyle(color: Color(0xFF5C5C5C), fontSize: 15),
                  ),
                ),
              ),
              Align(
                alignment: Alignment.centerRight,
                child: FloatingActionButton(
                  onPressed: () => Navigator.of(context).pop(),
                  backgroundColor: const Color(0xFF6ED7FF),
                  child: const Icon(Icons.add, color: Colors.black),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _DrawerItem extends StatelessWidget {
  const _DrawerItem({required this.icon, required this.label, required this.onTap});
  final IconData icon;
  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      child: Row(
        children: [
          Icon(icon, color: Colors.white, size: 22),
          const SizedBox(width: 16),
          Text(label, style: const TextStyle(color: Colors.white, fontSize: 17)),
        ],
      ),
    );
  }
}

/// Dropdown pill used both in the drawer ("Sesiones" header) and mirrored
/// visually by the Chat/Coder chips in the bottom input bar. Both call the
/// same [onSelectMode] callback owned by HomeScreen, so picking either one
/// keeps the whole screen in sync.
class ModePillDropdown extends StatelessWidget {
  const ModePillDropdown({super.key, required this.mode, required this.onSelectMode});
  final ChatMode mode;
  final ValueChanged<ChatMode> onSelectMode;

  @override
  Widget build(BuildContext context) {
    return PopupMenuButton<ChatMode>(
      color: const Color(0xFF1B1B1B),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
      onSelected: onSelectMode,
      itemBuilder: (context) => const [
        PopupMenuItem(value: ChatMode.chat, child: Text('Chat', style: TextStyle(color: Colors.white))),
        PopupMenuItem(value: ChatMode.coder, child: Text('Coder', style: TextStyle(color: Colors.white))),
      ],
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: const Color(0xFF313131)),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              mode == ChatMode.coder ? 'Coder' : 'Chat',
              style: const TextStyle(color: Colors.white, fontSize: 15),
            ),
            const SizedBox(width: 6),
            const Icon(Icons.keyboard_arrow_down, color: Colors.white, size: 18),
          ],
        ),
      ),
    );
  }
}