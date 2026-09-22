import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'core/auth_controller.dart';
import 'core/connectivity_banner.dart';
import 'core/theme.dart';
import 'features/screens/auth_screen.dart';
import 'features/screens/home_screen.dart';
import 'l10n/gen/app_localizations.dart';

class NuminationApp extends ConsumerWidget {
  const NuminationApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final AuthState auth = ref.watch(authControllerProvider);

    return MaterialApp(
      title: 'Numination',
      debugShowCheckedModeBanner: false,
      theme: buildTheme(),
      localizationsDelegates: const [
        AppLocalizations.delegate,
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],
      supportedLocales: AppLocalizations.supportedLocales,
      // Reproduce el comportamiento del i18n casero anterior: usa el
      // idioma del dispositivo si está soportado, si no cae a español.
      // No depende del orden en que gen-l10n genere supportedLocales.
      localeListResolutionCallback: (deviceLocales, supportedLocales) {
        for (final device in deviceLocales ?? const <Locale>[]) {
          for (final supported in supportedLocales) {
            if (supported.languageCode == device.languageCode) return supported;
          }
        }
        return const Locale('es');
      },
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