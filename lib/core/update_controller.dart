import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

const _autoUpdateKey = 'auto_update_apk';

class AutoUpdateController extends Notifier<bool> {
  @override
  bool build() {
    _load();
    return true;
  }

  Future<void> _load() async {
    final prefs = await SharedPreferences.getInstance();
    final saved = prefs.getBool(_autoUpdateKey);

    if (saved != null) {
      state = saved;
    }
  }

  Future<void> setEnabled(bool enabled) async {
    state = enabled;

    final prefs = await SharedPreferences.getInstance();

    await prefs.setBool(
      _autoUpdateKey,
      enabled,
    );
  }
}

final autoUpdateProvider =
    NotifierProvider<AutoUpdateController, bool>(
  AutoUpdateController.new,
);
