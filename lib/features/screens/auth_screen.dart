import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../core/auth_controller.dart';
import '../../core/env.dart';
import '../../core/numi_icons.dart';
import 'confirm_mail.dart';
import 'create_acc.dart';

class AuthScreen extends ConsumerStatefulWidget {
  const AuthScreen({super.key});

  @override
  ConsumerState<AuthScreen> createState() => _AuthScreenState();
}

class _AuthScreenState extends ConsumerState<AuthScreen> {
  final _emailController = TextEditingController();

  bool _isLoading = false;
  String? _errorText;

  static const _bg = Color(0xFFF7F9F8);
  static const _navy = Color(0xFF16325C);
  static const _ink = Color(0xFF111111);
  static const _muted = Color(0xFF8A8A8A);
  static const _line = Color(0xFFD4D4D4);

  @override
  void dispose() {
    _emailController.dispose();
    super.dispose();
  }

  bool _isValidEmail(String email) {
    return RegExp(r'^[^@\s]+@[^@\s]+\.[^@\s]+$').hasMatch(email);
  }

  Future<void> _onContinue() async {
    final email = _emailController.text.trim();

    if (!_isValidEmail(email)) {
      setState(() {
        _errorText = 'Ingresa un correo válido';
      });
      return;
    }

    setState(() {
      _isLoading = true;
      _errorText = null;
    });

    try {
      if (!mounted) return;

      await Navigator.of(context).push(
        MaterialPageRoute(builder: (_) => ConfirmMailScreen(email: email)),
      );
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  Future<void> _onGoogleSignIn() async {
    if (_isLoading) return;

    setState(() {
      _isLoading = true;
      _errorText = null;
    });

    try {
      if (Env.googleClientId.trim().isEmpty) {
        throw StateError(
          'Falta SUPABASE_AUTH_GOOGLE_CLIENT_ID en .env. '
          'Debe ser el Client ID web de Google.',
        );
      }

      final googleSignIn = GoogleSignIn.instance;

      await googleSignIn.signOut();

      final googleUser = await googleSignIn.authenticate();

      final googleAuth = googleUser.authentication;

      final idToken = googleAuth.idToken;

      if (idToken == null || idToken.isEmpty) {
        throw StateError('Google no devolvió un ID token.');
      }

      const scopes = <String>['email', 'profile'];

      final authorization = await googleUser.authorizationClient
          .authorizeScopes(scopes);

      final accessToken = authorization.accessToken;

      if (accessToken.isEmpty) {
        throw StateError('Google no devolvió un access token.');
      }

      final response = await Supabase.instance.client.auth.signInWithIdToken(
        provider: OAuthProvider.google,
        idToken: idToken,
        accessToken: accessToken,
      );

      final user = response.user ?? Supabase.instance.client.auth.currentUser;

      if (user == null) {
        throw StateError('Google autenticó, pero no se creó la sesión.');
      }

      if (!mounted) return;

      await ref.read(authControllerProvider.notifier).refresh();

      if (!mounted) return;
    } on GoogleSignInException catch (e) {
      if (!mounted) return;

      if (e.code == GoogleSignInExceptionCode.canceled) {
        setState(() {
          _errorText = null;
        });
        return;
      }

      setState(() {
        _errorText = e.description ?? 'No se pudo iniciar sesión con Google';
      });
    } on AuthException catch (e) {
      if (!mounted) return;

      setState(() {
        _errorText = e.message;
      });
    } catch (e) {
      if (!mounted) return;

      setState(() {
        _errorText = e.toString().replaceFirst('Bad state: ', '');
      });
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  Future<void> _onGithubSignIn() async {
    if (_isLoading) return;

    setState(() {
      _isLoading = true;
      _errorText = null;
    });

    try {
      await Supabase.instance.client.auth.signInWithOAuth(
        OAuthProvider.github,
        redirectTo: Env.authRedirectUrl,
      );
    } on AuthException catch (e) {
      if (!mounted) return;

      setState(() {
        _errorText = e.message;
      });
    } catch (_) {
      if (!mounted) return;

      setState(() {
        _errorText = 'No se pudo iniciar sesión con GitHub';
      });
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _bg,
      body: SafeArea(
        child: LayoutBuilder(
          builder: (context, constraints) {
            return SingleChildScrollView(
              padding: const EdgeInsets.symmetric(horizontal: 32),
              child: ConstrainedBox(
                constraints: BoxConstraints(minHeight: constraints.maxHeight),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const Text(
                      'Welcome to\nNumination.',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        fontSize: 32,
                        fontWeight: FontWeight.w800,
                        height: 1.12,
                        letterSpacing: -0.6,
                        color: _ink,
                      ),
                    ),

                    const SizedBox(height: 44),

                    TextField(
                      controller: _emailController,
                      keyboardType: TextInputType.emailAddress,
                      autocorrect: false,
                      enabled: !_isLoading,
                      textInputAction: TextInputAction.next,
                      onSubmitted: (_) => _onContinue(),
                      style: const TextStyle(fontSize: 15, color: _ink),
                      decoration: InputDecoration(
                        hintText: 'Correo electrónico',
                        hintStyle: const TextStyle(
                          color: _muted,
                          fontSize: 15,
                          fontWeight: FontWeight.w400,
                        ),
                        prefixIcon: const Padding(
                          padding: EdgeInsets.only(left: 16, right: 8),
                          child: Icon(
                            Icons.mail_outline_rounded,
                            size: 20,
                            color: _muted,
                          ),
                        ),
                        prefixIconConstraints: const BoxConstraints(
                          minWidth: 44,
                          minHeight: 20,
                        ),
                        filled: true,
                        fillColor: Colors.white,
                        contentPadding: const EdgeInsets.symmetric(
                          horizontal: 18,
                          vertical: 16,
                        ),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(28),
                          borderSide: const BorderSide(color: _line),
                        ),
                        enabledBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(28),
                          borderSide: const BorderSide(color: _line),
                        ),
                        focusedBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(28),
                          borderSide: const BorderSide(
                            color: Color(0xFF9AA7BC),
                          ),
                        ),
                        disabledBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(28),
                          borderSide: const BorderSide(color: _line),
                        ),
                      ),
                    ),

                    if (_errorText != null) ...[
                      const SizedBox(height: 8),
                      Align(
                        alignment: Alignment.centerLeft,
                        child: Text(
                          _errorText!,
                          style: const TextStyle(
                            color: Color(0xFFC23B3B),
                            fontSize: 13,
                          ),
                        ),
                      ),
                    ],

                    const SizedBox(height: 16),

                    SizedBox(
                      width: double.infinity,
                      height: 50,
                      child: ElevatedButton(
                        onPressed: _isLoading ? null : _onContinue,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: _navy,
                          foregroundColor: Colors.white,
                          disabledBackgroundColor: _navy.withValues(alpha: 0.7),
                          disabledForegroundColor: Colors.white,
                          elevation: 0,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(28),
                          ),
                        ),
                        child: _isLoading
                            ? const SizedBox(
                                width: 20,
                                height: 20,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2.4,
                                  color: Colors.white,
                                ),
                              )
                            : const Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Text(
                                    'Continuar',
                                    style: TextStyle(
                                      fontSize: 15,
                                      fontWeight: FontWeight.w600,
                                      letterSpacing: 0.1,
                                    ),
                                  ),
                                  SizedBox(width: 8),
                                  Icon(NumiIcons.arrow_right, size: 18),
                                ],
                              ),
                      ),
                    ),

                    const SizedBox(height: 40),

                    Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        _OAuthIconButton(
                          tooltip: 'Google',
                          isLoading: _isLoading,
                          onTap: _onGoogleSignIn,
                          icon: Image.asset(
                            'assets/images/google.png',
                            width: 22,
                            height: 22,
                          ),
                        ),
                        const SizedBox(width: 12),
                        _OAuthIconButton(
                          tooltip: 'GitHub',
                          isLoading: _isLoading,
                          onTap: _onGithubSignIn,
                          icon: Image.asset(
                            'assets/images/github.png',
                            width: 22,
                            height: 22,
                          ),
                        ),
                      ],
                    ),

                    const SizedBox(height: 28),

                    GestureDetector(
                      onTap: _isLoading
                          ? null
                          : () {
                              Navigator.of(context).push(
                                MaterialPageRoute(
                                  builder: (_) => const CreateAccountScreen(),
                                ),
                              );
                            },
                      child: const Text.rich(
                        TextSpan(
                          style: TextStyle(fontSize: 14, color: _muted),
                          children: [
                            TextSpan(text: "Don't have an account? "),
                            TextSpan(
                              text: 'Sign up',
                              style: TextStyle(
                                color: _ink,
                                fontWeight: FontWeight.w700,
                                decoration: TextDecoration.underline,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),

                    const SizedBox(height: 12),
                  ],
                ),
              ),
            );
          },
        ),
      ),
    );
  }
}

class _OAuthIconButton extends StatelessWidget {
  const _OAuthIconButton({
    required this.icon,
    required this.onTap,
    required this.isLoading,
    required this.tooltip,
  });

  final Widget icon;
  final VoidCallback onTap;
  final bool isLoading;
  final String tooltip;

  @override
  Widget build(BuildContext context) {
    return Tooltip(
      message: tooltip,
      child: SizedBox(
        width: 52,
        height: 52,
        child: Material(
          color: Colors.white,
          elevation: 0,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(14),
            side: const BorderSide(color: Color(0xFFE2E2E2)),
          ),
          child: InkWell(
            onTap: isLoading ? null : onTap,
            borderRadius: BorderRadius.circular(14),
            child: Center(child: icon),
          ),
        ),
      ),
    );
  }
}
