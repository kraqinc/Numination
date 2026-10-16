import 'package:flutter/material.dart';

import '../../core/api.dart';
import 'plans_screen.dart';
import '../widgets/numi_loading_animation.dart';

class CreditsHubScreen extends StatefulWidget {
  const CreditsHubScreen({super.key});

  @override
  State<CreditsHubScreen> createState() => _CreditsHubScreenState();
}

class _CreditsHubScreenState extends State<CreditsHubScreen> {
  int? _balance;
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

    return Scaffold(
      appBar: AppBar(
        title: const Text('Créditos'),
        actions: [
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
                    const NumiLoadingAnimation()
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
