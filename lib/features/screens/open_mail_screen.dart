import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart' hide AuthState;
import 'package:supabase_flutter/supabase_flutter.dart' as supabase;
import 'package:url_launcher/url_launcher.dart';

import '../../core/auth_controller.dart';
import 'auth_screen.dart';
import 'confirm_age_screen.dart';
import 'home_screen.dart';

class OpenMailScreen extends ConsumerStatefulWidget {
  const OpenMailScreen({
    super.key,
    required this.email,
  });

  final String email;

  @override
  ConsumerState<OpenMailScreen> createState() => _OpenMailScreenState();
}

class _OpenMailScreenState extends ConsumerState<OpenMailScreen> {
  static const _gmailChannel = MethodChannel('numination/gmail');

  static const _bg = Color(0xFFF7F9F8);
  static const _navy = Color(0xFF16325C);
  static const _ink = Color(0xFF111111);
  static const _muted = Color(0xFF8A8A8A);
  static const _line = Color(0xFFD4D4D4);
  static const _error = Color(0xFFC23B3B);

  bool _isOpeningGmail = false;
  bool _isChecking = false;
  bool _isResending = false;

  String? _errorText;
  String? _successText;

  Timer? _timer;
  StreamSubscription<supabase.AuthState>? _authSubscription;
  bool _isNavigating = false;

  @override
  void initState() {
    super.initState();

    _authSubscription =
        Supabase.instance.client.auth.onAuthStateChange.listen(
      (data) {
        if (data.event == AuthChangeEvent.passwordRecovery) return;

        final user = data.session?.user ??
            Supabase.instance.client.auth.currentUser;

        if (user?.emailConfirmedAt != null) {
          _openPostConfirmation();
        }
      },
      onError: (_, _) {},
    );

    _timer = Timer.periodic(
      const Duration(seconds: 3),
      (_) => _checkConfirmation(silent: true),
    );

    _checkConfirmation(silent: true);
  }

  Future<void> _openPostConfirmation() async {
    if (!mounted || _isNavigating) return;

    final user = Supabase.instance.client.auth.currentUser;
    if (user?.emailConfirmedAt == null) return;

    _isNavigating = true;
    _timer?.cancel();

    await ref.read(authControllerProvider.notifier).refresh();

    if (!mounted) return;

    final authState = ref.read(authControllerProvider);

    final Widget destination =
        authState is AuthAuthenticated &&
                authState.ageConfirmed &&
                !authState.bannedUnderage
            ? const HomeScreen()
            : const ConfirmAgeScreen();

    Navigator.of(context, rootNavigator: true).pushAndRemoveUntil(
      MaterialPageRoute<void>(
        builder: (_) => destination,
      ),
      (route) => false,
    );
  }

  @override
  void dispose() {
    _timer?.cancel();
    _authSubscription?.cancel();
    super.dispose();
  }

  Future<void> _checkConfirmation({
    bool silent = false,
  }) async {
    if (_isChecking) return;

    if (!silent) {
      setState(() {
        _isChecking = true;
        _errorText = null;
        _successText = null;
      });
    }

    try {
      final client = Supabase.instance.client;

      if (client.auth.currentSession != null) {
        try {
          await client.auth.refreshSession();
        } catch (_) {}
      }

      final user = client.auth.currentUser;

      if (user != null && user.emailConfirmedAt != null) {
        await _openPostConfirmation();
        return;
      }

      if (!silent && mounted) {
        setState(() {
          _errorText =
              'Todavía no detectamos la confirmación del correo.';
        });
      }
    } on AuthException catch (e) {
      if (!mounted || silent) return;

      setState(() {
        _errorText = e.message;
      });
    } catch (_) {
      if (!mounted || silent) return;

      setState(() {
        _errorText =
            'No se pudo comprobar el estado del correo.';
      });
    } finally {
      if (!silent && mounted) {
        setState(() {
          _isChecking = false;
        });
      }
    }
  }

  Future<void> _openGmail() async {
    if (_isOpeningGmail || _isResending) return;

    setState(() {
      _isOpeningGmail = true;
      _errorText = null;
      _successText = null;
    });

    try {
      bool opened = false;

      try {
        final result =
            await _gmailChannel.invokeMethod<bool>('openGmail');

        opened = result == true;
      } on PlatformException {
        opened = false;
      }

      if (!opened) {
        final uri = Uri(
          scheme: 'mailto',
          queryParameters: {
            'to': widget.email,
          },
        );

        if (await canLaunchUrl(uri)) {
          opened = await launchUrl(
            uri,
            mode: LaunchMode.externalApplication,
          );
        }
      }

      if (!mounted) return;

      if (!opened) {
        setState(() {
          _errorText =
              'No encontramos una aplicación de correo en este dispositivo.';
        });
      }
    } catch (_) {
      if (!mounted) return;

      setState(() {
        _errorText = 'No se pudo abrir Gmail.';
      });
    } finally {
      if (mounted) {
        setState(() {
          _isOpeningGmail = false;
        });
      }
    }
  }

  Future<void> _resendEmail() async {
    if (_isResending || _isOpeningGmail) return;

    setState(() {
      _isResending = true;
      _errorText = null;
      _successText = null;
    });

    try {
      await Supabase.instance.client.auth.resend(
        type: OtpType.signup,
        email: widget.email,
      );

      if (!mounted) return;

      setState(() {
        _successText =
            'Te enviamos otro correo de confirmación.';
      });
    } on AuthException catch (e) {
      if (!mounted) return;

      setState(() {
        _errorText = e.message;
      });
    } catch (_) {
      if (!mounted) return;

      setState(() {
        _errorText = 'No se pudo reenviar el correo.';
      });
    } finally {
      if (mounted) {
        setState(() {
          _isResending = false;
        });
      }
    }
  }

  Future<void> _useAnotherAccount() async {
    _timer?.cancel();

    try {
      await ref.read(authControllerProvider.notifier).signOut();
    } catch (_) {}

    if (!mounted) return;

    Navigator.of(context, rootNavigator: true).pushAndRemoveUntil(
      MaterialPageRoute<void>(
        builder: (_) => const AuthScreen(),
      ),
      (route) => false,
    );
  }

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, _) {
        if (didPop) return;
        _useAnotherAccount();
      },
      child: Scaffold(
        backgroundColor: _bg,
        body: SafeArea(
          child: LayoutBuilder(
            builder: (context, constraints) {
              return SingleChildScrollView(
                padding: const EdgeInsets.symmetric(
                  horizontal: 32,
                ),
                child: ConstrainedBox(
                  constraints: BoxConstraints(
                    minHeight: constraints.maxHeight,
                  ),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const SizedBox(height: 20),
                      const Text(
                        'Check your email.',
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          fontSize: 32,
                          fontWeight: FontWeight.w800,
                          height: 1.12,
                          letterSpacing: -0.6,
                          color: _ink,
                        ),
                      ),
                      const SizedBox(height: 8),
                      const Text(
                        'Confirma tu email para continuar.',
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          fontSize: 15,
                          color: _muted,
                          height: 1.4,
                        ),
                      ),
                      const SizedBox(height: 30),
                      Container(
                        width: double.infinity,
                        padding: const EdgeInsets.symmetric(
                          horizontal: 18,
                          vertical: 18,
                        ),
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(22),
                          border: Border.all(
                            color: _line,
                          ),
                        ),
                        child: Row(
                          children: [
                            Container(
                              width: 48,
                              height: 48,
                              decoration: BoxDecoration(
                                color: _bg,
                                borderRadius:
                                    BorderRadius.circular(16),
                              ),
                              child: const Icon(
                                Icons.mail_outline_rounded,
                                color: _navy,
                                size: 24,
                              ),
                            ),
                            const SizedBox(width: 14),
                            Expanded(
                              child: Column(
                                crossAxisAlignment:
                                    CrossAxisAlignment.start,
                                children: [
                                  const Text(
                                    'Correo enviado a',
                                    style: TextStyle(
                                      fontSize: 12,
                                      color: _muted,
                                      fontWeight:
                                          FontWeight.w500,
                                    ),
                                  ),
                                  const SizedBox(height: 3),
                                  Text(
                                    widget.email,
                                    maxLines: 2,
                                    overflow:
                                        TextOverflow.ellipsis,
                                    style: const TextStyle(
                                      fontSize: 14,
                                      color: _ink,
                                      fontWeight:
                                          FontWeight.w600,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 16),
                      const Text(
                        'Busca el mensaje de confirmación de Numination '
                        'y pulsa el enlace que aparece dentro.',
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          fontSize: 13,
                          height: 1.45,
                          color: _muted,
                        ),
                      ),
                      const SizedBox(height: 28),
                      SizedBox(
                        width: double.infinity,
                        height: 52,
                        child: ElevatedButton(
                          onPressed:
                              _isOpeningGmail || _isResending
                                  ? null
                                  : _openGmail,
                          style: ElevatedButton.styleFrom(
                            backgroundColor: _navy,
                            foregroundColor: Colors.white,
                            disabledBackgroundColor:
                                _navy.withValues(alpha: 0.65),
                            disabledForegroundColor:
                                Colors.white,
                            elevation: 0,
                            shape: RoundedRectangleBorder(
                              borderRadius:
                                  BorderRadius.circular(28),
                            ),
                          ),
                          child: _isOpeningGmail
                              ? const SizedBox(
                                  width: 21,
                                  height: 21,
                                  child:
                                      CircularProgressIndicator(
                                    strokeWidth: 2.3,
                                    color: Colors.white,
                                  ),
                                )
                              : const Row(
                                  mainAxisSize:
                                      MainAxisSize.min,
                                  children: [
                                    Icon(
                                      Icons.mail_rounded,
                                      size: 19,
                                    ),
                                    SizedBox(width: 9),
                                    Text(
                                      'Abrir aplicación Gmail',
                                      style: TextStyle(
                                        fontSize: 15,
                                        fontWeight:
                                            FontWeight.w600,
                                      ),
                                    ),
                                  ],
                                ),
                        ),
                      ),
                      const SizedBox(height: 12),
                      SizedBox(
                        width: double.infinity,
                        height: 50,
                        child: OutlinedButton(
                          onPressed:
                              _isChecking ||
                                      _isOpeningGmail ||
                                      _isResending
                                  ? null
                                  : () =>
                                      _checkConfirmation(),
                          style: OutlinedButton.styleFrom(
                            foregroundColor: _ink,
                            side: const BorderSide(
                              color: _line,
                            ),
                            shape: RoundedRectangleBorder(
                              borderRadius:
                                  BorderRadius.circular(28),
                            ),
                          ),
                          child: _isChecking
                              ? const SizedBox(
                                  width: 20,
                                  height: 20,
                                  child:
                                      CircularProgressIndicator(
                                    strokeWidth: 2.2,
                                    color: _navy,
                                  ),
                                )
                              : const Text(
                                  'Ya confirmé mi correo',
                                  style: TextStyle(
                                    fontSize: 15,
                                    fontWeight:
                                        FontWeight.w600,
                                  ),
                                ),
                        ),
                      ),
                      if (_errorText != null) ...[
                        const SizedBox(height: 14),
                        Container(
                          width: double.infinity,
                          padding: const EdgeInsets.symmetric(
                            horizontal: 14,
                            vertical: 11,
                          ),
                          decoration: BoxDecoration(
                            color: const Color(0xFFFDF0F0),
                            borderRadius:
                                BorderRadius.circular(14),
                          ),
                          child: Text(
                            _errorText!,
                            textAlign: TextAlign.center,
                            style: const TextStyle(
                              color: _error,
                              fontSize: 13,
                              height: 1.35,
                            ),
                          ),
                        ),
                      ],
                      if (_successText != null) ...[
                        const SizedBox(height: 14),
                        Container(
                          width: double.infinity,
                          padding: const EdgeInsets.symmetric(
                            horizontal: 14,
                            vertical: 11,
                          ),
                          decoration: BoxDecoration(
                            color: const Color(0xFFF1F5F3),
                            borderRadius:
                                BorderRadius.circular(14),
                          ),
                          child: Text(
                            _successText!,
                            textAlign: TextAlign.center,
                            style: const TextStyle(
                              color: _navy,
                              fontSize: 13,
                              height: 1.35,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ),
                      ],
                      const SizedBox(height: 22),
                      GestureDetector(
                        onTap:
                            _isResending || _isOpeningGmail
                                ? null
                                : _resendEmail,
                        child: Text(
                          _isResending
                              ? 'Enviando...'
                              : 'No recibí el correo · Reenviar',
                          style: const TextStyle(
                            fontSize: 14,
                            color: _muted,
                            fontWeight: FontWeight.w500,
                            decoration:
                                TextDecoration.underline,
                          ),
                        ),
                      ),
                      const SizedBox(height: 18),
                      GestureDetector(
                        onTap:
                            _isOpeningGmail || _isResending
                                ? null
                                : _useAnotherAccount,
                        child: const Text(
                          'Usar otra cuenta',
                          style: TextStyle(
                            fontSize: 14,
                            color: _muted,
                            fontWeight: FontWeight.w500,
                            decoration:
                                TextDecoration.underline,
                          ),
                        ),
                      ),
                      const SizedBox(height: 24),
                    ],
                  ),
                ),
              );
            },
          ),
        ),
      ),
    );
  }
}