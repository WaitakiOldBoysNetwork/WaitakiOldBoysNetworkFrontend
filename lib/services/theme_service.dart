import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Manages the user's light/dark theme preference and persists it across sessions.
class ThemeService extends ChangeNotifier {
  static final ThemeService _instance = ThemeService._internal();
  factory ThemeService() => _instance;
  ThemeService._internal();

  static const String _prefsKey = 'sp_theme_mode';

  ThemeMode _themeMode = ThemeMode.light;

  ThemeMode get themeMode => _themeMode;
  bool get isDark => _themeMode == ThemeMode.dark;

  Future<void> loadSavedTheme() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final saved = prefs.getString(_prefsKey);
      if (saved == 'dark') {
        _themeMode = ThemeMode.dark;
      } else if (saved == 'system') {
        _themeMode = ThemeMode.system;
      } else {
        _themeMode = ThemeMode.light;
      }
      notifyListeners();
    } catch (_) {
      // Safe fallback when storage is unavailable
    }
  }

  Future<void> setThemeMode(ThemeMode mode) async {
    if (_themeMode == mode) return;
    _themeMode = mode;
    notifyListeners();
    try {
      final prefs = await SharedPreferences.getInstance();
      final value = switch (mode) {
        ThemeMode.dark => 'dark',
        ThemeMode.system => 'system',
        ThemeMode.light => 'light',
      };
      await prefs.setString(_prefsKey, value);
    } catch (_) {}
  }

  Future<void> toggleTheme() async {
    await setThemeMode(isDark ? ThemeMode.light : ThemeMode.dark);
  }

  @visibleForTesting
  void resetForTest() {
    _themeMode = ThemeMode.light;
  }
}
