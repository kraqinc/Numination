import 'package:flutter/material.dart';

class AppColors {
  static const obsidian = Color(0xFF0A0D12);
  static const panel = Color(0xFF111722);
  static const card = Color(0xFF151C28);
  static const sidebar = Color(0xFF0D1117);
  static const border = Color(0xFF263140);
  static const text = Color(0xFFF3F5F7);
  static const muted = Color(0xFFA6AFBF);
  static const cyan = Color(0xFF6ED7FF);
  static const cyanSoft = Color(0xFF9CE7FF);
  static const purple = Color(0xFF7C5CFC);
  static const purpleSoft = Color(0xFF9B84FF);
  static const green = Color(0xFF53E08B);
  static const yellow = Color(0xFFFFD36A);
  static const red = Color(0xFFFF7282);

  /// Fondo del wizard de auth (login/signup), que se mantiene fijo sin
  /// importar el tema elegido por el usuario dentro de la app.
  static const screenBackground = Color(0xFFECECEC);
}

/// Los 4 temas que el usuario puede elegir desde Ajustes > Cambiar tema.
enum AppThemeMode { dark, gray, light, midnight }

extension AppThemeModeLabel on AppThemeMode {
  String get label => switch (this) {
    AppThemeMode.dark => 'Oscuro',
    AppThemeMode.gray => 'Gris',
    AppThemeMode.light => 'Blanco',
    AppThemeMode.midnight => 'Medianoche',
  };

  String get storageKey => switch (this) {
    AppThemeMode.dark => 'dark',
    AppThemeMode.gray => 'gray',
    AppThemeMode.light => 'light',
    AppThemeMode.midnight => 'midnight',
  };

  static AppThemeMode fromStorageKey(String? key) => switch (key) {
    'dark' => AppThemeMode.dark,
    'gray' => AppThemeMode.gray,
    'light' => AppThemeMode.light,
    'midnight' => AppThemeMode.midnight,
    _ => AppThemeMode.gray,
  };
}

/// Paleta resuelta para el tema activo. Todas las pantallas post-login
/// (home, drawer, ajustes, proyectos, artefactos, ghost chat, etc.) leen
/// sus colores de acá en vez de hardcodear Colors.black/white, así que
/// cambiar de tema los actualiza a todos de una.
class AppPalette {
  final AppThemeMode mode;
  final Color background;
  final Color surface;
  final Color surfaceAlt;
  final Color textPrimary;
  final Color textSecondary;
  final Color border;
  final Color accent;
  final bool isDark;

  const AppPalette({
    required this.mode,
    required this.background,
    required this.surface,
    required this.surfaceAlt,
    required this.textPrimary,
    required this.textSecondary,
    required this.border,
    required this.accent,
    required this.isDark,
  });

  factory AppPalette.of(AppThemeMode mode) {
    switch (mode) {
      case AppThemeMode.dark:
        return const AppPalette(
          mode: AppThemeMode.dark,
          background: Color(0xFF121212),
          surface: Color(0xFF1E1E1E),
          surfaceAlt: Color(0xFF262626),
          textPrimary: Colors.white,
          textSecondary: Color(0xFFA0A0A0),
          border: Color(0xFF333333),
          accent: Color(0xFF6ED7FF),
          isDark: true,
        );
      case AppThemeMode.midnight:
        return const AppPalette(
          mode: AppThemeMode.midnight,
          background: Color(0xFF05070D),
          surface: Color(0xFF0B0F1A),
          surfaceAlt: Color(0xFF12182A),
          textPrimary: Colors.white,
          textSecondary: Color(0xFF8892A8),
          border: Color(0xFF20263A),
          accent: Color(0xFF7C5CFC),
          isDark: true,
        );
      case AppThemeMode.light:
        return const AppPalette(
          mode: AppThemeMode.light,
          background: Colors.white,
          surface: Colors.white,
          surfaceAlt: Color(0xFFF4F4F4),
          textPrimary: Colors.black,
          textSecondary: Color(0xFF6B6B6B),
          border: Color(0xFFE2E2E2),
          accent: Color(0xFF1E88C7),
          isDark: false,
        );
      case AppThemeMode.gray:
        return const AppPalette(
          mode: AppThemeMode.gray,
          background: Color(0xFFECECEC),
          surface: Colors.white,
          surfaceAlt: Color(0xFFF0F0F0),
          textPrimary: Colors.black,
          textSecondary: Color(0xFF8A8A8A),
          border: Color(0xFFD8D8D8),
          accent: Color(0xFF1E88C7),
          isDark: false,
        );
    }
  }
}

ThemeData buildTheme() {
  final base = ThemeData.dark(useMaterial3: true);
  return base.copyWith(
    scaffoldBackgroundColor: AppColors.obsidian,
    colorScheme: base.colorScheme.copyWith(
      primary: AppColors.cyan,
      secondary: AppColors.purple,
      surface: AppColors.card,
      error: AppColors.red,
    ),
    textTheme: base.textTheme.apply(
      bodyColor: AppColors.text,
      displayColor: AppColors.text,
    ),
    appBarTheme: const AppBarTheme(
      backgroundColor: Colors.transparent,
      elevation: 0,
      foregroundColor: AppColors.text,
    ),
    inputDecorationTheme: InputDecorationTheme(
      filled: true,
      fillColor: AppColors.panel,
      hintStyle: const TextStyle(color: AppColors.muted),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.all(Radius.circular(14)),
        borderSide: BorderSide(color: AppColors.border),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.all(Radius.circular(14)),
        borderSide: BorderSide(color: AppColors.border),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.all(Radius.circular(14)),
        borderSide: BorderSide(color: AppColors.purpleSoft),
      ),
    ),
    snackBarTheme: const SnackBarThemeData(behavior: SnackBarBehavior.floating),
  );
}

/// Paleta monocromática del wizard de auth (login/signup), fija sin
/// importar el AppThemeMode elegido dentro de la app ya autenticada.
class AuthColors {
  static const background = Color(0xFF000000);
  static const surface = Color(0xFF0A0A0A);
  static const card = Color(0xFF111111);
  static const border = Color(0xFF232323);
  static const borderStrong = Color(0xFF313131);
  static const text = Color(0xFFF5F5F5);
  static const muted = Color(0xFF8A8A8A);
  static const mutedSoft = Color(0xFF5C5C5C);
  static const accent = Color(0xFFFFFFFF);
  static const error = Color(0xFFFF6B6B);
  static const success = Color(0xFF4ADE80);
}

class GlassCard extends StatelessWidget {
  final Widget child;
  final EdgeInsets padding;
  final VoidCallback? onTap;
  const GlassCard({
    super.key,
    required this.child,
    this.padding = const EdgeInsets.all(16),
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final content = Container(
      padding: padding,
      decoration: BoxDecoration(
        color: AppColors.card.withValues(alpha: 0.88),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: AppColors.border.withValues(alpha: 0.9)),
      ),
      child: child,
    );
    return onTap == null
        ? content
        : InkWell(
            onTap: onTap,
            borderRadius: BorderRadius.circular(18),
            child: content,
          );
  }
}
