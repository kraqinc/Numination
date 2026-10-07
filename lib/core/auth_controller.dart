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

class AuthPasswordRecovery extends AuthState {
  const AuthPasswordRecovery();
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
    final meta = user.userMetadata ?? const <String, dynamic>{};

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
  static bool _passwordRecoveryLinkPending = false;

  static void markPasswordRecoveryLink() {
    _passwordRecoveryLinkPending = true;
  }

  StreamSubscription<supabase.AuthState>? _sub;
  int _syncGeneration = 0;
  bool _passwordRecoveryActive = false;

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
          _syncGeneration++;
          _passwordRecoveryActive = false;
          ApiClient.setToken(null);
          state = const AuthUnauthenticated();
          return;
        }

        ApiClient.setToken(session.accessToken);

        if (_passwordRecoveryLinkPending) {
          _passwordRecoveryLinkPending = false;
          _passwordRecoveryActive = true;
          _syncGeneration++;
          state = const AuthPasswordRecovery();
          return;
        }

        if (authState.event ==
            supabase.AuthChangeEvent.passwordRecovery) {
          _passwordRecoveryActive = true;
          _syncGeneration++;
          state = const AuthPasswordRecovery();
          return;
        }

        // No sacar al usuario de la pantalla de recuperación
        // mientras esté estableciendo su nueva contraseña.
        if (_passwordRecoveryActive) {
          state = const AuthPasswordRecovery();
          return;
        }

        state = const AuthInitial();
        unawaited(_syncWithBackend(session.user));
      },
      onError: (Object _, StackTrace _) {
        final session = client.auth.currentSession;

        if (session != null) {
          ApiClient.setToken(session.accessToken);
          state = AuthAuthenticated.fromUser(session.user);
        }
      },
    );

    final session = client.auth.currentSession;

    if (session == null) {
      return const AuthUnauthenticated();
    }

    ApiClient.setToken(session.accessToken);

    if (_passwordRecoveryLinkPending) {
      _passwordRecoveryLinkPending = false;
      _passwordRecoveryActive = true;
      return const AuthPasswordRecovery();
    }

    if (_passwordRecoveryActive) {
      return const AuthPasswordRecovery();
    }

    unawaited(_syncWithBackend(session.user));
    return const AuthInitial();
  }

  Future<void> _syncWithBackend(supabase.User user) async {
    final client = supabase.Supabase.instance.client;
    final generation = ++_syncGeneration;

    bool isCurrentRequest() =>
        generation == _syncGeneration &&
        client.auth.currentUser?.id == user.id;

    void metadataFallback() {
      if (isCurrentRequest()) {
        state = AuthAuthenticated.fromUser(user);
      }
    }

    try {
      final response = await ApiClient.get('/auth/me').timeout(
        const Duration(seconds: 12),
      );

      final data = ApiClient.decode(response);

      if (data is! Map<String, dynamic>) {
        metadataFallback();
        return;
      }

      final serverUser = data['user'];

      if (serverUser is! Map<String, dynamic>) {
        metadataFallback();
        return;
      }

      if (!isCurrentRequest()) return;

      state = AuthAuthenticated(
        userId: user.id,
        email: user.email ?? '',
        ageConfirmed: serverUser['ageVerified'] == true,
        bannedUnderage: false,
        needsPasswordAfterEmailConfirmation:
            user.userMetadata?['numination_email_pending'] == true &&
            user.emailConfirmedAt != null,
      );
    } on ApiException catch (e) {
      if (!isCurrentRequest()) return;

      if (e.statusCode == 403) {
        state = AuthAuthenticated(
          userId: user.id,
          email: user.email ?? '',
          ageConfirmed: false,
          bannedUnderage: true,
          needsPasswordAfterEmailConfirmation:
              user.userMetadata?['numination_email_pending'] == true &&
              user.emailConfirmedAt != null,
        );
      } else {
        metadataFallback();
      }
    } catch (_) {
      metadataFallback();
    }
  }

  Future<void> refresh() async {
    final client = supabase.Supabase.instance.client;
    final session = client.auth.currentSession;

    if (session == null) {
      ApiClient.setToken(null);
      state = const AuthUnauthenticated();
      return;
    }

    ApiClient.setToken(session.accessToken);
    state = const AuthInitial();
    await _syncWithBackend(session.user);
  }

  Future<void> signOut() async {
    _passwordRecoveryActive = false;
    _passwordRecoveryLinkPending = false;
    ApiClient.setToken(null);
    await supabase.Supabase.instance.client.auth.signOut();
  }
}

final authControllerProvider =
    NotifierProvider<AuthController, AuthState>(
  AuthController.new,
);
