import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../core/auth_controller.dart';
import '../../core/env.dart';
import '../../core/error_messages.dart';
import '../widgets/numi_loading_animation.dart';
import 'confirm_age_screen.dart';
import 'create_acc.dart';
import 'home_screen.dart';

class AuthScreen extends ConsumerStatefulWidget {
  const AuthScreen({super.key});

  @override
  ConsumerState<AuthScreen> createState() => _AuthScreenState();
}

class _AuthScreenState extends ConsumerState<AuthScreen> {
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  final _emailFocus = FocusNode();
  final _passwordFocus = FocusNode();

  bool _passwordStep = false;
  bool _isLoading = false;
  bool _showPassword = false;
  bool _isSendingReset = false;
  String? _errorText;
  String? _successText;

  static const _ink = Color(0xFF101116);
  static const _navy = Color(0xFF1E2A4B);
  static const _muted = Color(0xFF7C8094);
  static const _line = Color(0xFFE2E4EE);
  static const _leftBg = Color(0xFFF7F4FD);

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    _emailFocus.dispose();
    _passwordFocus.dispose();
    super.dispose();
  }

  bool _isValidEmail(String email) =>
      RegExp(r'^[^\s@]+@[^\s@]+\.[^\s@]{2,}$').hasMatch(email.trim());

  void _continueWithEmail() {
    final email = _emailController.text.trim();
    if (!_isValidEmail(email)) {
      setState(() {
        _errorText = 'Ingresa un correo electrónico válido.';
        _successText = null;
      });
      return;
    }

    setState(() {
      _passwordStep = true;
      _errorText = null;
      _successText = null;
    });
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) _passwordFocus.requestFocus();
    });
  }

  void _useAnotherEmail() {
    setState(() {
      _passwordStep = false;
      _passwordController.clear();
      _errorText = null;
      _successText = null;
      _showPassword = false;
    });
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) _emailFocus.requestFocus();
    });
  }

  Future<void> _signInWithPassword() async {
    final email = _emailController.text.trim();
    final password = _passwordController.text;

    if (!_isValidEmail(email)) {
      setState(() => _errorText = 'Ingresa un correo electrónico válido.');
      return;
    }
    if (password.isEmpty) {
      setState(() => _errorText = 'Ingresa tu contraseña.');
      return;
    }

    setState(() {
      _isLoading = true;
      _errorText = null;
      _successText = null;
    });

    try {
      final client = Supabase.instance.client;
      await client.auth.signInWithPassword(email: email, password: password);

      if (client.auth.currentUser == null) {
        throw const AuthException('No se pudo crear la sesión.');
      }

      await ref.read(authControllerProvider.notifier).refresh();
      if (!mounted) return;

      final authState = ref.read(authControllerProvider);
      final isVerified =
          authState is AuthAuthenticated &&
          authState.ageConfirmed &&
          !authState.bannedUnderage;

      Navigator.of(context, rootNavigator: true).pushAndRemoveUntil(
        MaterialPageRoute<void>(
          builder: (_) =>
              isVerified ? const HomeScreen() : const ConfirmAgeScreen(),
        ),
        (route) => false,
      );
    } on AuthException catch (error) {
      if (!mounted) return;
      final message = error.message.toLowerCase();
      setState(() {
        if (message.contains('invalid login credentials') ||
            message.contains('invalid_credentials') ||
            message.contains('invalid email or password')) {
          _errorText = 'El correo o la contraseña no son correctos.';
        } else if (message.contains('email not confirmed') ||
            message.contains('email_not_confirmed')) {
          _errorText = 'Primero confirma tu correo electrónico.';
        } else {
          _errorText = AppErrorMessages.fromAuthError(error.message);
        }
      });
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _errorText = AppErrorMessages.fromAuthError(error.toString());
      });
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _sendPasswordReset() async {
    if (_isLoading || _isSendingReset) return;
    final email = _emailController.text.trim();
    if (!_isValidEmail(email)) {
      setState(() => _errorText = 'Ingresa un correo válido primero.');
      return;
    }

    setState(() {
      _isSendingReset = true;
      _errorText = null;
      _successText = null;
    });
    try {
      await Supabase.instance.client.auth.resetPasswordForEmail(
        email,
        redirectTo: '${Env.authRedirectUrl}?flow=recovery',
      );
      if (!mounted) return;
      setState(() {
        _successText =
            'Te enviamos un enlace para restablecer la contraseña. Revisa tu correo.';
      });
    } on AuthException catch (error) {
      if (!mounted) return;
      setState(
        () => _errorText = AppErrorMessages.fromAuthError(error.message),
      );
    } catch (_) {
      if (!mounted) return;
      setState(
        () => _errorText = 'No se pudo enviar el enlace de recuperación.',
      );
    } finally {
      if (mounted) setState(() => _isSendingReset = false);
    }
  }

  Future<void> _onGoogleSignIn() async {
    if (_isLoading) return;
    setState(() {
      _isLoading = true;
      _errorText = null;
      _successText = null;
    });

    try {
      final usesSupabaseOAuth =
          kIsWeb ||
          defaultTargetPlatform == TargetPlatform.android ||
          defaultTargetPlatform == TargetPlatform.linux ||
          defaultTargetPlatform == TargetPlatform.windows;

      if (usesSupabaseOAuth) {
        final launched = await Supabase.instance.client.auth.signInWithOAuth(
          OAuthProvider.google,
          redirectTo: kIsWeb ? null : Env.authRedirectUrl,
          authScreenLaunchMode: defaultTargetPlatform == TargetPlatform.android
              ? LaunchMode.externalApplication
              : LaunchMode.platformDefault,
        );
        if (!launched) {
          throw StateError('No se pudo abrir la autenticación de Google.');
        }
        return;
      }

      if (Env.googleClientId.trim().isEmpty) {
        throw StateError(
          'Falta SUPABASE_AUTH_GOOGLE_CLIENT_ID en .env. Debe ser el Client ID web de Google.',
        );
      }

      final googleSignIn = GoogleSignIn.instance;
      await googleSignIn.signOut();
      final googleUser = await googleSignIn.authenticate();
      final idToken = googleUser.authentication.idToken;
      if (idToken == null || idToken.isEmpty) {
        throw StateError('Google no devolvió un ID token.');
      }

      final authorization = await googleUser.authorizationClient
          .authorizeScopes(const <String>['email', 'profile']);
      if (authorization.accessToken.isEmpty) {
        throw StateError('Google no devolvió un access token.');
      }

      final response = await Supabase.instance.client.auth.signInWithIdToken(
        provider: OAuthProvider.google,
        idToken: idToken,
        accessToken: authorization.accessToken,
      );
      final user = response.user ?? Supabase.instance.client.auth.currentUser;
      if (user == null) {
        throw StateError('Google autenticó, pero no se creó la sesión.');
      }

      if (!mounted) return;
      await ref.read(authControllerProvider.notifier).refresh();
    } on GoogleSignInException catch (error) {
      if (!mounted) return;

      final description = error.description?.trim();

      debugPrint(
        '[GOOGLE_AUTH] ${error.code}: '
        '${description == null || description.isEmpty ? "sin descripción" : description}',
      );

      if (error.code == GoogleSignInExceptionCode.canceled) return;

      setState(() {
        _errorText = AppErrorMessages.fromAuthError(
          description ?? error.toString(),
          fallback: AppErrorMessages.googleSignInFailed,
        );
      });
    } on AuthException catch (error) {
      if (!mounted) return;
      setState(
        () => _errorText = AppErrorMessages.fromAuthError(error.message),
      );
    } catch (error) {
      if (!mounted) return;
      setState(
        () => _errorText = AppErrorMessages.fromAuthError(error.toString()),
      );
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _onGithubSignIn() async {
    if (_isLoading) return;
    setState(() {
      _isLoading = true;
      _errorText = null;
      _successText = null;
    });
    try {
      await Supabase.instance.client.auth.signInWithOAuth(
        OAuthProvider.github,
        redirectTo: Env.authRedirectUrl,
      );
    } on AuthException catch (error) {
      if (!mounted) return;
      setState(
        () => _errorText = AppErrorMessages.fromAuthError(error.message),
      );
    } catch (_) {
      if (!mounted) return;
      setState(() => _errorText = AppErrorMessages.githubSignInFailed);
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Widget _field({
    required TextEditingController controller,
    required FocusNode focusNode,
    required String hint,
    required IconData icon,
    required TextInputAction action,
    TextInputType? keyboardType,
    bool obscure = false,
    Widget? suffix,
    ValueChanged<String>? onSubmitted,
  }) {
    return SizedBox(
      height: 62,
      child: TextField(
        controller: controller,
        focusNode: focusNode,
        enabled: !_isLoading,
        obscureText: obscure,
        keyboardType: keyboardType,
        textInputAction: action,
        autocorrect: false,
        enableSuggestions: !obscure,
        onSubmitted: onSubmitted,
        cursorColor: _navy,
        style: const TextStyle(
          color: Color(0xFF14151A),
          fontSize: 15.5,
          fontWeight: FontWeight.w500,
        ),
        decoration: InputDecoration(
          hintText: hint,
          hintStyle: const TextStyle(
            color: Color(0xFF8B8FA3),
            fontSize: 15.5,
            fontWeight: FontWeight.w500,
          ),
          prefixIcon: Padding(
            padding: const EdgeInsets.only(left: 20, right: 13),
            child: Icon(icon, size: 21, color: const Color(0xFF1F2A4A)),
          ),
          prefixIconConstraints: const BoxConstraints(minWidth: 58),
          suffixIcon: suffix,
          filled: true,
          fillColor: Colors.white,
          contentPadding: const EdgeInsets.symmetric(
            horizontal: 18,
            vertical: 18,
          ),
          enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(40),
            borderSide: const BorderSide(color: _line),
          ),
          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(40),
            borderSide: const BorderSide(color: _navy, width: 1.2),
          ),
          disabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(40),
            borderSide: const BorderSide(color: _line),
          ),
        ),
      ),
    );
  }

  Widget _buildForm({required bool desktop}) {
    return Center(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 492),
        child: SingleChildScrollView(
          padding: EdgeInsets.symmetric(
            horizontal: desktop ? 26 : 20,
            vertical: desktop ? 28 : 24,
          ),
          child: Container(
            width: double.infinity,
            padding: EdgeInsets.fromLTRB(
              desktop ? 40 : 25,
              desktop ? 46 : 34,
              desktop ? 40 : 25,
              desktop ? 42 : 30,
            ),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(30),
              border: Border.all(color: const Color(0xFFF4F0FD)),
              boxShadow: desktop
                  ? const [
                      BoxShadow(
                        color: Color(0x335440A0),
                        blurRadius: 62,
                        offset: Offset(0, 25),
                      ),
                    ]
                  : const [],
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  'Welcome back',
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                    color: _ink,
                    fontSize: 31,
                    fontWeight: FontWeight.w800,
                    letterSpacing: -1.1,
                  ),
                ),
                const SizedBox(height: 9),
                Text(
                  'Sign in to continue to Numination',
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                    color: _muted,
                    fontSize: 15.5,
                    fontWeight: FontWeight.w500,
                  ),
                ),
                const SizedBox(height: 34),
                if (!_passwordStep)
                  _field(
                    controller: _emailController,
                    focusNode: _emailFocus,
                    hint: 'Correo electrónico',
                    icon: Icons.mail_outline_rounded,
                    keyboardType: TextInputType.emailAddress,
                    action: TextInputAction.continueAction,
                    onSubmitted: (_) => _continueWithEmail(),
                  )
                else ...[
                  _field(
                    controller: _passwordController,
                    focusNode: _passwordFocus,
                    hint: 'Contraseña',
                    icon: Icons.lock_outline_rounded,
                    obscure: !_showPassword,
                    action: TextInputAction.done,
                    onSubmitted: (_) => _signInWithPassword(),
                    suffix: IconButton(
                      tooltip: _showPassword
                          ? 'Ocultar contraseña'
                          : 'Mostrar contraseña',
                      onPressed: () =>
                          setState(() => _showPassword = !_showPassword),
                      icon: Icon(
                        _showPassword
                            ? Icons.visibility_off_outlined
                            : Icons.visibility_outlined,
                        color: const Color(0xFF8B8FA3),
                      ),
                    ),
                  ),
                  Align(
                    alignment: Alignment.centerLeft,
                    child: TextButton.icon(
                      onPressed: _isLoading ? null : _useAnotherEmail,
                      style: TextButton.styleFrom(
                        foregroundColor: const Color(0xFF85899C),
                        padding: const EdgeInsets.only(top: 8, left: 2),
                        visualDensity: VisualDensity.compact,
                      ),
                      icon: const Icon(Icons.arrow_back_rounded, size: 15),
                      label: const Text(
                        'Usar otro correo',
                        style: TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  ),
                ],
                if (_errorText != null) ...[
                  const SizedBox(height: 10),
                  Text(
                    _errorText!,
                    textAlign: TextAlign.center,
                    style: const TextStyle(
                      color: Color(0xFFCE3434),
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
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
                const SizedBox(height: 22),
                SizedBox(
                  height: 62,
                  width: double.infinity,
                  child: ElevatedButton(
                    onPressed: _isLoading
                        ? null
                        : (_passwordStep
                              ? _signInWithPassword
                              : _continueWithEmail),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: _navy,
                      foregroundColor: Colors.white,
                      disabledBackgroundColor: _navy.withValues(alpha: 0.72),
                      elevation: 0,
                      shape: const StadiumBorder(),
                    ),
                    child: _isLoading
                        ? const SizedBox(
                            width: 22,
                            height: 22,
                            child: NumiLoadingAnimation(),
                          )
                        : Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: const [
                              Text(
                                'Continuar',
                                style: TextStyle(
                                  fontSize: 16,
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                              SizedBox(width: 10),
                              Icon(Icons.arrow_forward_rounded, size: 20),
                            ],
                          ),
                  ),
                ),
                if (_passwordStep) ...[
                  const SizedBox(height: 7),
                  TextButton(
                    onPressed: _isLoading || _isSendingReset
                        ? null
                        : _sendPasswordReset,
                    child: Text(
                      _isSendingReset
                          ? 'Enviando enlace...'
                          : '¿Olvidaste tu contraseña?',
                      style: const TextStyle(
                        color: _muted,
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ],
                const SizedBox(height: 32),
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    _socialButton(
                      asset: 'assets/images/google.png',
                      label: 'Continuar con Google',
                      onPressed: _onGoogleSignIn,
                    ),
                    const SizedBox(width: 14),
                    _socialButton(
                      asset: 'assets/images/github.png',
                      label: 'Continuar con GitHub',
                      onPressed: _onGithubSignIn,
                      dark: true,
                    ),
                  ],
                ),
                const SizedBox(height: 30),
                Wrap(
                  alignment: WrapAlignment.center,
                  children: [
                    const Text(
                      "Don't have an account? ",
                      style: TextStyle(color: Color(0xFF6F7387), fontSize: 14),
                    ),
                    GestureDetector(
                      onTap: _isLoading
                          ? null
                          : () => Navigator.of(context).push(
                              MaterialPageRoute<void>(
                                builder: (_) => const CreateAccountScreen(),
                              ),
                            ),
                      child: const Text(
                        'Sign up',
                        style: TextStyle(
                          color: _ink,
                          fontSize: 14,
                          fontWeight: FontWeight.w800,
                          decoration: TextDecoration.underline,
                          decorationThickness: 1.4,
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _socialButton({
    required String asset,
    required String label,
    required VoidCallback onPressed,
    bool dark = false,
  }) {
    return Tooltip(
      message: label,
      child: SizedBox(
        width: 64,
        height: 64,
        child: OutlinedButton(
          onPressed: _isLoading ? null : onPressed,
          style: OutlinedButton.styleFrom(
            backgroundColor: Colors.white,
            foregroundColor: dark ? const Color(0xFF0B0D12) : _ink,
            side: const BorderSide(color: Color(0xFFE4E6EF)),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(19),
            ),
            padding: const EdgeInsets.all(15),
          ),
          child: Image.asset(asset, fit: BoxFit.contain),
        ),
      ),
    );
  }

  Widget _buildHeroPanel() {
    return LayoutBuilder(
      builder: (context, constraints) {
        final width = constraints.maxWidth;
        final height = constraints.maxHeight;

        return Container(
          decoration: const BoxDecoration(
            gradient: RadialGradient(
              center: Alignment(-0.78, -0.9),
              radius: 1.65,
              colors: [Color(0xFFFCFAFF), Color(0xFFF8F4FF), Color(0xFFE6DCFF)],
              stops: [0, 0.52, 1],
            ),
          ),
          child: ClipRect(
            child: Stack(
              children: [
                Positioned(
                  right: -120,
                  top: -135,
                  child: _circle(420, Colors.white.withValues(alpha: 0.22)),
                ),
                Positioned(
                  right: -75,
                  top: 24,
                  child: Container(
                    width: 380,
                    height: 380,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      border: Border.all(
                        color: Colors.white.withValues(alpha: 0.55),
                      ),
                    ),
                  ),
                ),
                Positioned(
                  left: -190,
                  bottom: -250,
                  child: _circle(
                    630,
                    const Color(0xFF9276FF).withValues(alpha: 0.32),
                  ),
                ),

                // Logotipo construido mediante CustomPainter.
                Positioned(
                  left: 60,
                  top: 34,
                  child: Row(
                    children: [
                      const _NuminationMark(size: 40),
                      const SizedBox(width: 11),
                      const Text(
                        'Numination.',
                        style: TextStyle(
                          color: Color(0xFF101116),
                          fontSize: 26,
                          fontWeight: FontWeight.w800,
                          letterSpacing: -0.8,
                        ),
                      ),
                    ],
                  ),
                ),

                // Título.
                Positioned(
                  left: 86,
                  top: height * 0.235,
                  right: 15,
                  child: RichText(
                    text: const TextSpan(
                      children: [
                        TextSpan(
                          text: 'Welcome to\n',
                          style: TextStyle(color: Color(0xFF101116)),
                        ),
                        TextSpan(
                          text: 'Numination.',
                          style: TextStyle(color: Color(0xFF39318F)),
                        ),
                      ],
                      style: TextStyle(
                        fontSize: 60,
                        height: 1.02,
                        fontWeight: FontWeight.w800,
                        letterSpacing: -2.5,
                      ),
                    ),
                  ),
                ),

                // Subtítulo.
                Positioned(
                  left: 86,
                  top: height * 0.485,
                  right: 20,
                  child: const Text(
                    'Your ideas. Your intelligence.\nYour possibilities.',
                    style: TextStyle(
                      color: Color(0xFF5B5E78),
                      fontSize: 19,
                      height: 1.5,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ),

                // ROBOT: 100 % Flutter, sin ghost.png.
                Positioned(
                  right: -5,
                  bottom: -62,
                  width: width * 0.44,
                  height: height * 0.92,
                  child: const _NumiRobot(),
                ),

                // Tarjeta flotante superior.
                Positioned(
                  right: 30,
                  top: height * 0.19,
                  child: _glassCard(
                    width: 180,
                    angle: 0.11,
                    child: const Row(
                      children: [
                        Icon(
                          Icons.auto_awesome_rounded,
                          color: Color(0xFF8F74F7),
                          size: 35,
                        ),
                        SizedBox(width: 13),
                        Expanded(
                          child: Column(
                            children: [
                              _SkeletonLine(widthFactor: 1),
                              SizedBox(height: 8),
                              _SkeletonLine(widthFactor: 0.68),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                ),

                // Tarjeta flotante de código.
                Positioned(
                  left: width * 0.23,
                  bottom: height * 0.23,
                  child: _glassCard(
                    width: 150,
                    angle: -0.14,
                    child: const Icon(
                      Icons.code_rounded,
                      color: Color(0xFF8B74F8),
                      size: 38,
                    ),
                  ),
                ),

                // Etiqueta inferior.
                Positioned(
                  left: 36,
                  bottom: 23,
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 23,
                      vertical: 18,
                    ),
                    decoration: BoxDecoration(
                      color: const Color(0xE6232B53),
                      borderRadius: BorderRadius.circular(21),
                      border: Border.all(
                        color: Colors.white.withValues(alpha: 0.16),
                      ),
                      boxShadow: const [
                        BoxShadow(
                          color: Color(0x55221B52),
                          blurRadius: 36,
                          offset: Offset(0, 15),
                        ),
                      ],
                    ),
                    child: const Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(Icons.bolt_rounded, color: Colors.white, size: 27),
                        SizedBox(width: 13),
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'AI without limits.',
                              style: TextStyle(
                                color: Colors.white,
                                fontSize: 17,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                            SizedBox(height: 3),
                            Text(
                              'Create. Think. Build.',
                              style: TextStyle(
                                color: Color(0xD9FFFFFF),
                                fontSize: 13,
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _circle(double size, Color color) => Container(
    width: size,
    height: size,
    decoration: BoxDecoration(shape: BoxShape.circle, color: color),
  );

  Widget _glassCard({
    required double width,
    required double angle,
    required Widget child,
  }) {
    return Transform.rotate(
      angle: angle,
      child: Container(
        width: width,
        padding: const EdgeInsets.symmetric(horizontal: 17, vertical: 23),
        decoration: BoxDecoration(
          color: Colors.white.withValues(alpha: 0.48),
          borderRadius: BorderRadius.circular(23),
          border: Border.all(color: Colors.white.withValues(alpha: 0.78)),
          boxShadow: const [
            BoxShadow(
              color: Color(0x334C37A8),
              blurRadius: 35,
              offset: Offset(0, 13),
            ),
          ],
        ),
        child: child,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      body: LayoutBuilder(
        builder: (context, constraints) {
          final desktop =
              constraints.maxWidth >= 960 && constraints.maxHeight >= 560;
          if (!desktop) {
            return SafeArea(
              child: Container(
                width: double.infinity,
                color: Colors.white,
                child: _buildForm(desktop: false),
              ),
            );
          }

          return SafeArea(
            child: Row(
              children: [
                Expanded(
                  flex: 9,
                  child: Container(
                    color: _leftBg,
                    child: _buildForm(desktop: true),
                  ),
                ),
                Expanded(flex: 11, child: _buildHeroPanel()),
              ],
            ),
          );
        },
      ),
    );
  }
}

class _NumiRobot extends StatelessWidget {
  const _NumiRobot();

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final w = constraints.maxWidth;
        final h = constraints.maxHeight;
        final headHeight = h * 0.47;

        return Stack(
          clipBehavior: Clip.none,
          children: [
            // Cuerpo y laterales oscuros.
            Positioned(
              left: w * 0.05,
              right: w * 0.05,
              bottom: -h * 0.06,
              height: h * 0.49,
              child: Stack(
                children: [
                  Positioned(
                    left: 0,
                    bottom: 0,
                    width: w * 0.25,
                    height: h * 0.43,
                    child: Transform.rotate(
                      angle: -0.13,
                      child: Container(
                        decoration: BoxDecoration(
                          color: const Color(0xFF202031),
                          borderRadius: BorderRadius.circular(65),
                        ),
                      ),
                    ),
                  ),
                  Positioned(
                    right: 0,
                    bottom: 0,
                    width: w * 0.25,
                    height: h * 0.43,
                    child: Transform.rotate(
                      angle: 0.13,
                      child: Container(
                        decoration: BoxDecoration(
                          color: const Color(0xFF202031),
                          borderRadius: BorderRadius.circular(65),
                        ),
                      ),
                    ),
                  ),
                  Positioned(
                    left: w * 0.12,
                    right: w * 0.12,
                    top: 0,
                    bottom: 0,
                    child: Container(
                      decoration: const BoxDecoration(
                        gradient: LinearGradient(
                          begin: Alignment.topCenter,
                          end: Alignment.bottomCenter,
                          colors: [Color(0xFFFFFFFF), Color(0xFFF3EEFF)],
                        ),
                        borderRadius: BorderRadius.vertical(
                          top: Radius.circular(105),
                        ),
                      ),
                    ),
                  ),
                  Positioned(
                    left: w * 0.33,
                    right: w * 0.33,
                    top: h * 0.035,
                    height: h * 0.22,
                    child: Container(
                      decoration: BoxDecoration(
                        color: const Color(0xFFF7F3FF),
                        borderRadius: BorderRadius.circular(29),
                      ),
                      child: const Center(child: _NuminationMark(size: 40)),
                    ),
                  ),
                ],
              ),
            ),

            // Cuello.
            Positioned(
              left: w * 0.40,
              top: headHeight * 0.78,
              width: w * 0.20,
              height: h * 0.17,
              child: Container(
                decoration: BoxDecoration(
                  color: const Color(0xFF28263E),
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
            ),
            Positioned(
              left: w * 0.36,
              top: headHeight * 0.91,
              width: w * 0.28,
              height: h * 0.07,
              child: Container(
                decoration: BoxDecoration(
                  color: const Color(0xFFEAE4FF),
                  borderRadius: BorderRadius.circular(30),
                ),
              ),
            ),

            // Orejas violetas.
            Positioned(
              left: 0,
              top: headHeight * 0.30,
              width: w * 0.23,
              height: headHeight * 0.46,
              child: Container(
                decoration: BoxDecoration(
                  gradient: const LinearGradient(
                    colors: [Color(0xFF7654F7), Color(0xFFB08AFF)],
                  ),
                  borderRadius: BorderRadius.circular(38),
                  boxShadow: const [
                    BoxShadow(color: Color(0x667E56FF), blurRadius: 20),
                  ],
                ),
              ),
            ),
            Positioned(
              right: 0,
              top: headHeight * 0.30,
              width: w * 0.23,
              height: headHeight * 0.46,
              child: Container(
                decoration: BoxDecoration(
                  gradient: const LinearGradient(
                    colors: [Color(0xFFB08AFF), Color(0xFF7654F7)],
                  ),
                  borderRadius: BorderRadius.circular(38),
                  boxShadow: const [
                    BoxShadow(color: Color(0x667E56FF), blurRadius: 20),
                  ],
                ),
              ),
            ),

            // Cabeza blanca.
            Positioned(
              left: w * 0.07,
              right: w * 0.07,
              top: 0,
              height: headHeight,
              child: Container(
                decoration: BoxDecoration(
                  gradient: const LinearGradient(
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    colors: [Colors.white, Color(0xFFF0EAFF)],
                  ),
                  borderRadius: BorderRadius.circular(100),
                  border: Border.all(color: Colors.white, width: 4),
                  boxShadow: const [
                    BoxShadow(
                      color: Color(0x447E60DC),
                      blurRadius: 35,
                      offset: Offset(0, 18),
                    ),
                  ],
                ),
                child: Stack(
                  children: [
                    // Visor negro.
                    Positioned(
                      left: w * 0.055,
                      right: w * 0.055,
                      top: headHeight * 0.15,
                      bottom: headHeight * 0.14,
                      child: Container(
                        decoration: BoxDecoration(
                          gradient: const LinearGradient(
                            begin: Alignment.topLeft,
                            end: Alignment.bottomRight,
                            colors: [Color(0xFF29283D), Color(0xFF090916)],
                          ),
                          borderRadius: BorderRadius.circular(100),
                          boxShadow: const [
                            BoxShadow(color: Color(0x55302A59), blurRadius: 15),
                          ],
                        ),
                      ),
                    ),

                    // Ojo izquierdo.
                    Positioned(
                      left: w * 0.22,
                      top: headHeight * 0.53,
                      width: w * 0.15,
                      height: headHeight * 0.12,
                      child: const CustomPaint(painter: _RobotEyePainter()),
                    ),

                    // Ojo derecho.
                    Positioned(
                      right: w * 0.22,
                      top: headHeight * 0.53,
                      width: w * 0.15,
                      height: headHeight * 0.12,
                      child: const CustomPaint(painter: _RobotEyePainter()),
                    ),
                  ],
                ),
              ),
            ),
          ],
        );
      },
    );
  }
}

class _RobotEyePainter extends CustomPainter {
  const _RobotEyePainter();

  @override
  void paint(Canvas canvas, Size size) {
    final path = Path()
      ..moveTo(size.width * 0.08, size.height * 0.82)
      ..quadraticBezierTo(
        size.width * 0.50,
        -size.height * 0.12,
        size.width * 0.92,
        size.height * 0.82,
      );

    final glow = Paint()
      ..color = const Color(0xFF9362FF)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 17
      ..strokeCap = StrokeCap.round
      ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 7);

    canvas.drawPath(path, glow);

    final stroke = Paint()
      ..color = const Color(0xFFAA82FF)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 8
      ..strokeCap = StrokeCap.round;

    canvas.drawPath(path, stroke);
  }

  @override
  bool shouldRepaint(covariant _RobotEyePainter oldDelegate) => false;
}

class _NuminationMark extends StatelessWidget {
  const _NuminationMark({required this.size});

  final double size;

  @override
  Widget build(BuildContext context) {
    return CustomPaint(
      size: Size.square(size),
      painter: _NuminationMarkPainter(),
    );
  }
}

class _NuminationMarkPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    canvas.save();
    canvas.scale(size.width / 40, size.height / 40);

    final navy = Paint()
      ..color = const Color(0xFF202744)
      ..style = PaintingStyle.fill;

    final violet = Paint()
      ..shader = const LinearGradient(
        colors: [Color(0xFF4438CE), Color(0xFF8060FF)],
      ).createShader(const Rect.fromLTWH(0, 0, 40, 40));

    final left = Path()
      ..moveTo(3, 7)
      ..quadraticBezierTo(3, 1, 9, 1)
      ..quadraticBezierTo(12, 1, 15, 5)
      ..lineTo(35, 23)
      ..lineTo(35, 33)
      ..quadraticBezierTo(35, 39, 29, 39)
      ..lineTo(7, 20)
      ..lineTo(7, 10)
      ..close();

    final right = Path()
      ..moveTo(35, 7)
      ..lineTo(35, 29)
      ..quadraticBezierTo(35, 37, 28, 37)
      ..lineTo(19, 29)
      ..lineTo(27, 22)
      ..lineTo(29, 24)
      ..lineTo(29, 8)
      ..close();

    canvas.drawPath(left, navy);
    canvas.drawPath(right, violet);
    canvas.drawCircle(
      const Offset(32, 5),
      3,
      Paint()..color = const Color(0xFF8060FF),
    );

    canvas.restore();
  }

  @override
  bool shouldRepaint(covariant _NuminationMarkPainter oldDelegate) => false;
}

class _SkeletonLine extends StatelessWidget {
  const _SkeletonLine({required this.widthFactor});
  final double widthFactor;

  @override
  Widget build(BuildContext context) {
    return Align(
      alignment: Alignment.centerLeft,
      child: FractionallySizedBox(
        widthFactor: widthFactor,
        child: Container(
          height: 7,
          decoration: BoxDecoration(
            color: const Color(0x337A60E8),
            borderRadius: BorderRadius.circular(20),
          ),
        ),
      ),
    );
  }
}
