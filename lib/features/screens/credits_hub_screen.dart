import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../core/api.dart';
import 'plans_screen.dart';
import '../widgets/numi_skeleton.dart';

class CreditsHubScreen extends StatefulWidget {
  const CreditsHubScreen({super.key, this.desktopSheet = false});

  final bool desktopSheet;

  @override
  State<CreditsHubScreen> createState() => _CreditsHubScreenState();
}

class _CreditsHubScreenState extends State<CreditsHubScreen> {
  int? _balance;
  DateTime? _nextResetAt;
  String _tier = 'FREE';
  bool _loading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    if (mounted) {
      setState(() {
        _loading = true;
        _error = null;
      });
    }

    try {
      final response = await ApiClient.get('/credits');
      final data = ApiClient.decode(response) as Map<String, dynamic>;

      if (!mounted) return;

      setState(() {
        _balance = (data['balance'] as num?)?.toInt() ?? 0;
        _nextResetAt = DateTime.tryParse(
          data['nextResetAt']?.toString() ?? '',
        )?.toLocal();
        _tier = data['tier']?.toString().toUpperCase() ?? 'FREE';
        _loading = false;
      });
    } catch (_) {
      if (!mounted) return;

      setState(() {
        _loading = false;
        _error = 'No pudimos consultar tu saldo. Inténtalo de nuevo.';
      });
    }
  }

  void _openPlans() {
    Navigator.of(
      context,
    ).push<void>(MaterialPageRoute<void>(builder: (_) => const PlansScreen()));
  }

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    final typography = Theme.of(context).textTheme;
    final nextReset = _nextResetAt;
    final showDailyReset =
        !_loading && _error == null && _tier == 'FREE' && nextReset != null;
    final nextResetLabel = nextReset == null
        ? ''
        : DateFormat.yMMMd('es_CO').add_jm().format(nextReset);

    return Scaffold(
      appBar: AppBar(
        automaticallyImplyLeading: !widget.desktopSheet,
        title: const Text('Créditos'),
        actions: [
          if (widget.desktopSheet)
            IconButton(
              tooltip: 'Cerrar',
              onPressed: () => Navigator.of(context).pop(),
              icon: const Icon(Icons.close_rounded),
            ),

          IconButton(
            tooltip: 'Actualizar saldo',
            onPressed: _loading ? null : _load,
            icon: const Icon(Icons.refresh_rounded),
          ),
        ],
      ),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.all(20),
          children: [
            Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 32),
              decoration: BoxDecoration(
                color: colors.surfaceContainerHighest,
                borderRadius: BorderRadius.circular(24),
                border: Border.all(color: colors.outlineVariant),
              ),
              child: Column(
                children: [
                  Icon(Icons.bolt_rounded, size: 32, color: colors.primary),
                  const SizedBox(height: 16),
                  Text('Créditos actuales', style: typography.titleMedium),
                  const SizedBox(height: 10),
                  if (_loading)
                    const NumiSkeleton(
                      kind: NumiSkeletonKind.credits,
                      dense: true,
                    )
                  else if (_error != null)
                    Text(
                      _error!,
                      textAlign: TextAlign.center,
                      style: TextStyle(color: colors.error),
                    )
                  else
                    Text(
                      (_balance ?? 0).toString(),
                      textAlign: TextAlign.center,
                      style: typography.displayMedium?.copyWith(
                        fontWeight: FontWeight.w800,
                        letterSpacing: -1.5,
                      ),
                    ),
                  const SizedBox(height: 8),
                  Text(
                    'Tu saldo disponible para usar Numination AI.',
                    textAlign: TextAlign.center,
                    style: typography.bodyMedium?.copyWith(
                      color: colors.onSurfaceVariant,
                    ),
                  ),
                ],
              ),
            ),
            if (showDailyReset) ...[
              const SizedBox(height: 14),
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: colors.surfaceContainerHighest,
                  borderRadius: BorderRadius.circular(18),
                  border: Border.all(color: colors.outlineVariant),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Icon(
                          Icons.schedule_rounded,
                          size: 19,
                          color: colors.primary,
                        ),
                        const SizedBox(width: 9),
                        Text(
                          'Renovación diaria',
                          style: typography.titleSmall?.copyWith(
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'Tus créditos gratuitos se renuevan todos los días '
                      'a las 9:00 a. m., según la hora local de tu dispositivo.',
                      style: typography.bodySmall?.copyWith(
                        color: colors.onSurfaceVariant,
                        height: 1.4,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'Próxima reposición: $nextResetLabel',
                      style: typography.labelLarge,
                    ),
                  ],
                ),
              ),
            ],
            const SizedBox(height: 24),
            Text(
              'Consigue más créditos',
              style: typography.titleLarge?.copyWith(
                fontWeight: FontWeight.w700,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'Consulta los planes disponibles y sus beneficios.',
              style: typography.bodyMedium?.copyWith(
                color: colors.onSurfaceVariant,
              ),
            ),
            const SizedBox(height: 16),
            SizedBox(
              width: double.infinity,
              child: FilledButton(
                onPressed: _openPlans,
                child: const Padding(
                  padding: EdgeInsets.symmetric(vertical: 14),
                  child: Text('Ver planes'),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
