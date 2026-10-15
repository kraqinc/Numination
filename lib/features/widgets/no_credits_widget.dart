import 'dart:async';

import 'package:flutter/material.dart';

class NoCreditsWidged extends StatefulWidget {
  const NoCreditsWidged({super.key, required this.onViewPlans, this.resetAt});

  final DateTime? resetAt;
  final VoidCallback onViewPlans;

  @override
  State<NoCreditsWidged> createState() => _NoCreditsWidgedState();
}

class _NoCreditsWidgedState extends State<NoCreditsWidged> {
  Timer? _timer;
  Duration? _remaining;

  @override
  void initState() {
    super.initState();
    _updateRemaining();
    _timer = Timer.periodic(
      const Duration(seconds: 1),
      (_) => _updateRemaining(),
    );
  }

  @override
  void didUpdateWidget(covariant NoCreditsWidged oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.resetAt != widget.resetAt) {
      _updateRemaining();
    }
  }

  void _updateRemaining() {
    final resetAt = widget.resetAt;

    if (resetAt == null) {
      if (mounted) setState(() => _remaining = null);
      return;
    }

    final difference = resetAt.toLocal().difference(DateTime.now());
    if (!mounted) return;

    setState(() {
      _remaining = difference.isNegative ? Duration.zero : difference;
    });
  }

  String _formatRemaining(Duration duration) {
    final days = duration.inDays;
    final hours = duration.inHours.remainder(24);
    final minutes = duration.inMinutes.remainder(60);
    final seconds = duration.inSeconds.remainder(60);

    String two(int value) => value.toString().padLeft(2, '0');

    if (days > 0) {
      return '${days}d ${two(hours)}:${two(minutes)}:${two(seconds)}';
    }

    return '${two(hours)}:${two(minutes)}:${two(seconds)}';
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;

    final remaining = _remaining;
    final resetAvailable = remaining != null && remaining == Duration.zero;

    return Container(
      width: double.infinity,
      margin: const EdgeInsets.fromLTRB(12, 4, 12, 12),
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: colors.surface,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: colors.outlineVariant.withValues(alpha: 0.7)),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.bolt_rounded, size: 30, color: colors.primary),
          const SizedBox(height: 12),
          Text(
            'Te quedaste sin créditos',
            textAlign: TextAlign.center,
            style: Theme.of(
              context,
            ).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w800),
          ),
          const SizedBox(height: 8),
          Text(
            'Compra un plan o espera a que se renueven tus créditos.',
            textAlign: TextAlign.center,
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
              color: colors.onSurfaceVariant,
              height: 1.4,
            ),
          ),
          if (remaining != null) ...[
            const SizedBox(height: 18),
            Text(
              resetAvailable
                  ? 'Comprueba tu saldo actualizado'
                  : 'Próxima renovación',
              style: Theme.of(
                context,
              ).textTheme.labelLarge?.copyWith(color: colors.onSurfaceVariant),
            ),
            if (!resetAvailable) ...[
              const SizedBox(height: 6),
              Text(
                _formatRemaining(remaining),
                style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                  fontWeight: FontWeight.w800,
                  fontFeatures: const [],
                ),
              ),
            ],
          ],
          const SizedBox(height: 18),
          SizedBox(
            width: double.infinity,
            child: FilledButton(
              onPressed: widget.onViewPlans,
              child: const Padding(
                padding: EdgeInsets.symmetric(vertical: 13),
                child: Text('Ver planes'),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
