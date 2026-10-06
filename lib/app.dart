import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'core/auth_controller.dart';
import 'core/connectivity_banner.dart';
import 'features/screens/confirm_age_screen.dart';
import 'core/i18n.dart';
import 'core/theme_controller.dart';
import 'core/theme.dart';
import 'features/screens/auth_screen.dart';
import 'features/screens/home_screen.dart';
import 'features/screens/reset_password_screen.dart';
import 'l10n/gen/app_localizations.dart';

class NuminationApp extends ConsumerWidget {
  const NuminationApp({super.key});

  static final GlobalKey<NavigatorState> _navigatorKey =
      GlobalKey<NavigatorState>();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final AuthState auth = ref.watch(authControllerProvider);
    final palette = ref.watch(appPaletteProvider);

    ref.listen<AuthState>(authControllerProvider, (previous, next) {
      if (next is AuthPasswordRecovery && previous is! AuthPasswordRecovery) {
        WidgetsBinding.instance.addPostFrameCallback((_) {
          final navigator = _navigatorKey.currentState;
          if (navigator == null) return;
          navigator.pushAndRemoveUntil(
            MaterialPageRoute<void>(
              builder: (_) => const ResetPasswordScreen(),
            ),
            (route) => false,
          );
        });
      }
    });

    return MaterialApp(
      navigatorKey: _navigatorKey,
      title: 'Numination',
      debugShowCheckedModeBanner: false,
      theme: buildTheme(palette),
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
        AppLocale.bind(context);
        return ConnectivityBanner(child: child ?? const SizedBox.shrink());
      },
      home: switch (auth) {
        AuthPasswordRecovery() => const ResetPasswordScreen(),
        AuthAuthenticated(:final bannedUnderage, :final ageConfirmed) =>
          bannedUnderage || !ageConfirmed
              ? const ConfirmAgeScreen()
              : const HomeScreen(),
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
      body: Center(child: CircularProgressIndicator(color: Colors.black54)),
    );
  }
}
