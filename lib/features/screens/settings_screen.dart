import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/auth_controller.dart';
import '../../core/env.dart';

class SettingsScreen
    extends ConsumerStatefulWidget {
  const SettingsScreen({
    super.key,
  });

  @override
  ConsumerState<SettingsScreen> createState() =>
      _SettingsScreenState();
}

class _SettingsScreenState
    extends ConsumerState<SettingsScreen> {
  bool notifications = true;
  bool autoUpdate = true;

  @override
  Widget build(
    BuildContext context,
  ) {
    final auth =
        ref.watch(
      authControllerProvider,
    );

    final email =
        auth is AuthAuthenticated
            ? auth.email
            : '';

    return Scaffold(
      backgroundColor:
          const Color(0xFFECECEC),
      appBar: AppBar(
        backgroundColor:
            const Color(0xFFECECEC),
        elevation: 0,
        foregroundColor:
            Colors.black,
        title: const Text(
          'Configuración',
          style: TextStyle(
            color: Colors.black,
            fontWeight:
                FontWeight.w700,
          ),
        ),
      ),
      body: ListView(
        padding:
            const EdgeInsets.all(
          16,
        ),
        children: [
          _SettingsCard(
            child: Column(
              crossAxisAlignment:
                  CrossAxisAlignment.start,
              children: [
                const Text(
                  'Cuenta',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight:
                        FontWeight.w800,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  email.isEmpty
                      ? 'Sesión actual'
                      : email,
                  style:
                      const TextStyle(
                    color:
                        Colors.black54,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 12),
          _SettingsCard(
            child: Column(
              children: [
                SwitchListTile.adaptive(
                  contentPadding:
                      EdgeInsets.zero,
                  value:
                      notifications,
                  title: const Text(
                    'Notificaciones',
                  ),
                  onChanged: (value) {
                    setState(() {
                      notifications =
                          value;
                    });
                  },
                ),
                SwitchListTile.adaptive(
                  contentPadding:
                      EdgeInsets.zero,
                  value:
                      autoUpdate,
                  title: const Text(
                    'Actualización automática',
                  ),
                  onChanged: (value) {
                    setState(() {
                      autoUpdate =
                          value;
                    });
                  },
                ),
              ],
            ),
          ),
          const SizedBox(height: 12),
          _SettingsCard(
            child: Column(
              crossAxisAlignment:
                  CrossAxisAlignment.start,
              children: [
                const Text(
                  'Entorno',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight:
                        FontWeight.w800,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  'App: ${Env.appVersion}',
                  style:
                      const TextStyle(
                    color:
                        Colors.black54,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  'API: ${Env.apiBaseUrl}',
                  style:
                      const TextStyle(
                    color:
                        Colors.black54,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  'Redirect: ${Env.authRedirectUrl}',
                  style:
                      const TextStyle(
                    color:
                        Colors.black54,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),
          SizedBox(
            height: 54,
            child: FilledButton.icon(
              style:
                  FilledButton.styleFrom(
                backgroundColor:
                    Colors.black,
                foregroundColor:
                    Colors.white,
                shape:
                    RoundedRectangleBorder(
                  borderRadius:
                      BorderRadius.circular(
                    16,
                  ),
                ),
              ),
              onPressed: () async {
                await ref
                    .read(
                      authControllerProvider
                          .notifier,
                    )
                    .signOut();

                if (!context.mounted) {
                  return;
                }

                Navigator.of(
                  context,
                ).pop();
              },
              icon: const Icon(
                Icons.logout,
              ),
              label: const Text(
                'Cerrar sesión',
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _SettingsCard
    extends StatelessWidget {
  const _SettingsCard({
    required this.child,
  });

  final Widget child;

  @override
  Widget build(
    BuildContext context,
  ) {
    return Container(
      padding:
          const EdgeInsets.all(
        16,
      ),
      decoration:
          BoxDecoration(
        color: Colors.white,
        borderRadius:
            BorderRadius.circular(
          18,
        ),
      ),
      child: child,
    );
  }
}