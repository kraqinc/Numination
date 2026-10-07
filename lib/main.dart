import 'package:app_links/app_links.dart';
import 'package:flutter/material.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'app.dart';
import 'core/auth_controller.dart';
import 'core/env.dart';
import 'core/theme.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  await dotenv.load(fileName: '.env');

  if (Env.supabaseUrl.isEmpty ||
      Env.supabasePublishableKey.isEmpty) {
    runApp(const ProviderScope(child: _MissingEnvApp()));
    return;
  }

  // Observa el enlace antes de iniciar Supabase para no perder
  // el marcador de recuperación durante un arranque en frío.
  AppLinks().uriLinkStream.listen(
    (uri) {
      if (uri.scheme == 'numination' &&
          uri.host == 'auth' &&
          uri.queryParameters['flow'] == 'recovery') {
        AuthController.markPasswordRecoveryLink();
      }
    },
    onError: (Object error, StackTrace stackTrace) {
      debugPrint('[AUTH LINK] $error');
    },
  );

  await Supabase.initialize(
    url: Env.supabaseUrl,
    publishableKey: Env.supabasePublishableKey,
    authOptions: const FlutterAuthClientOptions(
      authFlowType: AuthFlowType.pkce,
      detectSessionInUri: true,
    ),
  );

  if (Env.googleClientId.trim().isNotEmpty) {
    await GoogleSignIn.instance.initialize(
      serverClientId: Env.googleClientId,
    );
  }

  runApp(const ProviderScope(child: NuminationApp()));
}

class _MissingEnvApp extends StatelessWidget {
  const _MissingEnvApp();

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      theme: buildTheme(AppPalette.of(AppThemeMode.gray)),
      home: const Scaffold(
        body: Center(
          child: Padding(
            padding: EdgeInsets.all(24),
            child: Text(
              'Numination: configura SUPABASE_URL y SUPABASE_PUBLISHABLE_KEY en .env.',
              textAlign: TextAlign.center,
            ),
          ),
        ),
      ),
    );
  }
}
