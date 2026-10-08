import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../core/api.dart';
import '../../core/auth_controller.dart';

import 'home_screen.dart';

const _ageConfirmedKey = 'age_14_plus';
const _bannedUnderageKey = 'banned_underage';

bool isAgeConfirmed(User? user) {
  return user?.userMetadata?[_ageConfirmedKey] == true;
}

bool isBannedUnderage(User? user) {
  return user?.userMetadata?[_bannedUnderageKey] == true;
}

Widget nextScreenAfterAuth(User? user) {
  if (user == null || !isAgeConfirmed(user) || isBannedUnderage(user)) {
    return const ConfirmAgeScreen();
  }
  return const HomeScreen();
}

class ConfirmAgeScreen extends ConsumerStatefulWidget {
  const ConfirmAgeScreen({super.key});

  @override
  ConsumerState<ConfirmAgeScreen> createState() => _ConfirmAgeScreenState();
}

class _ConfirmAgeScreenState extends ConsumerState<ConfirmAgeScreen> {
  bool _confirmed = false;
  bool _isLoading = false;
  bool _banned = false;
  String? _errorText;

  static const _bg = Color(0xFFF7F9F8);
  static const _navy = Color(0xFF16325C);
  static const _ink = Color(0xFF111111);
  static const _muted = Color(0xFF8A8A8A);
  static const _line = Color(0xFFD4D4D4);

  @override
  void initState() {
    super.initState();
    final authState = ref.read(authControllerProvider);
    _banned =
        isBannedUnderage(Supabase.instance.client.auth.currentUser) ||
        (authState is AuthAuthenticated && authState.bannedUnderage);
  }

  Future<void> _onContinue() async {
    if (!_confirmed || _isLoading) return;

    setState(() {
      _isLoading = true;
      _errorText = null;
    });

    try {
      final session = Supabase.instance.client.auth.currentSession;
      if (session == null) {
        throw const ApiException(
          401,
          'Tu sesión expiró. Inicia sesión nuevamente.',
        );
      }
      ApiClient.setToken(session.accessToken);

      final response = await ApiClient.post('/auth/age', {
        'confirmed14Plus': true,
      });
      final data = ApiClient.decode(response);
      if (data is! Map<String, dynamic> || data['verified'] != true) {
        throw const ApiException(500, 'El backend no confirmó la edad.');
      }

      final currentUser = Supabase.instance.client.auth.currentUser;

      if (currentUser != null) {
        final metadata = <String, dynamic>{
          ...(currentUser.userMetadata ?? const <String, dynamic>{}),
          'age_14_plus': true,
          'banned_underage': false,
          'numination_email_pending': false,
        };

        await Supabase.instance.client.auth.updateUser(
          UserAttributes(data: metadata),
        );
      }

      await ref.read(authControllerProvider.notifier).refresh();
      if (!mounted) return;

      Navigator.of(context, rootNavigator: true).pushAndRemoveUntil(
        MaterialPageRoute<void>(builder: (_) => const HomeScreen()),
        (route) => false,
      );
    } on ApiException catch (e) {
      if (mounted) setState(() => _errorText = e.message);
    } on AuthException catch (e) {
      if (mounted) setState(() => _errorText = e.message);
    } catch (_) {
      if (mounted) {
        setState(() => _errorText = 'No se pudo guardar la confirmación');
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _onUnderage() async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: Colors.white,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Text(
          'Esta cuenta se bloqueará',
          style: TextStyle(
            fontWeight: FontWeight.w800,
            fontSize: 18,
            color: _ink,
          ),
        ),
        content: const Text(
          'Numination es solo para mayores de 14 años. Si continúas, esta cuenta quedará baneada y no podrás entrar.',
          style: TextStyle(fontSize: 14, height: 1.4, color: _ink),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: const Text('Cancelar', style: TextStyle(color: _muted)),
          ),
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(true),
            child: const Text(
              'Bloquear cuenta',
              style: TextStyle(
                color: Color(0xFFC23B3B),
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
        ],
      ),
    );
    if (ok != true || _isLoading) return;

    setState(() {
      _isLoading = true;
      _errorText = null;
    });
    try {
      final session = Supabase.instance.client.auth.currentSession;
      if (session != null) {
        ApiClient.setToken(session.accessToken);
        try {
          await ApiClient.post('/auth/age', {'confirmedUnder14': true});
        } catch (_) {}
      }
    } finally {
      await Supabase.instance.client.auth.signOut();
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _signOut() async {
    await Supabase.instance.client.auth.signOut();
  }

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, _) {
        if (didPop) return;
        _signOut();
      },
      child: Scaffold(
        backgroundColor: _bg,
        body: SafeArea(
          child: LayoutBuilder(
            builder: (context, constraints) {
              return SingleChildScrollView(
                padding: const EdgeInsets.symmetric(horizontal: 32),
                child: ConstrainedBox(
                  constraints: BoxConstraints(minHeight: constraints.maxHeight),
                  child: _banned ? _bannedBody() : _confirmBody(),
                ),
              );
            },
          ),
        ),
      ),
    );
  }

  Widget _confirmBody() {
    final canContinue = _confirmed && !_isLoading;

    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        const Text(
          'Confirm you\'re\n14 or older.',
          textAlign: TextAlign.center,
          style: TextStyle(
            fontSize: 32,
            fontWeight: FontWeight.w800,
            height: 1.12,
            letterSpacing: -0.6,
            color: _ink,
          ),
        ),
        const SizedBox(height: 12),
        const Text(
          'Si eres menor de 14 años no puedes entrar\ny tu cuenta será baneada.',
          textAlign: TextAlign.center,
          style: TextStyle(fontSize: 14, height: 1.4, color: _muted),
        ),
        const SizedBox(height: 36),
        Material(
          color: Colors.white,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(20),
            side: BorderSide(
              color: _confirmed ? _navy : _line,
              width: _confirmed ? 1.6 : 1,
            ),
          ),
          child: InkWell(
            onTap: _isLoading
                ? null
                : () => setState(() => _confirmed = !_confirmed),
            borderRadius: BorderRadius.circular(20),
            child: Padding(
              padding: const EdgeInsets.fromLTRB(16, 16, 18, 16),
              child: Row(
                children: [
                  AnimatedContainer(
                    duration: const Duration(milliseconds: 160),
                    width: 24,
                    height: 24,
                    decoration: BoxDecoration(
                      color: _confirmed ? _navy : Colors.white,
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(
                        color: _confirmed ? _navy : const Color(0xFFB8B8B8),
                        width: 1.4,
                      ),
                    ),
                    child: _confirmed
                        ? const Icon(Icons.check, size: 16, color: Colors.white)
                        : null,
                  ),
                  const SizedBox(width: 14),
                  const Expanded(
                    child: Text(
                      'Confirmo que tengo 14 años o más',
                      style: TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w600,
                        height: 1.3,
                        color: _ink,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
        if (_errorText != null) ...[
          const SizedBox(height: 10),
          Text(
            _errorText!,
            style: const TextStyle(color: Color(0xFFC23B3B), fontSize: 13),
          ),
        ],
        const SizedBox(height: 16),
        SizedBox(
          width: double.infinity,
          height: 50,
          child: ElevatedButton(
            onPressed: canContinue ? _onContinue : null,
            style: ElevatedButton.styleFrom(
              backgroundColor: _navy,
              foregroundColor: Colors.white,
              disabledBackgroundColor: _navy.withValues(alpha: 0.28),
              disabledForegroundColor: Colors.white.withValues(alpha: 0.85),
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
                : const Text(
                    'Continuar  →',
                    style: TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.w600,
                      letterSpacing: 0.1,
                    ),
                  ),
          ),
        ),
        const SizedBox(height: 28),
        GestureDetector(
          onTap: _isLoading ? null : _onUnderage,
          child: const Text(
            'Tengo menos de 14 años',
            style: TextStyle(
              fontSize: 14,
              color: _muted,
              decoration: TextDecoration.underline,
            ),
          ),
        ),
        const SizedBox(height: 12),
      ],
    );
  }

  Widget _bannedBody() {
    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        const Text(
          'Account\nblocked.',
          textAlign: TextAlign.center,
          style: TextStyle(
            fontSize: 32,
            fontWeight: FontWeight.w800,
            height: 1.12,
            letterSpacing: -0.6,
            color: _ink,
          ),
        ),
        const SizedBox(height: 14),
        const Text(
          'Esta cuenta está baneada porque se declaró\nmenor de 14 años. Numination no está\ndisponible para ti.',
          textAlign: TextAlign.center,
          style: TextStyle(fontSize: 14, height: 1.45, color: _muted),
        ),
        const SizedBox(height: 36),
        SizedBox(
          width: double.infinity,
          height: 50,
          child: ElevatedButton(
            onPressed: _signOut,
            style: ElevatedButton.styleFrom(
              backgroundColor: _navy,
              foregroundColor: Colors.white,
              elevation: 0,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(28),
              ),
            ),
            child: const Text(
              'Salir',
              style: TextStyle(fontSize: 15, fontWeight: FontWeight.w600),
            ),
          ),
        ),
      ],
    );
  }
}
