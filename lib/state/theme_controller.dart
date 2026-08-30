import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// User-chosen appearance, persisted on device.
///
/// Following the system is the default because it is right most of the time,
/// but it is a default rather than a rule: people read this app on a bus at
/// night and in an office at noon, and the OS setting often lags both.
class ThemeController extends ChangeNotifier {
  static const _key = 'gc-theme-mode';

  ThemeMode _mode = ThemeMode.system;
  bool _loaded = false;

  ThemeMode get mode => _mode;
  bool get loaded => _loaded;

  Future<void> load() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      _mode = _parse(prefs.getString(_key));
    } catch (_) {
      _mode = ThemeMode.system;
    }
    _loaded = true;
    notifyListeners();
  }

  Future<void> setMode(ThemeMode mode) async {
    if (mode == _mode) return;
    _mode = mode;
    notifyListeners();
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(_key, mode.name);
    } catch (_) {
      // Losing the preference is survivable; refusing to switch is not.
    }
  }

  static ThemeMode _parse(String? raw) => switch (raw) {
        'light' => ThemeMode.light,
        'dark' => ThemeMode.dark,
        _ => ThemeMode.system,
      };

  String get label => switch (_mode) {
        ThemeMode.light => 'Light',
        ThemeMode.dark => 'Dark',
        ThemeMode.system => 'Match device',
      };
}
