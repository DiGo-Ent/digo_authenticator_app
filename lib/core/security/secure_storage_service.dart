import 'dart:convert';
import 'dart:math';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:crypto/crypto.dart';

class SecureStorageService {
  final FlutterSecureStorage _storage;
  SecureStorageService()
      : _storage = const FlutterSecureStorage(
          aOptions: AndroidOptions(),
          iOptions: IOSOptions(accessibility: KeychainAccessibility.first_unlock),
        );

  static const String _keyMasterKey = 'master_key';
  static const String _keyLockType = 'lock_type'; // 'none', 'pin', 'password'
  static const String _keyLockHash = 'lock_hash'; // Hashed PIN/password
  static const String _keyLockSalt = 'lock_salt';
  static const String _keyBiometricsEnabled = 'biometrics_enabled';
  static const String _keyThemeMode = 'theme_mode';
  static const String _keyLanguage = 'language';
  static const String _keyAutoLockDuration = 'auto_lock_duration';
  static const String _keyScreenProtectionEnabled = 'screen_protection_enabled';
  static const String _keyTimeOffset = 'time_offset';

  Future<String?> _read(String key) => _storage.read(key: key);
  Future<void> _write(String key, String value) => _storage.write(key: key, value: value);
  Future<void> _delete(String key) => _storage.delete(key: key);

  // Master key management
  Future<String> getOrCreateMasterKey() async {
    String? key = await _read(_keyMasterKey);
    if (key == null) {
      // Generate a new 256-bit key (32 bytes) in hex format securely
      final random = Random.secure();
      final values = List<int>.generate(32, (_) => random.nextInt(256));
      key = sha256.convert(values).toString();
      await _write(_keyMasterKey, key);
    }
    return key;
  }

  // App lock configurations
  Future<String> getLockType() async => await _read(_keyLockType) ?? 'none';
  Future<void> setLockType(String type) async => await _write(_keyLockType, type);

  Future<bool> verifyLock(String input) async {
    final storedHash = await _read(_keyLockHash);
    final storedSalt = await _read(_keyLockSalt);
    if (storedHash == null || storedSalt == null) return false;

    final bytes = utf8.encode(input + storedSalt);
    final hash = sha256.convert(bytes).toString();
    return hash == storedHash;
  }

  Future<void> setLock(String input, String type) async {
    if (input.isEmpty) {
      await _delete(_keyLockHash);
      await _delete(_keyLockSalt);
      await setLockType('none');
      return;
    }
    final salt = DateTime.now().microsecondsSinceEpoch.toString();
    final bytes = utf8.encode(input + salt);
    final hash = sha256.convert(bytes).toString();
    await _write(_keyLockHash, hash);
    await _write(_keyLockSalt, salt);
    await setLockType(type);
  }

  // Biometrics
  Future<bool> getBiometricsEnabled() async {
    final val = await _read(_keyBiometricsEnabled);
    return val == 'true';
  }
  Future<void> setBiometricsEnabled(bool enabled) async {
    await _write(_keyBiometricsEnabled, enabled.toString());
  }

  // Settings
  Future<String> getThemeMode() async => await _read(_keyThemeMode) ?? 'system';
  Future<void> setThemeMode(String theme) async => await _write(_keyThemeMode, theme);

  Future<String> getLanguage() async => await _read(_keyLanguage) ?? 'en';
  Future<void> setLanguage(String lang) async => await _write(_keyLanguage, lang);

  Future<int> getAutoLockDuration() async {
    final val = await _read(_keyAutoLockDuration);
    return val != null ? int.parse(val) : 0; // 0 means Never
  }
  Future<void> setAutoLockDuration(int durationSeconds) async {
    await _write(_keyAutoLockDuration, durationSeconds.toString());
  }

  Future<bool> getScreenProtectionEnabled() async {
    final val = await _read(_keyScreenProtectionEnabled);
    return val == 'true';
  }
  Future<void> setScreenProtectionEnabled(bool enabled) async {
    await _write(_keyScreenProtectionEnabled, enabled.toString());
  }

  // Time offset in ms
  Future<int> getTimeOffset() async {
    final val = await _read(_keyTimeOffset);
    return val != null ? int.parse(val) : 0;
  }
  Future<void> setTimeOffset(int offsetMs) async {
    await _write(_keyTimeOffset, offsetMs.toString());
  }

  static const String _keyWebAccounts = 'web_accounts';
  Future<String?> getWebAccountsJson() async => await _read(_keyWebAccounts);
  Future<void> setWebAccountsJson(String json) async => await _write(_keyWebAccounts, json);

  // Complete data reset
  Future<void> clearAll() async {
    await _storage.deleteAll();
  }
}
