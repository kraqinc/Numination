import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'api.dart';

/// Auth state mirrored from Supabase's own session. The email/password
/// wizard (auth_screen.dart -> confirm_mail.dart) talks to Supabase
/// directly via signInWithPassword/signUp; this controller only listens
/// for the resulting session so the rest of the app (app.dart,
/// home_screen.dart) knows whether to show the wizard or the
/// authenticated shell.
sealed class AuthState {
  const AuthState();
}

class AuthInitial extends AuthState {
  const AuthInitial();
}

class AuthUnauthenticated extends AuthState {
  const AuthUnauthenticated();
}

class AuthAuthenticated extends AuthState {
  final String userId;
  final String email;
  const AuthAuthenticated({required this.userId, required this.email});
}

class AuthController extends Notifier<AuthState> {
  StreamSubscription<AuthState>? _sub;

  @override
  AuthState build() {
    final client = Supabase.instance.client;

    ref.onDispose(() {
      _sub?.cancel();
    });

    _sub = client.auth.onAuthStateChange.map((event) {
      final session = event.session;
      if (session == null) {
        ApiClient.setToken(null);
        return const AuthUnauthenticated();
      }
      ApiClient.setToken(session.accessToken);
      return AuthAuthenticated(
        userId: session.user.id,
        email: session.user.email ?? '',
      );
    }).listen((next) => state = next);

    final currentSession = client.auth.currentSession;
    if (currentSession != null) {
      ApiClient.setToken(currentSession.accessToken);
      return AuthAuthenticated(
        userId: currentSession.user.id,
        email: currentSession.user.email ?? '',
      );
    }
    return const AuthUnauthenticated();
  }

  Future<void> signOut() async {
    await Supabase.instance.client.auth.signOut();
  }
}

final authControllerProvider = NotifierProvider<AuthController, AuthState>(
  AuthController.new,
);