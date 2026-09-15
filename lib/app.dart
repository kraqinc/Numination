import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'core/auth_controller.dart';
import 'core/connectivity_banner.dart';
import 'core/theme.dart';
import 'features/screens/auth_screen.dart';
import 'features/screens/home_screen.dart';

class NuminationApp extends ConsumerWidget {
  const NuminationApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final AuthState auth = ref.watch(authControllerProvider);

    return MaterialApp(
      title: 'Numination',
      debugShowCheckedModeBanner: false,
      theme: buildTheme(),
      builder: (context, child) {
        return ConnectivityBanner(child: child ?? const SizedBox.shrink());
      },
      home: switch (auth) {
        AuthAuthenticated() => const HomeScreen(),
        AuthUnauthenticated() => const AuthScreen(),
        AuthInitial() => const _SplashScreen(),
      },
    );
  }
}

class _SplashScreen extends StatelessWidget {
  const _SplashScreen();

  @override
  Widget build(BuildContext context) {
    return const Scaffold(
      backgroundColor: Color(0xFFECECEC),
      body: Center(
        child: CircularProgressIndicator(color: Colors.black54),
      ),
    );
  }
}