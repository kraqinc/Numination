import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/auth_controller.dart';
import '../../core/theme.dart';
import 'confirm_passwd_screen.dart';

class AuthScreen extends ConsumerStatefulWidget {
  const AuthScreen({super.key});
  @override
  ConsumerState<AuthScreen> createState() => _AuthScreenState();
}

class _AuthScreenState extends ConsumerState<AuthScreen> {
  final email = TextEditingController();
  final password = TextEditingController();
  final passwordFocus = FocusNode();
  String? localError;
  bool obscure = true;
  bool rememberMe = false;

  @override
  void dispose() {
    email.dispose();
    password.dispose();
    passwordFocus.dispose();
    super.dispose();
  }

  Future<void> submitEmail() async {
    final value = email.text.trim();
    if (!RegExp(r'^[^@\s]+@[^@\s]+\.[^@\s]+$').hasMatch(value)) {
      setState(() => localError = 'Correo inválido');
      return;
    }
    setState(() => localError = null);
    await ref.read(authControllerProvider.notifier).checkEmail(value);
  }

  void submitPassword(String forEmail) {
    if (password.text.isEmpty) {
      setState(() => localError = 'Ingresa tu contraseña');
      return;
    }
    setState(() => localError = null);
    ref.read(authControllerProvider.notifier).signInWithPassword(forEmail, password.text);
  }

  void notYou() {
    password.clear();
    setState(() => localError = null);
    ref.read(authControllerProvider.notifier).resetToEmailStep();
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(authControllerProvider);
    final loading = state is AuthLoading;
    final remoteError = state is AuthError ? state.message : null;

    // Route to confirm_passwd as soon as we learn the email is new.
    if (state is AuthEmailChecked && !state.exists) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted) return;
        Navigator.of(context).pushReplacement(
          MaterialPageRoute(builder: (_) => ConfirmPasswdScreen(email: state.email)),
        );
      });
    }

    final checkedState = state is AuthEmailChecked ? state : null;
    final showPasswordStep = checkedState != null && checkedState.exists;
    final stepEmail = showPasswordStep ? checkedState.email : email.text.trim();

    return Scaffold(
      backgroundColor: AuthColors.background,
      body: Stack(
        children: [
          const DecoratedBox(
            decoration: BoxDecoration(color: AuthColors.background),
          ),
          Center(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(28),
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 420),
                child: _AuthCard(
                  child: AnimatedSwitcher(
                    duration: const Duration(milliseconds: 220),
                    child: showPasswordStep
                        ? _PasswordStep(
                            key: const ValueKey('password'),
                            email: stepEmail,
                            controller: password,
                            focusNode: passwordFocus,
                            obscure: obscure,
                            rememberMe: rememberMe,
                            loading: loading,
                            error: localError ?? remoteError,
                            onToggleObscure: () => setState(() => obscure = !obscure),
                            onToggleRemember: (v) => setState(() => rememberMe = v ?? false),
                            onNotYou: notYou,
                            onSubmit: () => submitPassword(stepEmail),
                          )
                        : _EmailStep(
                            key: const ValueKey('email'),
                            controller: email,
                            loading: loading,
                            error: localError ?? remoteError,
                            onSubmit: submitEmail,
                            onGoogle: () => ref.read(authControllerProvider.notifier).googleLogin(),
                            onGitHub: () => ref.read(authControllerProvider.notifier).githubLogin(),
                          ),
                  ),
                ),
              ),
            ),
          ),
          if (loading)
            const Positioned.fill(
              child: IgnorePointer(
                child: ColoredBox(color: Color(0x33000000)),
              ),
            ),
        ],
      ),
    );
  }
}

class _AuthCard extends StatelessWidget {
  final Widget child;
  const _AuthCard({required this.child});
  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(28, 32, 28, 24),
      decoration: BoxDecoration(
        color: AuthColors.card,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: AuthColors.border),
        boxShadow: [
          BoxShadow(color: Colors.black.withValues(alpha: 0.5), blurRadius: 40, offset: const Offset(0, 20)),
        ],
      ),
      child: child,
    );
  }
}

class _Logo extends StatelessWidget {
  const _Logo();
  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Container(
          width: 48,
          height: 48,
          decoration: BoxDecoration(
            color: AuthColors.text,
            borderRadius: BorderRadius.circular(10),
          ),
          child: const Center(
            child: Icon(Icons.bolt_rounded, color: Colors.black, size: 26),
          ),
        ),
        const SizedBox(height: 16),
        Image.asset('assets/images/numination_logo_wordmark.png', height: 26),
      ],
    );
  }
}

class _EmailStep extends StatelessWidget {
  final TextEditingController controller;
  final bool loading;
  final String? error;
  final VoidCallback onSubmit;
  final VoidCallback onGoogle;
  final VoidCallback onGitHub;
  const _EmailStep({
    super.key,
    required this.controller,
    required this.loading,
    required this.error,
    required this.onSubmit,
    required this.onGoogle,
    required this.onGitHub,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const _Logo(),
        const SizedBox(height: 18),
        const Text(
          'Sign in to your account',
          textAlign: TextAlign.center,
          style: TextStyle(color: AuthColors.muted, fontSize: 14),
        ),
        const SizedBox(height: 26),
        const Text('Email Address', style: TextStyle(color: AuthColors.muted, fontSize: 12, fontWeight: FontWeight.w600)),
        const SizedBox(height: 8),
        _AuthField(
          controller: controller,
          hint: 'name@company.com',
          keyboardType: TextInputType.emailAddress,
          onSubmitted: (_) => onSubmit(),
        ),
        const SizedBox(height: 18),
        _PrimaryButton(label: 'Continue', loading: loading, onTap: onSubmit),
        if (error != null) ...[
          const SizedBox(height: 10),
          Text(error!, textAlign: TextAlign.center, style: const TextStyle(color: AuthColors.error, fontSize: 12)),
        ],
        const SizedBox(height: 22),
        Row(
          children: [
            const Expanded(child: Divider(color: AuthColors.border)),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 12),
              child: Text('or continue with', style: TextStyle(color: AuthColors.mutedSoft, fontSize: 12)),
            ),
            const Expanded(child: Divider(color: AuthColors.border)),
          ],
        ),
        const SizedBox(height: 18),
        _ProviderButton(icon: Icons.g_mobiledata_rounded, label: 'Sign in with Google', onTap: loading ? null : onGoogle),
        const SizedBox(height: 10),
        _ProviderButton(icon: Icons.code_rounded, label: 'Sign in with GitHub', onTap: loading ? null : onGitHub),
        const SizedBox(height: 20),
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Text("Don't have an account? ", style: TextStyle(color: AuthColors.muted, fontSize: 13)),
            Text('Sign up', style: TextStyle(color: AuthColors.text, fontSize: 13, fontWeight: FontWeight.w700)),
          ],
        ),
      ],
    );
  }
}

class _PasswordStep extends StatelessWidget {
  final String email;
  final TextEditingController controller;
  final FocusNode focusNode;
  final bool obscure;
  final bool rememberMe;
  final bool loading;
  final String? error;
  final VoidCallback onToggleObscure;
  final ValueChanged<bool?> onToggleRemember;
  final VoidCallback onNotYou;
  final VoidCallback onSubmit;
  const _PasswordStep({
    super.key,
    required this.email,
    required this.controller,
    required this.focusNode,
    required this.obscure,
    required this.rememberMe,
    required this.loading,
    required this.error,
    required this.onToggleObscure,
    required this.onToggleRemember,
    required this.onNotYou,
    required this.onSubmit,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const _Logo(),
        const SizedBox(height: 18),
        const Text('Welcome back', textAlign: TextAlign.center, style: TextStyle(color: AuthColors.muted, fontSize: 14)),
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
              Expanded(child: Text(email, overflow: TextOverflow.ellipsis, style: const TextStyle(color: AuthColors.text, fontSize: 13, fontWeight: FontWeight.w600))),
              GestureDetector(
                onTap: onNotYou,
                child: const Text('Not you?', style: TextStyle(color: AuthColors.muted, fontSize: 12, decoration: TextDecoration.underline)),
              ),
            ],
          ),
        ),
        const SizedBox(height: 18),
        Text('Password for $email', style: const TextStyle(color: AuthColors.muted, fontSize: 12, fontWeight: FontWeight.w600)),
        const SizedBox(height: 8),
        _AuthField(
          controller: controller,
          focusNode: focusNode,
          hint: '••••••••••',
          obscureText: obscure,
          autofocus: true,
          onSubmitted: (_) => onSubmit(),
          suffix: IconButton(
            icon: Icon(obscure ? Icons.visibility_off_outlined : Icons.visibility_outlined, size: 18, color: AuthColors.muted),
            onPressed: onToggleObscure,
          ),
        ),
        const SizedBox(height: 14),
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Row(
              children: [
                SizedBox(
                  width: 18,
                  height: 18,
                  child: Checkbox(
                    value: rememberMe,
                    onChanged: onToggleRemember,
                    activeColor: AuthColors.text,
                    checkColor: Colors.black,
                    side: const BorderSide(color: AuthColors.borderStrong),
                  ),
                ),
                const SizedBox(width: 8),
                const Text('Remember me', style: TextStyle(color: AuthColors.muted, fontSize: 12)),
              ],
            ),
            const Text('Forgot Password?', style: TextStyle(color: AuthColors.text, fontSize: 12, fontWeight: FontWeight.w600)),
          ],
        ),
        const SizedBox(height: 18),
        _PrimaryButton(label: 'Sign In', loading: loading, onTap: onSubmit),
        if (error != null) ...[
          const SizedBox(height: 10),
          Text(error!, textAlign: TextAlign.center, style: const TextStyle(color: AuthColors.error, fontSize: 12)),
        ],
        const SizedBox(height: 18),
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Text("Don't have an account? ", style: TextStyle(color: AuthColors.muted, fontSize: 13)),
            Text('Sign up', style: TextStyle(color: AuthColors.text, fontSize: 13, fontWeight: FontWeight.w700)),
          ],
        ),
      ],
    );
  }
}

class _AuthField extends StatelessWidget {
  final TextEditingController controller;
  final String hint;
  final FocusNode? focusNode;
  final bool obscureText;
  final bool autofocus;
  final TextInputType? keyboardType;
  final Widget? suffix;
  final ValueChanged<String>? onSubmitted;
  const _AuthField({
    required this.controller,
    required this.hint,
    this.focusNode,
    this.obscureText = false,
    this.autofocus = false,
    this.keyboardType,
    this.suffix,
    this.onSubmitted,
  });

  @override
  Widget build(BuildContext context) {
    return TextField(
      controller: controller,
      focusNode: focusNode,
      obscureText: obscureText,
      autofocus: autofocus,
      keyboardType: keyboardType,
      onSubmitted: onSubmitted,
      style: const TextStyle(color: AuthColors.text, fontSize: 14),
      cursorColor: AuthColors.text,
      decoration: InputDecoration(
        hintText: hint,
        hintStyle: const TextStyle(color: AuthColors.mutedSoft, fontSize: 14),
        filled: true,
        fillColor: AuthColors.surface,
        suffixIcon: suffix,
        contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: AuthColors.border)),
        enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: AuthColors.border)),
        focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: AuthColors.borderStrong)),
      ),
    );
  }
}

class _PrimaryButton extends StatelessWidget {
  final String label;
  final bool loading;
  final VoidCallback onTap;
  const _PrimaryButton({required this.label, required this.loading, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 46,
      child: ElevatedButton(
        onPressed: loading ? null : onTap,
        style: ElevatedButton.styleFrom(
          backgroundColor: AuthColors.text,
          foregroundColor: Colors.black,
          disabledBackgroundColor: AuthColors.text.withValues(alpha: 0.6),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          elevation: 0,
        ),
        child: loading
            ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.black))
            : Text(label, style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 14)),
      ),
    );
  }
}

class _ProviderButton extends StatelessWidget {
  final IconData icon;
  final String label;
  final VoidCallback? onTap;
  const _ProviderButton({required this.icon, required this.label, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 46,
      child: OutlinedButton.icon(
        onPressed: onTap,
        style: OutlinedButton.styleFrom(
          side: const BorderSide(color: AuthColors.border),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          foregroundColor: AuthColors.text,
        ),
        icon: Icon(icon, size: 18),
        label: Text(label, style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13)),
      ),
    );
  }
}