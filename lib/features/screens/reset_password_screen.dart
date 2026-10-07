import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../core/api.dart';
import 'auth_screen.dart';

class ResetPasswordScreen extends StatefulWidget {
  const ResetPasswordScreen({super.key});

  @override
  State<ResetPasswordScreen> createState() =>
      _ResetPasswordScreenState();
}

class _ResetPasswordScreenState extends State<ResetPasswordScreen> {
  final _passwordController = TextEditingController();
  final _confirmController = TextEditingController();

  bool _hidePassword = true;
  bool _hideConfirm = true;
  bool _busy = false;
  bool _completed = false;
  String? _error;

  @override
  void dispose() {
    _passwordController.dispose();
    _confirmController.dispose();
    super.dispose();
  }

  Future<void> _savePassword() async {
    final password = _passwordController.text;
    final confirm = _confirmController.text;
    final auth = Supabase.instance.client.auth;

    if (password.length < 8) {
      setState(() {
        _error = 'Usa una contraseña de al menos 8 caracteres.';
      });
      return;
    }

    if (password != confirm) {
      setState(() {
        _error = 'Las contraseñas no coinciden.';
      });
      return;
    }

    if (auth.currentSession == null) {
      setState(() {
        _error =
            'El enlace no tiene una sesión de recuperación válida. Solicita otro correo.';
      });
      return;
    }

    setState(() {
      _busy = true;
      _error = null;
    });

    try {
      // Cambia de verdad la contraseña del usuario en Supabase Auth.
      await auth.updateUser(
        UserAttributes(password: password),
      );

      if (!mounted) return;

      setState(() {
        _completed = true;
      });
    } on AuthException catch (e) {
      if (!mounted) return;
      setState(() => _error = e.message);
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _error = 'No se pudo actualizar la contraseña.';
      });
    } finally {
      if (mounted) {
        setState(() => _busy = false);
      }
    }
  }

  Future<void> _returnToLogin() async {
    try {
      await Supabase.instance.client.auth.signOut();
    } catch (_) {}

    ApiClient.setToken(null);

    if (!mounted) return;

    Navigator.of(context, rootNavigator: true).pushAndRemoveUntil(
      MaterialPageRoute<void>(
        builder: (_) => const AuthScreen(),
      ),
      (_) => false,
    );
  }

  Widget _passwordField({
    required TextEditingController controller,
    required String label,
    required bool obscure,
    required VoidCallback onToggle,
    required TextInputAction action,
    ValueChanged<String>? onSubmitted,
  }) {
    return TextField(
      controller: controller,
      obscureText: obscure,
      enabled: !_busy,
      autocorrect: false,
      textInputAction: action,
      onSubmitted: onSubmitted,
      decoration: InputDecoration(
        labelText: label,
        prefixIcon: const Icon(Icons.lock_outline_rounded),
        suffixIcon: IconButton(
          onPressed: _busy ? null : onToggle,
          icon: Icon(
            obscure
                ? Icons.visibility_outlined
                : Icons.visibility_off_outlined,
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Restablecer contraseña'),
      ),
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(24),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 460),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Text(
                    _completed
                        ? 'Contraseña actualizada'
                        : 'Crea una contraseña nueva',
                    textAlign: TextAlign.center,
                    style: const TextStyle(
                      fontSize: 27,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                  const SizedBox(height: 10),
                  Text(
                    _completed
                        ? 'Ya puedes iniciar sesión con tu nueva contraseña.'
                        : 'Elige una contraseña nueva para tu cuenta de Numination.',
                    textAlign: TextAlign.center,
                  ),
                  if (!_completed) ...[
                    const SizedBox(height: 28),
                    _passwordField(
                      controller: _passwordController,
                      label: 'Nueva contraseña',
                      obscure: _hidePassword,
                      onToggle: () {
                        setState(() {
                          _hidePassword = !_hidePassword;
                        });
                      },
                      action: TextInputAction.next,
                    ),
                    const SizedBox(height: 14),
                    _passwordField(
                      controller: _confirmController,
                      label: 'Confirmar contraseña',
                      obscure: _hideConfirm,
                      onToggle: () {
                        setState(() {
                          _hideConfirm = !_hideConfirm;
                        });
                      },
                      action: TextInputAction.done,
                      onSubmitted: (_) => _savePassword(),
                    ),
                    if (_error != null) ...[
                      const SizedBox(height: 14),
                      Text(
                        _error!,
                        style: const TextStyle(
                          color: Colors.redAccent,
                        ),
                      ),
                    ],
                  ] else if (_error != null) ...[
                    const SizedBox(height: 14),
                    Text(
                      _error!,
                      style: const TextStyle(color: Colors.redAccent),
                    ),
                  ],
                  const SizedBox(height: 24),
                  SizedBox(
                    height: 52,
                    child: ElevatedButton(
                      onPressed: _busy
                          ? null
                          : _completed
                              ? _returnToLogin
                              : _savePassword,
                      child: _busy
                          ? const SizedBox(
                              width: 22,
                              height: 22,
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                              ),
                            )
                          : Text(
                              _completed
                                  ? 'Volver al inicio de sesión'
                                  : 'Guardar contraseña',
                            ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
