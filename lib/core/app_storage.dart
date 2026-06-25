import 'package:flutter_secure_storage/flutter_secure_storage.dart';

import 'app_language.dart';

class AppStorage {
  AppStorage._secure()
    : _secureStorage = const FlutterSecureStorage(),
      _memory = null;

  AppStorage.memory() : _secureStorage = null, _memory = <String, String>{};

  static AppStorage instance = AppStorage._secure();

  static const String _authTokenKey = 'auth_token';
  static const String _languageKey = 'app_language';
  static const String _onboardingDraftKey = 'smart_onboarding_draft';
  static const String _notificationPermissionPromptedKey =
      'notification_permission_prompted';

  final FlutterSecureStorage? _secureStorage;
  final Map<String, String>? _memory;

  Future<String?> _read(String key) async {
    final memory = _memory;
    if (memory != null) return memory[key];

    return _secureStorage!.read(key: key);
  }

  Future<void> _write(String key, String value) async {
    final memory = _memory;
    if (memory != null) {
      memory[key] = value;
      return;
    }

    await _secureStorage!.write(key: key, value: value);
  }

  Future<void> _delete(String key) async {
    final memory = _memory;
    if (memory != null) {
      memory.remove(key);
      return;
    }

    await _secureStorage!.delete(key: key);
  }

  Future<String?> readAuthToken() {
    return _read(_authTokenKey);
  }

  Future<void> saveAuthToken(String token) {
    return _write(_authTokenKey, token);
  }

  Future<void> clearAuthToken() {
    return _delete(_authTokenKey);
  }

  Future<AppLanguage?> readLanguage() async {
    final code = await _read(_languageKey);
    return appLanguageFromCode(code);
  }

  Future<void> saveLanguage(AppLanguage language) {
    return _write(_languageKey, appLanguageCode(language));
  }

  Future<void> clearLanguage() {
    return _delete(_languageKey);
  }

  Future<String?> readOnboardingDraftJson() {
    return _read(_onboardingDraftKey);
  }

  Future<void> saveOnboardingDraftJson(String value) {
    return _write(_onboardingDraftKey, value);
  }

  Future<void> clearOnboardingDraftJson() {
    return _delete(_onboardingDraftKey);
  }

  Future<bool> hasPromptedNotificationPermission() async {
    return await _read(_notificationPermissionPromptedKey) == 'true';
  }

  Future<void> markNotificationPermissionPrompted() {
    return _write(_notificationPermissionPromptedKey, 'true');
  }

  Future<void> clearSessionButKeepLanguage() {
    return clearAuthToken();
  }
}
