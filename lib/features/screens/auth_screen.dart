import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/auth_controller.dart';
import '../../core/env.dart';
import '../../core/theme.dart';

class AuthScreen extends ConsumerStatefulWidget {
  const AuthScreen({super.key});
  @override ConsumerState<AuthScreen> createState() => _AuthScreenState();
}
class _AuthScreenState extends ConsumerState<AuthScreen> {
  final email = TextEditingController();
  final code = TextEditingController();
  String? error;
  bool sent = false;
  @override void dispose(){ email.dispose(); code.dispose(); super.dispose(); }
  Future<void> submit() async {
    final value = email.text.trim();
    if (!RegExp(r'^[^@\s]+@[^@\s]+\.[^@\s]+$').hasMatch(value)) { setState(() => error = 'Correo inválido'); return; }
    setState(() { error = null; sent = false; });
    await ref.read(authControllerProvider.notifier).requestEmailCode(value);
    if (mounted && ref.read(authControllerProvider) is AuthUnauthenticated) setState(() => sent = true);
  }
  @override Widget build(BuildContext context) {
    final state = ref.watch(authControllerProvider);
    final loading = state is AuthLoading;
    final remoteError = state is AuthError ? state.message : null;
    return Scaffold(
      body: Stack(children: [
        DecoratedBox(
          decoration: const BoxDecoration(gradient: LinearGradient(begin: Alignment.topLeft, end: Alignment.bottomRight, colors: [AppColors.obsidian, Color(0xFF151023), AppColors.obsidian])),
          child: Center(child: SingleChildScrollView(padding: const EdgeInsets.all(28), child: ConstrainedBox(constraints: const BoxConstraints(maxWidth: 520), child: GlassCard(
            padding: const EdgeInsets.all(28),
            child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
              Center(child: Image.asset('assets/images/numination_logo_wordmark.png', height: 52)),
              const SizedBox(height: 24),
              const Text('La IA para quienes resuelven problemas.', textAlign: TextAlign.center, style: TextStyle(fontSize: 28, fontWeight: FontWeight.w800)),
              const SizedBox(height: 10),
              const Text('Construye, piensa y desbloquea ideas desde cualquier lugar.', textAlign: TextAlign.center, style: TextStyle(color: AppColors.muted, height: 1.4)),
              const SizedBox(height: 26),
              _ProviderButton(icon: Icons.g_mobiledata, label: 'Continuar con Google', onTap: () => ref.read(authControllerProvider.notifier).googleLogin(), enabled: !loading),
              const SizedBox(height: 10),
              _ProviderButton(icon: Icons.code_rounded, label: 'Continuar con GitHub', onTap: () => ref.read(authControllerProvider.notifier).githubLogin(), enabled: !loading),
              const SizedBox(height: 20),
              Row(children: [const Expanded(child: Divider(color: AppColors.border)), Padding(padding: const EdgeInsets.symmetric(horizontal: 12), child: Text('o', style: TextStyle(color: AppColors.muted))), const Expanded(child: Divider(color: AppColors.border))]),
              const SizedBox(height: 18),
              TextField(controller: email, onSubmitted: (_) => submit(), keyboardType: TextInputType.emailAddress, decoration: const InputDecoration(prefixIcon: Icon(Icons.mail_outline), hintText: 'usuario@email.com')),
              const SizedBox(height: 12),
              FilledButton.icon(onPressed: loading ? null : submit, icon: const Icon(Icons.arrow_forward_rounded), label: Text(sent ? 'Enlace/código enviado' : 'Continuar')),
              if (sent) ...[
                const Padding(padding: EdgeInsets.only(top: 12), child: Text('Revisa tu correo e introduce el código recibido.', textAlign: TextAlign.center, style: TextStyle(color: AppColors.green))),
                const SizedBox(height: 10),
                TextField(controller: code, maxLength: 8, keyboardType: TextInputType.number, textAlign: TextAlign.center, decoration: const InputDecoration(hintText: 'Código de verificación')),
                const SizedBox(height: 8),
                OutlinedButton.icon(onPressed: loading ? null : () => ref.read(authControllerProvider.notifier).verifyEmailCode(email.text, code.text), icon: const Icon(Icons.verified_outlined), label: const Text('Verificar código')),
              ],
              if (error != null || remoteError != null) Padding(padding: const EdgeInsets.only(top: 12), child: Text(error ?? remoteError!, textAlign: TextAlign.center, style: const TextStyle(color: AppColors.red, fontSize: 12))),
              const SizedBox(height: 16),
              Text('Redirect: ${Env.authRedirectUrl}', textAlign: TextAlign.center, style: const TextStyle(color: AppColors.muted, fontSize: 10)),
              const SizedBox(height: 8),
              const Text('Al continuar aceptas los Términos de Servicio y la Política de Privacidad.', textAlign: TextAlign.center, style: TextStyle(color: AppColors.muted, fontSize: 10)),
            ]),
          )))),
        ),
        if (loading) const Positioned.fill(child: ColoredBox(color: Color(0x55000000), child: Center(child: CircularProgressIndicator()))),
      ]),
    );
  }
}
class _ProviderButton extends StatelessWidget {
  final IconData icon; final String label; final VoidCallback onTap; final bool enabled;
  const _ProviderButton({required this.icon, required this.label, required this.onTap, required this.enabled});
  @override Widget build(BuildContext context) => SizedBox(height: 50, child: OutlinedButton.icon(onPressed: enabled ? onTap : null, icon: Icon(icon), label: Text(label, style: const TextStyle(fontWeight: FontWeight.w700))));
}
