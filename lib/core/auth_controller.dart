import 'dart:async';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:url_launcher/url_launcher.dart';
import 'api.dart';
import 'env.dart';
import 'models.dart';

sealed class AuthUiState { const AuthUiState(); }
class AuthBooting extends AuthUiState { const AuthBooting(); }
class AuthUnauthenticated extends AuthUiState { const AuthUnauthenticated(); }
class AuthLoading extends AuthUiState { const AuthLoading(); }
class AuthAuthenticated extends AuthUiState { final AppUser user; const AuthAuthenticated(this.user); }
class AuthError extends AuthUiState { final String message; const AuthError(this.message); }

final authControllerProvider = NotifierProvider<AuthController, AuthUiState>(AuthController.new);

class AuthController extends Notifier<AuthUiState> {
  final _client = Supabase.instance.client;
  StreamSubscription<AuthState>? _sub;
  bool _disposed = false;

  @override
  AuthUiState build() {
    ref.onDispose(() { _disposed = true; _sub?.cancel(); });
    _sub = _client.auth.onAuthStateChange.listen((data) async {
      if (_disposed) return;
      if (data.session == null) {
        ApiClient.setToken(null);
        state = const AuthUnauthenticated();
      } else {
        await syncSession();
      }
    });
    Future.microtask(syncSession);
    return const AuthBooting();
  }

  Future<void> syncSession() async {
    final session = _client.auth.currentSession;
    if (session == null) {
      state = const AuthUnauthenticated();
      return;
    }
    final token = session.accessToken;
    ApiClient.setToken(token);
    try {
      final data = ApiClient.decode(await ApiClient.get('/auth/me')) as Map;
      final rawUser = data['user'];
      if (rawUser is! Map) {
        state = const AuthError('El backend no devolvió un usuario válido.');
        return;
      }
      state = AuthAuthenticated(AppUser.fromJson(Map<String, dynamic>.from(rawUser)));
    } catch (e) {
      state = AuthError(_friendly(e));
    }
  }

  Future<void> googleLogin() async => _oauth(OAuthProvider.google);
  Future<void> githubLogin() async => _oauth(OAuthProvider.github);

  Future<void> _oauth(OAuthProvider provider) async {
    state = const AuthLoading();
    try {
      await _client.auth.signInWithOAuth(provider, redirectTo: Env.authRedirectUrl, authScreenLaunchMode: LaunchMode.externalApplication);
    } catch (e) {
      state = AuthError(_friendly(e));
    }
  }

  Future<void> requestEmailCode(String email) async {
    state = const AuthLoading();
    try {
      await _client.auth.signInWithOtp(email: email.trim().toLowerCase(), emailRedirectTo: Env.authRedirectUrl, shouldCreateUser: true);
      state = const AuthUnauthenticated();
    } catch (e) {
      state = AuthError(_friendly(e));
    }
  }

  Future<void> verifyEmailCode(String email, String token) async {
    state = const AuthLoading();
    try {
      await _client.auth.verifyOTP(email: email.trim().toLowerCase(), token: token.trim(), type: OtpType.email);
      await syncSession();
    } catch (e) {
      state = AuthError(_friendly(e));
    }
  }

  Future<void> signOut() async {
    try { await _client.auth.signOut(); } finally {
      ApiClient.setToken(null);
      state = const AuthUnauthenticated();
    }
  }

  String _friendly(Object e) {
    if (e is AuthException) return e.message;
    if (e is PostgrestException) return e.message;
    return 'No pudimos conectar con Supabase. Revisa tu conexión.\n$e';
  }
}
