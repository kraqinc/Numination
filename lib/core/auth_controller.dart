import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart' as supabase;

import 'api.dart';

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
  final bool ageConfirmed;
  final bool bannedUnderage;
  final bool needsPasswordAfterEmailConfirmation;

  const AuthAuthenticated({
    required this.userId,
    required this.email,
    this.ageConfirmed = false,
    this.bannedUnderage = false,
    this.needsPasswordAfterEmailConfirmation = false,
  });

  factory AuthAuthenticated.fromUser(supabase.User user) {
    final meta =
        user.userMetadata ?? const <String, dynamic>{};

    return AuthAuthenticated(
      userId: user.id,
      email: user.email ?? '',
      ageConfirmed: meta['age_14_plus'] == true,
      bannedUnderage: meta['banned_underage'] == true,
      needsPasswordAfterEmailConfirmation:
          meta['numination_email_pending'] == true &&
          user.emailConfirmedAt != null,
    );
  }
}

class AuthController extends Notifier<AuthState> {
  StreamSubscription<supabase.AuthState>? _sub;

  @override
  AuthState build() {
    final client = supabase.Supabase.instance.client;

    ref.onDispose(() {
      _sub?.cancel();
    });

    _sub = client.auth.onAuthStateChange.listen(
      (authState) {
        final session = authState.session;

        if (session == null) {
          ApiClient.setToken(null);
          state = const AuthUnauthenticated();
          return;
        }

        ApiClient.setToken(session.accessToken);

        state = AuthAuthenticated.fromUser(
          session.user,
        );
      },
      onError: (Object error, StackTrace stackTrace) {
        // Los errores del stream no deben tumbar la aplicación.
      },
    );

    final currentSession = client.auth.currentSession;

    if (currentSession != null) {
      ApiClient.setToken(
        currentSession.accessToken,
      );

      return AuthAuthenticated.fromUser(
        currentSession.user,
      );
    }

    return const AuthUnauthenticated();
  }

  Future<void> signOut() async {
    ApiClient.setToken(null);

    await supabase.Supabase.instance.client.auth.signOut();
  }
}

final authControllerProvider =
    NotifierProvider<AuthController, AuthState>(
  AuthController.new,
);
