import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../core/api.dart';
import 'auth_screen.dart';

class ResetPasswordScreen extends StatefulWidget {
  const ResetPasswordScreen({super.key});

  @override
  State<ResetPasswordScreen> createState() => _ResetPasswordScreenState();
}

class _ResetPasswordScreenState extends State<ResetPasswordScreen> {
  final _passwordController = TextEditingController();
  final _confirmController = TextEditingController();

  bool _obscurePassword = true;
  bool _obscureConfirm = true;
  bool _isLoading = false;
  bool _completed = false;
  String? _errorText;

  static const _bg = Color(0xFFF7F9F8);
  static const _navy = Color(0xFF16325C);
  static const _ink = Color(0xFF111111);
  static const _muted = Color(0xFF8A8A8A);
  static const _line = Color(0xFFD4D4D4);
  static const _error = Color(0xFFC23B3B);

  @override
  void dispose() {
    _passwordController.dispose();
    _confirmController.dispose();
    super.dispose();
  }

  Future<void> _updatePassword() async {
    final password = _passwordController.text;
    final confirmation = _confirmController.text;

    if (password.length < 8) {
      setState(() => _errorText = 'La contraseña debe tener al menos 8 caracteres.');
      return;
    }
    if (password != confirmation) {
      setState(() => _errorText = 'Las contraseñas no coinciden.');
      return;
    }
    if (Supabase.instance.client.auth.currentSession == null) {
      setState(() => _errorText = 'El enlace expiró. Solicita otro correo de recuperación.');
      return;
    }

    setState(() {
      _isLoading = true;
      _errorText = null;
    });
    try {
      await Supabase.instance.client.auth.updateUser(
        UserAttributes(password: password),
      );
      if (!mounted) return;
      setState(() => _completed = true);
    } on AuthException catch (e) {
      if (!mounted) return;
      setState(() => _errorText = e.message);
    } catch (_) {
      if (!mounted) return;
      setState(() => _errorText = 'No se pudo actualizar la contraseña.');
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _returnToLogin() async {
    try {
      await Supabase.instance.client.auth.signOut();
    } catch (_) {}
    ApiClient.setToken(null);
    if (!mounted) return;
    Navigator.of(context, rootNavigator: true).pushAndRemoveUntil(
      MaterialPageRoute<void>(builder: (_) => const AuthScreen()),
      (route) => false,
    );
  }

  Widget _field({
    required TextEditingController controller,
    required String hint,
    required bool obscure,
    required VoidCallback toggleVisibility,
    required TextInputAction action,
    ValueChanged<String>? onSubmitted,
  }) {
    return TextField(
      controller: controller,
      obscureText: obscure,
      enabled: !_isLoading,
      autocorrect: false,
      textInputAction: action,
      onSubmitted: onSubmitted,
      style: const TextStyle(fontSize: 15, color: _ink),
      decoration: InputDecoration(
        hintText: hint,
        hintStyle: const TextStyle(color: _muted, fontSize: 15),
        prefixIcon: const Icon(Icons.lock_outline_rounded, size: 20, color: _muted),
        suffixIcon: IconButton(
          onPressed: _isLoading ? null : toggleVisibility,
          icon: Icon(
            obscure ? Icons.visibility_outlined : Icons.visibility_off_outlined,
            color: _muted,
            size: 21,
          ),
        ),
        filled: true,
        fillColor: Colors.white,
        contentPadding: const EdgeInsets.symmetric(horizontal: 18, vertical: 16),
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
          borderSide: const BorderSide(color: Color(0xFF9AA7BC)),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _bg,
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.symmetric(horizontal: 30, vertical: 24),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 460),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    _completed ? 'Password updated.' : 'Reset your password.',
                    textAlign: TextAlign.center,
                    style: const TextStyle(
                      fontSize: 31,
                      fontWeight: FontWeight.w800,
                      height: 1.12,
                      letterSpacing: -0.6,
                      color: _ink,
                    ),
                  ),
                  const SizedBox(height: 12),
                  Text(
                    _completed
                        ? 'Tu contraseña se actualizó. Ya puedes iniciar sesión con la nueva contraseña.'
                        : 'Elige una contraseña nueva para tu cuenta de Numination.',
                    textAlign: TextAlign.center,
                    style: const TextStyle(fontSize: 14, height: 1.45, color: _muted),
                  ),
                  if (!_completed) ...[
                    const SizedBox(height: 30),
                    _field(
                      controller: _passwordController,
                      hint: 'Nueva contraseña',
                      obscure: _obscurePassword,
                      toggleVisibility: () => setState(() => _obscurePassword = !_obscurePassword),
                      action: TextInputAction.next,
                    ),
                    const SizedBox(height: 14),
                    _field(
                      controller: _confirmController,
                      hint: 'Confirmar contraseña',
                      obscure: _obscureConfirm,
                      toggleVisibility: () => setState(() => _obscureConfirm = !_obscureConfirm),
                      action: TextInputAction.done,
                      onSubmitted: (_) => _updatePassword(),
                    ),
                    if (_errorText != null) ...[
                      const SizedBox(height: 12),
                      Align(
                        alignment: Alignment.centerLeft,
                        child: Text(
                          _errorText!,
                          style: const TextStyle(color: _error, fontSize: 13),
                        ),
                      ),
                    ],
                  ],
                  const SizedBox(height: 24),
                  SizedBox(
                    width: double.infinity,
                    height: 52,
                    child: ElevatedButton(
                      onPressed: _isLoading
                          ? null
                          : _completed
                              ? _returnToLogin
                              : _updatePassword,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: _navy,
                        foregroundColor: Colors.white,
                        disabledBackgroundColor: _navy.withValues(alpha: 0.65),
                        disabledForegroundColor: Colors.white,
                        elevation: 0,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(28),
                        ),
                      ),
                      child: _isLoading
                          ? const SizedBox(
                              width: 21,
                              height: 21,
                              child: CircularProgressIndicator(
                                strokeWidth: 2.3,
                                color: Colors.white,
                              ),
                            )
                          : Text(
                              _completed ? 'Volver a iniciar sesión' : 'Guardar contraseña',
                              style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w600),
                            ),
                    ),
                  ),
                  const SizedBox(height: 18),
                  if (!_completed)
                    GestureDetector(
                      onTap: _isLoading ? null : _returnToLogin,
                      child: const Text(
                        'Cancelar y volver al login',
                        style: TextStyle(
                          fontSize: 14,
                          color: _muted,
                          decoration: TextDecoration.underline,
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
