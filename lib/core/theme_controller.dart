import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'theme.dart';

const _prefsKey = 'app_theme_mode';

class ThemeController extends Notifier<AppThemeMode> {
  @override
  AppThemeMode build() {
    _loadSaved();
    return AppThemeMode.gray;
  }

  Future<void> _loadSaved() async {
    final prefs = await SharedPreferences.getInstance();
    final saved = prefs.getString(_prefsKey);
    if (saved != null) {
      state = AppThemeModeLabel.fromStorageKey(saved);
    }
  }

  Future<void> setMode(AppThemeMode mode) async {
    state = mode;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_prefsKey, mode.storageKey);
  }
}

final themeControllerProvider = NotifierProvider<ThemeController, AppThemeMode>(ThemeController.new);

final appPaletteProvider = Provider<AppPalette>((ref) {
  final mode = ref.watch(themeControllerProvider);
  return AppPalette.of(mode);
});