// lib/core/theme/theme_provider.dart - Fixed SharedPreferences issue
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
    try {
      final prefs = await SharedPreferences.getInstance();

      // Fix the type casting issue
      final themeModeValue = prefs.get(_themeKey);
      int themeModeIndex;

      if (themeModeValue is String) {
        // Handle case where it was saved as string
        themeModeIndex = int.tryParse(themeModeValue) ?? ThemeMode.system.index;
      } else if (themeModeValue is int) {
        themeModeIndex = themeModeValue;
      } else {
        themeModeIndex = ThemeMode.system.index;
      }

      // Ensure the index is valid
      if (themeModeIndex >= 0 && themeModeIndex < ThemeMode.values.length) {
        _themeMode = ThemeMode.values[themeModeIndex];
      } else {
        _themeMode = ThemeMode.system;
      }

      _languageCode = prefs.getString(_languageKey) ?? 'en';
      notifyListeners();
    } catch (e) {
      debugPrint('Error loading theme: $e');
      _themeMode = ThemeMode.system;
      _languageCode = 'en';
    }
  }

  Future<void> setThemeMode(ThemeMode mode) async {
    if (_themeMode == mode) return;

    _themeMode = mode;
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setInt(_themeKey, mode.index);
    } catch (e) {
      debugPrint('Error saving theme: $e');
    }
    notifyListeners();
  }

  Future<void> setLanguage(String languageCode) async {
    if (_languageCode == languageCode) return;

    _languageCode = languageCode;
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(_languageKey, languageCode);
    } catch (e) {
      debugPrint('Error saving language: $e');
    }
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
