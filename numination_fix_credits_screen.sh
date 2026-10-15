#!/usr/bin/env bash
set -euo pipefail
APP="$HOME/Proyectos/Numination"
if [[ ! -f "$APP/lib/features/widgets/hamburger.dart" ]]; then
  echo "No encuentro $APP/lib/features/widgets/hamburger.dart" >&2
  exit 1
fi
cd "$APP"
python3 - <<'PY'
from pathlib import Path
from datetime import datetime
import shutil
import sys

root = Path.home() / "Proyectos" / "Numination"
hamburger = root / "lib/features/widgets/hamburger.dart"
screen = root / "lib/features/screens/credits_hub_screen.dart"
button = root / "lib/features/widgets/galaxy_button.dart"

source = hamburger.read_text()
if "CreditsHubScreen" in source or "credits_hub_screen.dart" in source:
    raise SystemExit("El acceso a Créditos parece existir ya en hamburger.dart. No se hicieron cambios para evitar duplicarlo.")

anchor = '''              _DrawerItem(
                icon: NumiIcons.notifications_outlined,
                label: context.l10n.notifications,
                color: palette.textPrimary,
                onTap: () {
                  Navigator.of(context).pop();
                  Navigator.of(context).push(
                    MaterialPageRoute(
                      builder: (_) => const NotificationScreen(),
                    ),
                  );
                },
              ),
              const SizedBox(height: 16),
              Divider(color: palette.border),'''
if source.count(anchor) != 1:
    raise SystemExit("No coincide el bloque de Notificaciones en hamburger.dart. No se escribió ningún cambio.")
if screen.exists():
    raise SystemExit(f"Ya existe {screen}; no la sobrescribo. Inspecciona ese archivo antes de volver a ejecutar.")

stamp = datetime.now().strftime("%Y%m%d-%H%M%S-%f")
backup_dir = Path("/tmp") / f"numination-credits-ui-backup-{stamp}"
backup_dir.mkdir(parents=True, exist_ok=False)
shutil.copy2(hamburger, backup_dir / "hamburger.dart")
if button.exists():
    shutil.copy2(button, backup_dir / "galaxy_button.dart")

# Add imports only after all patch preconditions have passed.
if "import '../screens/credits_hub_screen.dart';" not in source:
    source = source.replace(
        "import '../screens/connectors_screen.dart';\n",
        "import '../screens/connectors_screen.dart';\nimport '../screens/credits_hub_screen.dart';\n",
        1,
    )
if "import '../../core/error_messages.dart';" not in source:
    source = source.replace(
        "import '../../core/api.dart';\n",
        "import '../../core/api.dart';\nimport '../../core/error_messages.dart';\n",
        1,
    )
if "package:lucide_flutter/lucide_flutter.dart" not in source:
    source = source.replace(
        "import 'package:flutter/material.dart';\n",
        "import 'package:flutter/material.dart';\nimport 'package:lucide_flutter/lucide_flutter.dart';\n",
        1,
    )

replacement = '''              _DrawerItem(
                icon: NumiIcons.notifications_outlined,
                label: context.l10n.notifications,
                color: palette.textPrimary,
                onTap: () {
                  Navigator.of(context).pop();
                  Navigator.of(context).push(
                    MaterialPageRoute(
                      builder: (_) => const NotificationScreen(),
                    ),
                  );
                },
              ),
              const SizedBox(height: 18),
              _DrawerItem(
                icon: LucideIcons.creditCard,
                label: AppErrorMessages.isEnglish ? 'Credits' : 'Créditos',
                color: palette.textPrimary,
                trailing: _creditsLoading
                    ? SizedBox(
                        width: 15,
                        height: 15,
                        child: CircularProgressIndicator(
                          strokeWidth: 1.6,
                          color: palette.accent,
                        ),
                      )
                    : _creditBalance == null
                    ? null
                    : Text(
                        _formatCreditBalance(_creditBalance!),
                        style: TextStyle(
                          color: palette.accent,
                          fontSize: 14,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                onTap: () {
                  final navigator = Navigator.of(context);
                  navigator.pop();
                  navigator.push(
                    MaterialPageRoute(
                      builder: (_) => const CreditsHubScreen(),
                    ),
                  );
                },
              ),
              const SizedBox(height: 16),
              Divider(color: palette.border),'''
source = source.replace(anchor, replacement, 1)

# Load the authenticated server balance for the drawer badge.
state_old = '''class _AppDrawerState extends ConsumerState<AppDrawer> {
  bool _isLoading = true;
  List<ChatSession> _chats = [];
  String? _resolvedAvatarUrl;

  @override
  void initState() {
    super.initState();
    _resolvedAvatarUrl = widget.avatarUrl;
    _loadProfile();
    _loadChats();
  }
'''
state_new = '''class _AppDrawerState extends ConsumerState<AppDrawer> {
  bool _isLoading = true;
  List<ChatSession> _chats = [];
  String? _resolvedAvatarUrl;
  int? _creditBalance;
  bool _creditsLoading = true;

  @override
  void initState() {
    super.initState();
    _resolvedAvatarUrl = widget.avatarUrl;
    _loadProfile();
    _loadChats();
    _loadCredits();
  }

  Future<void> _loadCredits() async {
    try {
      final response = await ApiClient.get('/credits');
      final data = ApiClient.decode(response);
      final raw = data is Map ? data['balance'] : null;
      if (raw is! num || !raw.isFinite || raw < 0) {
        throw const FormatException('Invalid credits balance');
      }
      if (!mounted) return;
      setState(() {
        _creditBalance = raw.toInt();
        _creditsLoading = false;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _creditBalance = null;
        _creditsLoading = false;
      });
    }
  }

  String _formatCreditBalance(int value) {
    final separator = AppErrorMessages.isEnglish ? ',' : '.';
    return value.toString().replaceAllMapped(
      RegExp(r'\\B(?=(\\d{3})+(?!\\d))'),
      (_) => separator,
    );
  }
'''
if source.count(state_old) != 1:
    sys.exit("ERROR: no se encontró el estado del drawer para cargar créditos; no se escribió ningún archivo.")
source = source.replace(state_old, state_new, 1)

item_class_old = '''class _DrawerItem extends StatelessWidget {
  const _DrawerItem({
    required this.icon,
    required this.label,
    required this.color,
    required this.onTap,
  });
  final IconData icon;
  final String label;
  final Color color;
  final VoidCallback onTap;
'''
item_class_new = '''class _DrawerItem extends StatelessWidget {
  const _DrawerItem({
    required this.icon,
    required this.label,
    required this.color,
    required this.onTap,
    this.trailing,
  });
  final IconData icon;
  final String label;
  final Color color;
  final VoidCallback onTap;
  final Widget? trailing;
'''
if source.count(item_class_old) != 1:
    sys.exit("ERROR: no se encontró el componente _DrawerItem esperado; no se escribió ningún archivo.")
source = source.replace(item_class_old, item_class_new, 1)
label_old = "          Text(label, style: TextStyle(color: color, fontSize: 17)),\n        ],"
label_new = "          Text(label, style: TextStyle(color: color, fontSize: 17)),\n          if (trailing != null) ...[\n            const Spacer(),\n            trailing!,\n          ],\n        ],"
if source.count(label_old) != 1:
    sys.exit("ERROR: no se encontró el texto de _DrawerItem esperado; no se escribió ningún archivo.")
source = source.replace(label_old, label_new, 1)

screen_text = r'''import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../core/api.dart';
import '../../core/env.dart';
import '../../core/error_messages.dart';
import '../widgets/galaxy_button.dart';

class CreditsHubScreen extends StatefulWidget {
  const CreditsHubScreen({super.key});

  @override
  State<CreditsHubScreen> createState() => _CreditsHubScreenState();
}

class _CreditsHubScreenState extends State<CreditsHubScreen> {
  int? _balance;
  bool _loading = true;
  bool _openingPayPal = false;
  String? _loadError;

  bool get _english => AppErrorMessages.isEnglish;

  Uri? get _payPalUri {
    final uri = Uri.tryParse(Env.paypalReloadUrl.trim());
    if (uri == null || uri.scheme != 'https') return null;
    final host = uri.host.toLowerCase();
    final allowed = host == 'paypal.com' ||
        host.endsWith('.paypal.com') ||
        host == 'paypal.me' ||
        host.endsWith('.paypal.me');
    return allowed ? uri : null;
  }

  @override
  void initState() {
    super.initState();
    _loadBalance();
  }

  Future<void> _loadBalance() async {
    if (mounted) {
      setState(() {
        _loading = true;
        _loadError = null;
      });
    }
    try {
      final response = await ApiClient.get('/credits');
      final data = ApiClient.decode(response);
      if (data is! Map) throw const FormatException('Invalid credits response');
      final rawBalance = data['balance'];
      if (rawBalance is! num || !rawBalance.isFinite || rawBalance < 0) {
        throw const FormatException('Invalid credits balance');
      }
      if (!mounted) return;
      setState(() {
        _balance = rawBalance.toInt();
        _loading = false;
      });
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _loading = false;
        _loadError = error is ApiException
            ? error.message
            : AppErrorMessages.fromException(error);
      });
    }
  }

  String _formatBalance(int value) {
    final digits = value.toString();
    final separator = _english ? ',' : '.';
    return digits.replaceAllMapped(
      RegExp(r'\B(?=(\d{3})+(?!\d))'),
      (_) => separator,
    );
  }

  Future<void> _openPayPal() async {
    final uri = _payPalUri;
    if (uri == null || _openingPayPal) return;
    setState(() => _openingPayPal = true);
    try {
      final opened = await launchUrl(uri, mode: LaunchMode.externalApplication);
      if (!opened && mounted) {
        _showMessage(_english ? 'Could not open PayPal.' : 'No se pudo abrir PayPal.');
      }
    } catch (_) {
      if (mounted) {
        _showMessage(_english ? 'Could not open PayPal. Check your connection.' : 'No se pudo abrir PayPal. Revisa tu conexión.');
      }
    } finally {
      if (mounted) setState(() => _openingPayPal = false);
    }
  }

  void _showMessage(String message) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(message)));
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colors = theme.colorScheme;
    final available = _payPalUri != null;

    return Scaffold(
      appBar: AppBar(
        title: Text(_english ? 'AI credits' : 'Créditos de IA'),
        actions: [
          IconButton(
            tooltip: _english ? 'Refresh balance' : 'Actualizar saldo',
            onPressed: _loading ? null : _loadBalance,
            icon: const Icon(Icons.refresh_rounded),
          ),
          const SizedBox(width: 8),
        ],
      ),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.fromLTRB(20, 12, 20, 28),
          children: [
            Container(
              padding: const EdgeInsets.all(24),
              decoration: BoxDecoration(
                color: colors.surfaceContainerHighest,
                borderRadius: BorderRadius.circular(26),
                border: Border.all(color: colors.outlineVariant.withValues(alpha: 0.7)),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Icon(Icons.credit_card_rounded, size: 28, color: colors.primary),
                  const SizedBox(height: 22),
                  Text(
                    _balance == 0
                        ? (_english ? 'You are out of credits' : 'Te quedaste sin créditos')
                        : (_english ? 'Available balance' : 'Saldo disponible'),
                    style: theme.textTheme.titleMedium,
                  ),
                  const SizedBox(height: 8),
                  if (_loading)
                    const SizedBox(
                      height: 43,
                      child: Align(alignment: Alignment.centerLeft, child: SizedBox(width: 24, height: 24, child: CircularProgressIndicator(strokeWidth: 2))),
                    )
                  else if (_balance != null)
                    Text(
                      _formatBalance(_balance!),
                      style: theme.textTheme.headlineLarge?.copyWith(fontWeight: FontWeight.w800, letterSpacing: -1.2),
                    )
                  else
                    Text('—', style: theme.textTheme.headlineLarge?.copyWith(fontWeight: FontWeight.w800)),
                  const SizedBox(height: 8),
                  Text(
                    _english
                        ? 'Credits are read from your Numination account. They are not stored on this device.'
                        : 'El saldo se consulta desde tu cuenta de Numination; no se inventa ni se guarda en este dispositivo.',
                    style: theme.textTheme.bodyMedium?.copyWith(color: colors.onSurfaceVariant, height: 1.45),
                  ),
                ],
              ),
            ),
            if (_loadError != null) ...[
              const SizedBox(height: 14),
              Text(_loadError!, style: TextStyle(color: colors.error)),
              Align(
                alignment: Alignment.centerLeft,
                child: TextButton.icon(
                  onPressed: _loadBalance,
                  icon: const Icon(Icons.refresh_rounded),
                  label: Text(_english ? 'Try again' : 'Reintentar'),
                ),
              ),
            ],
            const SizedBox(height: 20),
            GalaxyButton(
              onPressed: available && !_openingPayPal ? _openPayPal : null,
              child: Row(
                mainAxisSize: MainAxisSize.min,
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  if (_openingPayPal)
                    const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2))
                  else
                    const Icon(Icons.open_in_new_rounded, size: 19),
                  const SizedBox(width: 10),
                  Text(_openingPayPal
                      ? (_english ? 'Opening…' : 'Abriendo…')
                      : (_english ? 'Recharge' : 'Recargar')),
                ],
              ),
            ),
            if (!available) ...[
              const SizedBox(height: 12),
              Text(
                _english ? 'Recharges are not configured yet.' : 'Las recargas aún no están configuradas.',
                textAlign: TextAlign.center,
                style: theme.textTheme.bodySmall?.copyWith(color: colors.onSurfaceVariant),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
'''

button_text = r'''import 'dart:math' as math;
import 'package:flutter/material.dart';

class GalaxyButton extends StatefulWidget {
  const GalaxyButton({
    super.key,
    required this.child,
    required this.onPressed,
    this.borderRadius = const BorderRadius.all(Radius.circular(22)),
    this.padding = const EdgeInsets.symmetric(horizontal: 22, vertical: 16),
  });
  final Widget child;
  final VoidCallback? onPressed;
  final BorderRadius borderRadius;
  final EdgeInsetsGeometry padding;
  @override
  State<GalaxyButton> createState() => _GalaxyButtonState();
}

class _GalaxyButtonState extends State<GalaxyButton> with SingleTickerProviderStateMixin {
  late final AnimationController _controller;
  bool _hovered = false;
  bool _pressed = false;
  @override
  void initState() {
    super.initState();
    _controller = AnimationController(vsync: this, duration: const Duration(milliseconds: 2600))..repeat();
  }
  @override
  void dispose() { _controller.dispose(); super.dispose(); }
  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    final active = widget.onPressed != null && (_hovered || _pressed);
    return MouseRegion(
      onEnter: (_) => setState(() => _hovered = true),
      onExit: (_) => setState(() => _hovered = false),
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTapDown: widget.onPressed == null ? null : (_) => setState(() => _pressed = true),
        onTapCancel: () => setState(() => _pressed = false),
        onTapUp: widget.onPressed == null ? null : (_) => setState(() => _pressed = false),
        onTap: widget.onPressed,
        child: AnimatedScale(
          scale: _pressed ? 0.985 : 1,
          duration: const Duration(milliseconds: 120),
          child: AnimatedBuilder(
            animation: _controller,
            builder: (context, _) => CustomPaint(
              painter: _GalaxyBorderPainter(_controller.value, colors.primary, widget.borderRadius.topLeft.x, active),
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 180),
                padding: widget.padding,
                decoration: BoxDecoration(
                  borderRadius: widget.borderRadius,
                  color: Color.lerp(colors.surface, colors.primary, active ? 0.13 : 0.04),
                  boxShadow: active ? [BoxShadow(color: colors.primary.withValues(alpha: 0.22), blurRadius: 22)] : const [],
                ),
                child: Center(child: Opacity(opacity: widget.onPressed == null ? 0.45 : 1, child: widget.child)),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _GalaxyBorderPainter extends CustomPainter {
  const _GalaxyBorderPainter(this.progress, this.color, this.radius, this.active);
  final double progress;
  final Color color;
  final double radius;
  final bool active;
  @override
  void paint(Canvas canvas, Size size) {
    if (size.isEmpty) return;
    final shader = SweepGradient(
      transform: GradientRotation(progress * math.pi * 2),
      colors: [color.withValues(alpha: 0.12), color.withValues(alpha: active ? 1 : 0.55), color.withValues(alpha: 0.14), color.withValues(alpha: 0.12)],
      stops: const [0, 0.42, 0.53, 1],
    ).createShader(Offset.zero & size);
    final rect = (Offset.zero & size).deflate(0.8);
    canvas.drawRRect(
      RRect.fromRectAndRadius(rect, Radius.circular(radius)),
      Paint()..style = PaintingStyle.stroke..strokeWidth = active ? 1.5 : 1..shader = shader,
    );
  }
  @override
  bool shouldRepaint(covariant _GalaxyBorderPainter old) => progress != old.progress || color != old.color || radius != old.radius || active != old.active;
}
'''

# Commit the local edits only after every structural precondition was validated.
if not button.exists():
    button.write_text(button_text)
screen.write_text(screen_text)
hamburger.write_text(source)
print(f"UI aplicada. Copias de seguridad: {backup_dir}")
print("Archivos modificados/creados:")
print("  lib/features/widgets/hamburger.dart")
print("  lib/features/screens/credits_hub_screen.dart")
if not (backup_dir / "galaxy_button.dart").exists():
    print("  lib/features/widgets/galaxy_button.dart (creado solo porque no existía)")
PY

if command -v dart >/dev/null 2>&1; then
  dart format lib/features/widgets/hamburger.dart lib/features/screens/credits_hub_screen.dart lib/features/widgets/galaxy_button.dart
else
  echo "Dart no disponible; no se ejecutó formatter."
fi

git diff --check -- lib/features/widgets/hamburger.dart lib/features/screens/credits_hub_screen.dart lib/features/widgets/galaxy_button.dart
printf '\n===== CAMBIOS LOCALES =====\n'
git status --short
printf '\nNo se hizo commit ni push. La pantalla debe aparecer en el menú hamburguesa debajo de Notificaciones.\n'
