// lib/core/theme/theme_provider.dart

import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

class ThemeProvider extends ChangeNotifier {
  static const String _themeKey = 'theme_mode';
  static const String _languageKey = 'app_language';

  ThemeMode _themeMode = ThemeMode.system;
  String _languageCode = 'en';

  ThemeMode get themeMode => _themeMode;
  String get languageCode => _languageCode;

  // Check if dark mode is active
  bool get isDarkMode {
    if (_themeMode == ThemeMode.system) {
      // For system mode, we need to check the actual system brightness
      // This will be determined by the BuildContext in the UI
      return false; // Default to light for system mode
    }
    return _themeMode == ThemeMode.dark;
  }

  // Get the actual dark mode status with context
  bool isDarkModeActive(BuildContext context) {
    if (_themeMode == ThemeMode.system) {
      return MediaQuery.of(context).platformBrightness == Brightness.dark;
    }
    return _themeMode == ThemeMode.dark;
  }

  Future<void> loadTheme() async {
    final prefs = await SharedPreferences.getInstance();
    final themeModeIndex = prefs.getInt(_themeKey) ?? ThemeMode.system.index;
    _themeMode = ThemeMode.values[themeModeIndex];
    _languageCode = prefs.getString(_languageKey) ?? 'en';
    notifyListeners();
  }

  Future<void> setThemeMode(ThemeMode mode) async {
    if (_themeMode == mode) return;

    _themeMode = mode;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt(_themeKey, mode.index);
    notifyListeners();
  }

  Future<void> setLanguage(String languageCode) async {
    if (_languageCode == languageCode) return;

    _languageCode = languageCode;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_languageKey, languageCode);
    notifyListeners();
  }

  void toggleTheme() {
    if (_themeMode == ThemeMode.light) {
      setThemeMode(ThemeMode.dark);
    } else if (_themeMode == ThemeMode.dark) {
      setThemeMode(ThemeMode.system);
    } else {
      setThemeMode(ThemeMode.light);
    }
  }

  // Set dark mode directly
  Future<void> setDarkMode(bool isDark) async {
    await setThemeMode(isDark ? ThemeMode.dark : ThemeMode.light);
  }
}
