import 'package:shared_preferences/shared_preferences.dart';

class StorageService {
  static SharedPreferences? _prefs;

  // Keys
  static const String _themeKey = 'theme_mode';
  static const String _onboardingKey = 'onboarding_completed';
  static const String _languageKey = 'selected_language';

  static Future<void> init() async {
    _prefs = await SharedPreferences.getInstance();
  }

  static SharedPreferences get prefs {
    if (_prefs == null) {
      throw Exception(
        'StorageService not initialized. Call StorageService.init() first.',
      );
    }
    return _prefs!;
  }

  // Theme methods
  static Future<bool> setTheme(String theme) async {
    return await prefs.setString(_themeKey, theme);
  }

  static Future<String> getTheme() async {
    return prefs.getString(_themeKey) ?? 'system';
  }

  // Onboarding methods
  static Future<bool> setOnboardingCompleted(bool completed) async {
    return await prefs.setBool(_onboardingKey, completed);
  }

  static Future<bool> isOnboardingCompleted() async {
    return prefs.getBool(_onboardingKey) ?? false;
  }

  // Language methods
  static Future<bool> setLanguage(String languageCode) async {
    return await prefs.setString(_languageKey, languageCode);
  }

  static Future<String> getLanguage() async {
    return prefs.getString(_languageKey) ?? 'en';
  }

  // Clear all data
  static Future<bool> clearAll() async {
    return await prefs.clear();
  }
}
