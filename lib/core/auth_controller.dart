import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'api.dart';

/// Auth state mirrored from Supabase's own session.
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

  const AuthAuthenticated({
    required this.userId,
    required this.email,
    this.ageConfirmed = false,
    this.bannedUnderage = false,
  });

  factory AuthAuthenticated.fromUser(User user) {
    final meta = user.userMetadata ?? const <String, dynamic>{};

    return AuthAuthenticated(
      userId: user.id,
      email: user.email ?? '',
      ageConfirmed: meta['age_14_plus'] == true,
      bannedUnderage: meta['banned_underage'] == true,
    );
  }
}

class AuthController extends Notifier<AuthState> {
  StreamSubscription<AuthState>? _sub;

  @override
  AuthState build() {
    final client = Supabase.instance.client;

    ref.onDispose(() {
      _sub?.cancel();
    });

    _sub = client.auth.onAuthStateChange
        .map((event) {
          final session = event.session;

          if (session == null) {
            ApiClient.setToken(null);
            return const AuthUnauthenticated();
          }

          ApiClient.setToken(session.accessToken);

          return AuthAuthenticated.fromUser(session.user);
        })
        .listen((next) => state = next);

    final currentSession = client.auth.currentSession;

    if (currentSession != null) {
      ApiClient.setToken(currentSession.accessToken);
      return AuthAuthenticated.fromUser(currentSession.user);
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
