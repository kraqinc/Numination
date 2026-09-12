import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/auth_controller.dart';
import '../../core/theme.dart';

class ConfirmPasswdScreen extends ConsumerStatefulWidget {
  final String email;
  const ConfirmPasswdScreen({super.key, required this.email});

  @override
  ConsumerState<ConfirmPasswdScreen> createState() => _ConfirmPasswdScreenState();
}

class _ConfirmPasswdScreenState extends ConsumerState<ConfirmPasswdScreen> {
  final password = TextEditingController();
  final confirm = TextEditingController();
  bool obscurePassword = true;
  bool obscureConfirm = true;
  String? localError;

  @override
  void dispose() {
    password.dispose();
    confirm.dispose();
    super.dispose();
  }

  void submit() {
    if (password.text.length < 8) {
      setState(() => localError = 'La contraseña debe tener al menos 8 caracteres');
      return;
    }
    if (password.text != confirm.text) {
      setState(() => localError = 'Las contraseñas no coinciden');
      return;
    }
    setState(() => localError = null);
    ref.read(authControllerProvider.notifier).signUpWithPassword(widget.email, password.text);
  }

  void notYou() {
    ref.read(authControllerProvider.notifier).resetToEmailStep();
    Navigator.of(context).pop();
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(authControllerProvider);
    final loading = state is AuthLoading;
    final remoteError = state is AuthError ? state.message : null;
    final error = localError ?? remoteError;

    return Scaffold(
      backgroundColor: AuthColors.background,
      body: Stack(
        children: [
          Center(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(28),
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 420),
                child: Container(
                  padding: const EdgeInsets.fromLTRB(28, 32, 28, 24),
                  decoration: BoxDecoration(
                    color: AuthColors.card,
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(color: AuthColors.border),
                    boxShadow: [
                      BoxShadow(color: Colors.black.withValues(alpha: 0.5), blurRadius: 40, offset: const Offset(0, 20)),
                    ],
                  ),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Column(
                        children: [
                          Container(
                            width: 48,
                            height: 48,
                            decoration: BoxDecoration(color: AuthColors.text, borderRadius: BorderRadius.circular(10)),
                            child: const Center(child: Icon(Icons.bolt_rounded, color: Colors.black, size: 26)),
                          ),
                          const SizedBox(height: 16),
                          Image.asset('assets/images/numination_logo_wordmark.png', height: 26),
                        ],
                      ),
                      const SizedBox(height: 18),
                      const Text('Create your account', textAlign: TextAlign.center, style: TextStyle(color: AuthColors.muted, fontSize: 14)),
                      const SizedBox(height: 22),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                        decoration: BoxDecoration(
                          color: AuthColors.surface,
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(color: AuthColors.border),
                        ),
                        child: Row(
                          children: [
                            const CircleAvatar(radius: 11, backgroundColor: AuthColors.borderStrong, child: Icon(Icons.person, size: 13, color: AuthColors.muted)),
                            const SizedBox(width: 10),
                            Expanded(child: Text(widget.email, overflow: TextOverflow.ellipsis, style: const TextStyle(color: AuthColors.text, fontSize: 13, fontWeight: FontWeight.w600))),
                            GestureDetector(
                              onTap: notYou,
                              child: const Text('Not you?', style: TextStyle(color: AuthColors.muted, fontSize: 12, decoration: TextDecoration.underline)),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 18),
                      const Text('Create a password', style: TextStyle(color: AuthColors.muted, fontSize: 12, fontWeight: FontWeight.w600)),
                      const SizedBox(height: 8),
                      _field(
                        controller: password,
                        hint: '••••••••••',
                        obscure: obscurePassword,
                        autofocus: true,
                        onToggle: () => setState(() => obscurePassword = !obscurePassword),
                      ),
                      const SizedBox(height: 14),
                      const Text('Confirm password', style: TextStyle(color: AuthColors.muted, fontSize: 12, fontWeight: FontWeight.w600)),
                      const SizedBox(height: 8),
                      _field(
                        controller: confirm,
                        hint: '••••••••••',
                        obscure: obscureConfirm,
                        onSubmitted: (_) => submit(),
                        onToggle: () => setState(() => obscureConfirm = !obscureConfirm),
                      ),
                      const SizedBox(height: 18),
                      SizedBox(
                        height: 46,
                        child: ElevatedButton(
                          onPressed: loading ? null : submit,
                          style: ElevatedButton.styleFrom(
                            backgroundColor: AuthColors.text,
                            foregroundColor: Colors.black,
                            disabledBackgroundColor: AuthColors.text.withValues(alpha: 0.6),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                            elevation: 0,
                          ),
                          child: loading
                              ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.black))
                              : const Text('Create Account', style: TextStyle(fontWeight: FontWeight.w700, fontSize: 14)),
                        ),
                      ),
                      if (error != null) ...[
                        const SizedBox(height: 10),
                        Text(error, textAlign: TextAlign.center, style: const TextStyle(color: AuthColors.error, fontSize: 12)),
                      ],
                      const SizedBox(height: 18),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          const Text('Already have an account? ', style: TextStyle(color: AuthColors.muted, fontSize: 13)),
                          GestureDetector(
                            onTap: notYou,
                            child: const Text('Sign in', style: TextStyle(color: AuthColors.text, fontSize: 13, fontWeight: FontWeight.w700)),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
          if (loading)
            const Positioned.fill(child: IgnorePointer(child: ColoredBox(color: Color(0x33000000)))),
        ],
      ),
    );
  }

  Widget _field({
    required TextEditingController controller,
    required String hint,
    required bool obscure,
    required VoidCallback onToggle,
    bool autofocus = false,
    ValueChanged<String>? onSubmitted,
  }) {
    return TextField(
      controller: controller,
      obscureText: obscure,
      autofocus: autofocus,
      onSubmitted: onSubmitted,
      style: const TextStyle(color: AuthColors.text, fontSize: 14),
      cursorColor: AuthColors.text,
      decoration: InputDecoration(
        hintText: hint,
        hintStyle: const TextStyle(color: AuthColors.mutedSoft, fontSize: 14),
        filled: true,
        fillColor: AuthColors.surface,
        suffixIcon: IconButton(
          icon: Icon(obscure ? Icons.visibility_off_outlined : Icons.visibility_outlined, size: 18, color: AuthColors.muted),
          onPressed: onToggle,
        ),
        contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: AuthColors.border)),
        enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: AuthColors.border)),
        focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: AuthColors.borderStrong)),
      ),
    );
  }
}