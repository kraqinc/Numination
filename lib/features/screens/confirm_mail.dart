import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../core/auth_controller.dart';
import '../../core/env.dart';
import 'auth_screen.dart';

import 'confirm_age_screen.dart';
import 'home_screen.dart';

class ConfirmMailScreen extends ConsumerStatefulWidget {
  const ConfirmMailScreen({
    super.key,
    required this.email,
  });

  final String email;

  @override
  ConsumerState<ConfirmMailScreen> createState() =>
      _ConfirmMailScreenState();
}

class _ConfirmMailScreenState
    extends ConsumerState<ConfirmMailScreen> {
  final _passwordController = TextEditingController();

  bool _obscurePassword = true;
  bool _isLoading = false;
  bool _isSendingReset = false;

  String? _errorText;
  String? _successText;

  static const _bg = Color(0xFFF7F9F8);
  static const _navy = Color(0xFF16325C);
  static const _ink = Color(0xFF111111);
  static const _muted = Color(0xFF8A8A8A);
  static const _line = Color(0xFFD4D4D4);

  @override
  void dispose() {
    _passwordController.dispose();
    super.dispose();
  }

  Future<void> _onLogin() async {
    final password = _passwordController.text;

    if (password.isEmpty) {
      setState(() {
        _errorText = 'Ingresa tu contraseña';
      });
      return;
    }

    setState(() {
      _isLoading = true;
      _errorText = null;
      _successText = null;
    });

    final client = Supabase.instance.client;

    try {
      await client.auth.signInWithPassword(
        email: widget.email,
        password: password,
      );

      final user = client.auth.currentUser;

      if (user == null) {
        throw const AuthException(
          'No se pudo crear la sesión.',
        );
      }

      await ref.read(authControllerProvider.notifier).refresh();
      if (!mounted) return;

      final authState = ref.read(authControllerProvider);
      final ageConfirmed = authState is AuthAuthenticated &&
          authState.ageConfirmed &&
          !authState.bannedUnderage;

      Navigator.of(context, rootNavigator: true).pushAndRemoveUntil(
        MaterialPageRoute<void>(
          builder: (_) => ageConfirmed
              ? const HomeScreen()
              : const ConfirmAgeScreen(),
        ),
        (route) => false,
      );
    } on AuthException catch (e) {
      final msg = e.message.toLowerCase();

      final isWrongPassword =
          msg.contains('invalid login credentials') ||
          msg.contains('invalid_credentials') ||
          msg.contains('invalid email or password');

      final isEmailNotConfirmed =
          msg.contains('email not confirmed') ||
          msg.contains('email_not_confirmed');

      if (!mounted) return;

      setState(() {
        if (isWrongPassword) {
          _errorText =
              '¡Ups! La contraseña no es correcta';
        } else if (isEmailNotConfirmed) {
          _errorText =
              'Primero confirma tu correo electrónico.';
        } else {
          _errorText = e.message;
        }
      });
    } catch (_) {
      if (!mounted) return;

      setState(() {
        _errorText =
            'Ocurrió un error inesperado';
      });
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  Future<void> _onForgotPassword() async {
    if (_isLoading || _isSendingReset) return;

    setState(() {
      _isSendingReset = true;
      _errorText = null;
      _successText = null;
    });

    try {
      await Supabase.instance.client.auth.resetPasswordForEmail(
        widget.email,
        redirectTo: '${Env.authRedirectUrl}?flow=recovery',
      );
      if (!mounted) return;
      setState(() {
        _successText = 'Te enviamos un enlace para restablecer la contraseña. Revisa tu correo.';
      });
    } on AuthException catch (e) {
      if (!mounted) return;
      setState(() => _errorText = e.message);
    } catch (_) {
      if (!mounted) return;
      setState(() => _errorText = 'No se pudo enviar el enlace de recuperación.');
    } finally {
      if (mounted) setState(() => _isSendingReset = false);
    }
  }

  Future<void> _changeAccount() async {
    try {
      await ref.read(authControllerProvider.notifier).signOut();
    } catch (_) {}
    if (!mounted) return;
    Navigator.of(context, rootNavigator: true).pushAndRemoveUntil(
      MaterialPageRoute<void>(builder: (_) => const AuthScreen()),
      (route) => false,
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _bg,
      body: SafeArea(
        child: LayoutBuilder(
          builder: (context, constraints) {
            return SingleChildScrollView(
              padding:
                  const EdgeInsets.symmetric(horizontal: 32),
              child: ConstrainedBox(
                constraints: BoxConstraints(
                  minHeight: constraints.maxHeight,
                ),
                child: Column(
                  mainAxisAlignment:
                      MainAxisAlignment.center,
                  children: [
                    const Text(
                      'Enter your password\nto continue',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        fontSize: 28,
                        fontWeight: FontWeight.w800,
                        height: 1.15,
                        letterSpacing: -0.5,
                        color: _ink,
                      ),
                    ),

                    const SizedBox(height: 10),

                    Text(
                      widget.email,
                      textAlign: TextAlign.center,
                      style: const TextStyle(
                        fontSize: 13,
                        color: _muted,
                      ),
                    ),

                    const SizedBox(height: 24),

                    TextField(
                      controller:
                          _passwordController,
                      obscureText:
                          _obscurePassword,
                      enabled: !_isLoading,
                      textInputAction:
                          TextInputAction.done,
                      onSubmitted: (_) =>
                          _onLogin(),
                      style: const TextStyle(
                        fontSize: 15,
                        color: _ink,
                      ),
                      decoration:
                          InputDecoration(
                        prefixIcon:
                            GestureDetector(
                          onTap: _isLoading
                              ? null
                              : () {
                                  setState(() {
                                    _obscurePassword =
                                        !_obscurePassword;
                                  });
                                },
                          child: const Padding(
                            padding:
                                EdgeInsets.only(
                              left: 16,
                              right: 8,
                            ),
                            child: Icon(
                              Icons
                                  .lock_outline_rounded,
                              size: 20,
                              color: _muted,
                            ),
                          ),
                        ),
                        prefixIconConstraints:
                            const BoxConstraints(
                          minWidth: 44,
                          minHeight: 20,
                        ),
                        filled: true,
                        fillColor: Colors.white,
                        contentPadding:
                            const EdgeInsets.symmetric(
                          horizontal: 18,
                          vertical: 16,
                        ),
                        border:
                            OutlineInputBorder(
                          borderRadius:
                              BorderRadius.circular(
                            28,
                          ),
                          borderSide:
                              const BorderSide(
                            color: _line,
                          ),
                        ),
                        enabledBorder:
                            OutlineInputBorder(
                          borderRadius:
                              BorderRadius.circular(
                            28,
                          ),
                          borderSide:
                              const BorderSide(
                            color: _line,
                          ),
                        ),
                        focusedBorder:
                            OutlineInputBorder(
                          borderRadius:
                              BorderRadius.circular(
                            28,
                          ),
                          borderSide:
                              const BorderSide(
                            color: Color(
                              0xFF9AA7BC,
                            ),
                          ),
                        ),
                        disabledBorder:
                            OutlineInputBorder(
                          borderRadius:
                              BorderRadius.circular(
                            28,
                          ),
                          borderSide:
                              const BorderSide(
                            color: _line,
                          ),
                        ),
                      ),
                    ),

                    if (_errorText != null) ...[
                      const SizedBox(height: 8),
                      Align(
                        alignment:
                            Alignment.centerLeft,
                        child: Text(
                          _errorText!,
                          style:
                              const TextStyle(
                            color:
                                Color(0xFFC23B3B),
                            fontSize: 13,
                          ),
                        ),
                      ),
                    ],

                    const SizedBox(height: 14),

                    SizedBox(
                      width: double.infinity,
                      height: 50,
                      child: ElevatedButton(
                        onPressed: _isLoading || _isSendingReset
                            ? null
                            : _onLogin,
                        style:
                            ElevatedButton.styleFrom(
                          backgroundColor: _navy,
                          foregroundColor:
                              Colors.white,
                          disabledBackgroundColor:
                              _navy.withValues(
                            alpha: 0.7,
                          ),
                          disabledForegroundColor:
                              Colors.white,
                          elevation: 0,
                          shape:
                              RoundedRectangleBorder(
                            borderRadius:
                                BorderRadius.circular(
                              28,
                            ),
                          ),
                        ),
                        child: _isLoading
                            ? const SizedBox(
                                width: 20,
                                height: 20,
                                child:
                                    CircularProgressIndicator(
                                  strokeWidth: 2.4,
                                  color:
                                      Colors.white,
                                ),
                              )
                            : const Text(
                                'Verify  →',
                                style: TextStyle(
                                  fontSize: 15,
                                  fontWeight:
                                      FontWeight.w600,
                                  letterSpacing:
                                      0.1,
                                ),
                              ),
                      ),
                    ),
                    if (_successText != null) ...[
                      const SizedBox(height: 10),
                      Text(
                        _successText!,
                        textAlign: TextAlign.center,
                        style: const TextStyle(
                          color: _navy,
                          fontSize: 13,
                          height: 1.4,
                        ),
                      ),
                    ],
                    const SizedBox(height: 8),
                    TextButton(
                      onPressed: _isLoading || _isSendingReset
                          ? null
                          : _onForgotPassword,
                      child: Text(
                        _isSendingReset
                            ? 'Enviando enlace...'
                            : '¿Olvidaste tu contraseña?',
                        style: const TextStyle(
                          color: _navy,
                          fontSize: 14,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                    GestureDetector(
                      onTap: _isLoading || _isSendingReset ? null : _changeAccount,
                      child: const Padding(
                        padding: EdgeInsets.symmetric(vertical: 8),
                        child: Text(
                          'Cambiar correo o cuenta',
                          style: TextStyle(
                            fontSize: 14,
                            color: _muted,
                            decoration: TextDecoration.underline,
                          ),
                        ),
                      ),
                    ),
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
