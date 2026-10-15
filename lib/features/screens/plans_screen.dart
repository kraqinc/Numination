import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

class PlansScreen extends StatelessWidget {
  const PlansScreen({super.key});

  static final Uri _nequiUri = Uri.parse('https://www.nequi.com.co/');

  Future<void> _openNequi(BuildContext context) async {
    final opened = await launchUrl(
      _nequiUri,
      mode: LaunchMode.externalApplication,
    );

    if (!opened && context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('No pudimos abrir el sitio de Nequi.')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    final text = Theme.of(context).textTheme;

    return Scaffold(
      appBar: AppBar(title: const Text('Suscripciones')),
      body: ListView(
        padding: const EdgeInsets.all(20),
        children: [
          Text(
            'Elige cómo quieres usar Numination',
            style: text.headlineSmall?.copyWith(fontWeight: FontWeight.w800),
          ),
          const SizedBox(height: 8),
          Text(
            'Más créditos para tus conversaciones y herramientas de IA.',
            style: text.bodyMedium?.copyWith(color: colors.onSurfaceVariant),
          ),
          const SizedBox(height: 24),
          _PlanCard(
            name: 'Pro',
            description: 'Para trabajar y resolver más tareas cada semana.',
            benefits: const [
              '6.500 créditos por semana',
              'Acceso a las funciones de Numination',
            ],
            onChoose: () => _openNequi(context),
          ),
          const SizedBox(height: 14),
          _PlanCard(
            name: 'Ultimate',
            featured: true,
            description: 'Más capacidad para proyectos de mayor uso.',
            benefits: const [
              '10.000 créditos por semana',
              'Generación de imágenes ilimitada',
            ],
            onChoose: () => _openNequi(context),
          ),
          const SizedBox(height: 14),
          Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: colors.surface,
              borderRadius: BorderRadius.circular(20),
              border: Border.all(color: colors.outlineVariant),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    const Expanded(
                      child: Text(
                        'Coder',
                        style: TextStyle(
                          fontSize: 20,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                    ),
                    Text(
                      'Gratis por ahora',
                      style: TextStyle(
                        color: colors.primary,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                Text(
                  'El modo Coder sigue disponible gratis mientras '
                  'Numination continúa en desarrollo.',
                  style: text.bodyMedium?.copyWith(
                    color: colors.onSurfaceVariant,
                    height: 1.4,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 20),
          OutlinedButton.icon(
            onPressed: () => _openNequi(context),
            icon: const Icon(Icons.open_in_new_rounded),
            label: const Text('Abrir Nequi'),
          ),
          const SizedBox(height: 10),
          Text(
            'La compra y activación de los planes requiere conectar '
            'la pasarela de pago con el backend. Abrir Nequi no activa '
            'una suscripción automáticamente.',
            textAlign: TextAlign.center,
            style: text.bodySmall?.copyWith(color: colors.onSurfaceVariant),
          ),
        ],
      ),
    );
  }
}

class _PlanCard extends StatelessWidget {
  const _PlanCard({
    required this.name,
    required this.description,
    required this.benefits,
    required this.onChoose,
    this.featured = false,
  });

  final String name;
  final String description;
  final List<String> benefits;
  final VoidCallback onChoose;
  final bool featured;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    final text = Theme.of(context).textTheme;

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: featured
            ? colors.primaryContainer.withValues(alpha: 0.35)
            : colors.surface,
        borderRadius: BorderRadius.circular(22),
        border: Border.all(
          color: featured ? colors.primary : colors.outlineVariant,
          width: featured ? 1.5 : 1,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  name,
                  style: text.titleLarge?.copyWith(fontWeight: FontWeight.w800),
                ),
              ),
              if (featured)
                Text(
                  'MÁS CAPACIDAD',
                  style: text.labelSmall?.copyWith(
                    color: colors.primary,
                    fontWeight: FontWeight.w800,
                    letterSpacing: 0.6,
                  ),
                ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            description,
            style: text.bodyMedium?.copyWith(color: colors.onSurfaceVariant),
          ),
          const SizedBox(height: 16),
          for (final benefit in benefits)
            Padding(
              padding: const EdgeInsets.only(bottom: 10),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Icon(
                    Icons.check_circle_outline_rounded,
                    size: 19,
                    color: colors.primary,
                  ),
                  const SizedBox(width: 10),
                  Expanded(child: Text(benefit)),
                ],
              ),
            ),
          const SizedBox(height: 8),
          SizedBox(
            width: double.infinity,
            child: FilledButton(
              onPressed: onChoose,
              child: const Padding(
                padding: EdgeInsets.symmetric(vertical: 12),
                child: Text('Consultar pago'),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
