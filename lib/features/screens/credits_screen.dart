import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../core/env.dart';
import '../../core/error_messages.dart';
import '../widgets/galaxy_button.dart';

class CreditsScreen extends StatefulWidget {
  const CreditsScreen({super.key, required this.balance, this.onRefresh});

  /// Saldo recibido del sistema de créditos, no un valor ficticio local.
  final int balance;
  final VoidCallback? onRefresh;

  @override
  State<CreditsScreen> createState() => _CreditsScreenState();
}

class _CreditsScreenState extends State<CreditsScreen> {
  bool _openingPayPal = false;

  bool get _isEnglish => AppErrorMessages.isEnglish;

  Uri? get _payPalUri {
    final uri = Uri.tryParse(Env.paypalReloadUrl.trim());
    if (uri == null || uri.scheme != 'https') return null;

    final host = uri.host.toLowerCase();
    final isPayPal =
        host == 'paypal.com' ||
        host.endsWith('.paypal.com') ||
        host == 'paypal.me' ||
        host.endsWith('.paypal.me');

    return isPayPal ? uri : null;
  }

  String get _formattedBalance {
    final locale = _isEnglish ? 'en_US' : 'es_CO';
    return NumberFormat.decimalPattern(locale).format(widget.balance);
  }

  Future<void> _openPayPal() async {
    final uri = _payPalUri;
    if (uri == null || _openingPayPal) return;

    setState(() => _openingPayPal = true);

    try {
      final launched = await launchUrl(
        uri,
        mode: LaunchMode.externalApplication,
      );

      if (!launched && mounted) {
        _showMessage(
          _isEnglish
              ? 'PayPal could not be opened. Try again.'
              : 'No se pudo abrir PayPal. Inténtalo de nuevo.',
        );
      }
    } catch (_) {
      if (mounted) {
        _showMessage(
          _isEnglish
              ? 'PayPal could not be opened. Check your connection.'
              : 'No se pudo abrir PayPal. Revisa tu conexión.',
        );
      }
    } finally {
      if (mounted) setState(() => _openingPayPal = false);
    }
  }

  void _showMessage(String message) {
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text(message)));
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colors = theme.colorScheme;
    final palette = theme.textTheme;
    final hasCredits = widget.balance > 0;
    final payPalConfigured = _payPalUri != null;

    return Scaffold(
      appBar: AppBar(
        title: Text(_isEnglish ? 'AI credits' : 'Créditos de IA'),
        actions: [
          if (widget.onRefresh != null)
            IconButton(
              tooltip: _isEnglish ? 'Refresh balance' : 'Actualizar saldo',
              onPressed: widget.onRefresh,
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
                border: Border.all(
                  color: colors.outlineVariant.withValues(alpha: 0.7),
                ),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Icon(
                    Icons.credit_card_rounded,
                    size: 28,
                    color: colors.primary,
                  ),
                  const SizedBox(height: 22),
                  Text(
                    hasCredits
                        ? (_isEnglish
                              ? 'Available balance'
                              : 'Saldo disponible')
                        : (_isEnglish
                              ? 'You are out of credits'
                              : 'Te quedaste sin créditos'),
                    style: palette.titleMedium,
                  ),
                  const SizedBox(height: 8),
                  Text(
                    _formattedBalance,
                    style: palette.headlineLarge?.copyWith(
                      fontWeight: FontWeight.w800,
                      letterSpacing: -1.2,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    _isEnglish
                        ? 'AI credits for your Numination conversations and coding sessions.'
                        : 'Créditos de IA para tus conversaciones y sesiones de Coder en Numination.',
                    style: palette.bodyMedium?.copyWith(
                      color: colors.onSurfaceVariant,
                      height: 1.45,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 20),
            GalaxyButton(
              onPressed: payPalConfigured && !_openingPayPal
                  ? _openPayPal
                  : null,
              child: Row(
                mainAxisSize: MainAxisSize.min,
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  if (_openingPayPal)
                    const SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  else
                    const Icon(Icons.open_in_new_rounded, size: 19),
                  const SizedBox(width: 10),
                  Text(
                    _openingPayPal
                        ? (_isEnglish ? 'Opening…' : 'Abriendo…')
                        : (_isEnglish ? 'Recharge' : 'Recargar'),
                    style: palette.titleMedium?.copyWith(
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ],
              ),
            ),
            if (!payPalConfigured) ...[
              const SizedBox(height: 12),
              Text(
                _isEnglish
                    ? 'Recharges are temporarily unavailable.'
                    : 'Las recargas no están disponibles por el momento.',
                textAlign: TextAlign.center,
                style: palette.bodySmall?.copyWith(
                  color: colors.onSurfaceVariant,
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
