import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/i18n.dart';
import '../../core/theme_controller.dart';

class MemoryScreen extends ConsumerWidget {
  const MemoryScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final palette = ref.watch(appPaletteProvider);

    return Scaffold(
      backgroundColor: palette.background,
      appBar: AppBar(
        backgroundColor: palette.background,
        elevation: 0,
        iconTheme: IconThemeData(color: palette.textPrimary),
        title: Text(AppLocale.t('memory'), style: TextStyle(color: palette.textPrimary)),
      ),
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(32),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.memory_outlined, color: palette.accent, size: 48),
              const SizedBox(height: 16),
              Text(
                'Numination todavía no ha guardado memorias sobre ti.',
                textAlign: TextAlign.center,
                style: TextStyle(color: palette.textPrimary, fontSize: 16, fontWeight: FontWeight.w600),
              ),
              const SizedBox(height: 8),
              Text(
                'A medida que converses, lo que sea relevante para futuras respuestas aparecerá acá.',
                textAlign: TextAlign.center,
                style: TextStyle(color: palette.textSecondary, fontSize: 13, height: 1.4),
              ),
            ],
          ),
        ),
      ),
    );
    }
  }