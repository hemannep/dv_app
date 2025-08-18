// lib/core/services/storage_service.dart

import 'package:shared_preferences/shared_preferences.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'dart:convert';

class StorageService {
  static late SharedPreferences _prefs;
  static late Box _photoBox;
  static late Box _settingsBox;
  static late Box _cacheBox;

  // Keys for various settings
  static const String _onboardingKey = 'onboarding_completed';
  static const String _languageKey = 'app_language';
  static const String _firstTimeKey = 'first_time';
  static const String _notificationsEnabledKey = 'notifications_enabled';
  static const String _autoSaveKey = 'auto_save_enabled';
  static const String _babyModeKey = 'baby_mode_default';
  static const String _gridLinesKey = 'show_grid_lines';
  static const String _liveValidationKey = 'live_validation_enabled';
  static const String _soundEnabledKey = 'sound_enabled';
  static const String _vibrationEnabledKey = 'vibration_enabled';

  static Future<void> init() async {
    // Initialize SharedPreferences
    _prefs = await SharedPreferences.getInstance();

    // Initialize Hive
    await Hive.initFlutter();
    _photoBox = await Hive.openBox('photos');
    _settingsBox = await Hive.openBox('settings');
    _cacheBox = await Hive.openBox('cache');
  }

  // Onboarding methods
  static Future<bool> setOnboardingCompleted(bool completed) async {
    return await _prefs.setBool(_onboardingKey, completed);
  }

  static bool isOnboardingCompleted() {
    return _prefs.getBool(_onboardingKey) ?? false;
  }

  // Language methods
  static Future<bool> setLanguage(String languageCode) async {
    return await _prefs.setString(_languageKey, languageCode);
  }

  static String getLanguage() {
    return _prefs.getString(_languageKey) ?? 'en';
  }

  // First time check
  static Future<bool> setFirstTime(bool isFirstTime) async {
    return await _prefs.setBool(_firstTimeKey, isFirstTime);
  }

  static bool isFirstTime() {
    return _prefs.getBool(_firstTimeKey) ?? true;
  }

  // Notification settings
  static Future<bool> setNotificationsEnabled(bool enabled) async {
    return await _prefs.setBool(_notificationsEnabledKey, enabled);
  }

  static bool areNotificationsEnabled() {
    return _prefs.getBool(_notificationsEnabledKey) ?? true;
  }

  // Auto-save settings
  static Future<bool> setAutoSaveEnabled(bool enabled) async {
    return await _prefs.setBool(_autoSaveKey, enabled);
  }

  static bool isAutoSaveEnabled() {
    return _prefs.getBool(_autoSaveKey) ?? true;
  }

  // Baby mode settings
  static Future<bool> setBabyModeDefault(bool enabled) async {
    return await _prefs.setBool(_babyModeKey, enabled);
  }

  static bool isBabyModeDefault() {
    return _prefs.getBool(_babyModeKey) ?? false;
  }

  // Camera settings
  static Future<bool> setGridLinesEnabled(bool enabled) async {
    return await _prefs.setBool(_gridLinesKey, enabled);
  }

  static bool areGridLinesEnabled() {
    return _prefs.getBool(_gridLinesKey) ?? true;
  }

  static Future<bool> setLiveValidationEnabled(bool enabled) async {
    return await _prefs.setBool(_liveValidationKey, enabled);
  }

  static bool isLiveValidationEnabled() {
    return _prefs.getBool(_liveValidationKey) ?? true;
  }

  // Sound and vibration settings
  static Future<bool> setSoundEnabled(bool enabled) async {
    return await _prefs.setBool(_soundEnabledKey, enabled);
  }

  static bool isSoundEnabled() {
    return _prefs.getBool(_soundEnabledKey) ?? true;
  }

  static Future<bool> setVibrationEnabled(bool enabled) async {
    return await _prefs.setBool(_vibrationEnabledKey, enabled);
  }

  static bool isVibrationEnabled() {
    return _prefs.getBool(_vibrationEnabledKey) ?? true;
  }

  // Generic SharedPreferences methods
  static Future<bool> setBool(String key, bool value) async {
    return await _prefs.setBool(key, value);
  }

  static bool? getBool(String key) {
    return _prefs.getBool(key);
  }

  static Future<bool> setString(String key, String value) async {
    return await _prefs.setString(key, value);
  }

  static String? getString(String key) {
    return _prefs.getString(key);
  }

  static Future<bool> setInt(String key, int value) async {
    return await _prefs.setInt(key, value);
  }

  static int? getInt(String key) {
    return _prefs.getInt(key);
  }

  static Future<bool> setDouble(String key, double value) async {
    return await _prefs.setDouble(key, value);
  }

  static double? getDouble(String key) {
    return _prefs.getDouble(key);
  }

  static Future<bool> setStringList(String key, List<String> value) async {
    return await _prefs.setStringList(key, value);
  }

  static List<String>? getStringList(String key) {
    return _prefs.getStringList(key);
  }

  // Photo storage methods
  static Future<void> savePhoto(
    String path,
    Map<String, dynamic> metadata,
  ) async {
    await _photoBox.put(path, jsonEncode(metadata));
  }

  static Map<String, dynamic>? getPhotoMetadata(String path) {
    final data = _photoBox.get(path);
    if (data != null) {
      return jsonDecode(data);
    }
    return null;
  }

  static List<String> getAllPhotoPaths() {
    return _photoBox.keys.cast<String>().toList();
  }

  static Future<void> deletePhoto(String path) async {
    await _photoBox.delete(path);
  }

  static Future<void> savePhotoToHistory(String path) async {
    List<String> history = getStringList('photo_history') ?? [];
    history.insert(0, path);
    if (history.length > 50) {
      history = history.sublist(0, 50);
    }
    await setStringList('photo_history', history);
  }

  static List<String> getPhotoHistory() {
    return getStringList('photo_history') ?? [];
  }

  // Settings storage methods
  static Future<void> saveSetting(String key, dynamic value) async {
    await _settingsBox.put(key, value);
  }

  static dynamic getSetting(String key, {dynamic defaultValue}) {
    return _settingsBox.get(key, defaultValue: defaultValue);
  }

  // Cache methods
  static Future<void> cacheData(String key, dynamic data) async {
    await _cacheBox.put(key, {
      'data': data,
      'timestamp': DateTime.now().millisecondsSinceEpoch,
    });
  }

  static dynamic getCachedData(String key, {Duration? maxAge}) {
    final cached = _cacheBox.get(key);
    if (cached == null) return null;

    if (maxAge != null) {
      final timestamp = cached['timestamp'] as int;
      final age = DateTime.now().millisecondsSinceEpoch - timestamp;
      if (age > maxAge.inMilliseconds) {
        _cacheBox.delete(key);
        return null;
      }
    }

    return cached['data'];
  }

  static Future<void> clearCache() async {
    await _cacheBox.clear();
  }

  // Statistics methods
  static Future<void> incrementPhotoCount() async {
    final count = getInt('total_photos_taken') ?? 0;
    await setInt('total_photos_taken', count + 1);
  }

  static int getTotalPhotosTaken() {
    return getInt('total_photos_taken') ?? 0;
  }

  static Future<void> updateLastPhotoDate() async {
    await setString('last_photo_date', DateTime.now().toIso8601String());
  }

  static DateTime? getLastPhotoDate() {
    final dateStr = getString('last_photo_date');
    if (dateStr != null) {
      return DateTime.parse(dateStr);
    }
    return null;
  }

  // Clear methods
  static Future<void> clearAllData() async {
    await _prefs.clear();
    await _photoBox.clear();
    await _settingsBox.clear();
    await _cacheBox.clear();
  }

  static Future<void> clearPhotos() async {
    await _photoBox.clear();
    await _prefs.remove('photo_history');
  }

  static Future<void> clearSettings() async {
    await _settingsBox.clear();
    // Preserve critical settings
    final onboarding = isOnboardingCompleted();
    final language = getLanguage();
    await _prefs.clear();
    await setOnboardingCompleted(onboarding);
    await setLanguage(language);
  }

  // Export/Import methods for backup
  static Future<Map<String, dynamic>> exportData() async {
    return {
      'settings': _prefs.getKeys().fold<Map<String, dynamic>>(
        {},
        (map, key) => map..[key] = _prefs.get(key),
      ),
      'photos': _photoBox.toMap(),
      'app_settings': _settingsBox.toMap(),
    };
  }

  static Future<void> importData(Map<String, dynamic> data) async {
    // Import settings
    if (data['settings'] != null) {
      final settings = data['settings'] as Map<String, dynamic>;
      for (final entry in settings.entries) {
        if (entry.value is bool) {
          await setBool(entry.key, entry.value);
        } else if (entry.value is int) {
          await setInt(entry.key, entry.value);
        } else if (entry.value is double) {
          await setDouble(entry.key, entry.value);
        } else if (entry.value is String) {
          await setString(entry.key, entry.value);
        } else if (entry.value is List<String>) {
          await setStringList(entry.key, entry.value);
        }
      }
    }

    // Import photos
    if (data['photos'] != null) {
      final photos = data['photos'] as Map;
      for (final entry in photos.entries) {
        await _photoBox.put(entry.key, entry.value);
      }
    }

    // Import app settings
    if (data['app_settings'] != null) {
      final settings = data['app_settings'] as Map;
      for (final entry in settings.entries) {
        await _settingsBox.put(entry.key, entry.value);
      }
    }
  }
}
