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

  /// Shared screen background used across the whole app (login wizard,
  /// home/chat, drawer-driven screens like projects/settings/etc). Only
  /// the connectivity banner keeps its own red, everything else uses
  /// this same gray for Scaffold.backgroundColor.
  static const screenBackground = Color(0xFFECECEC);
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
    snackBarTheme: const SnackBarThemeData(
      behavior: SnackBarBehavior.floating,
    ),
  );
}

/// Monochrome palette used only by the auth wizard (email / sign in /
/// confirm password), matching the Cursor-style reference designs.
/// Kept separate from [AppColors] so the rest of the app keeps its
/// cyan/purple identity.
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
  const GlassCard({super.key, required this.child, this.padding = const EdgeInsets.all(16), this.onTap});

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
        : InkWell(onTap: onTap, borderRadius: BorderRadius.circular(18), child: content);
  }
}