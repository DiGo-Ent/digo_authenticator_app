import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../core/di/di.dart';
import '../../../../core/security/secure_storage_service.dart';
import 'package:screen_protector/screen_protector.dart';

class SettingsState {
  final ThemeMode themeMode;
  final Locale locale;
  final bool biometricLockEnabled;
  final bool screenProtectionEnabled;
  final int autoLockDuration;
  final int timeOffsetMs;

  SettingsState({
    required this.themeMode,
    required this.locale,
    required this.biometricLockEnabled,
    required this.screenProtectionEnabled,
    required this.autoLockDuration,
    required this.timeOffsetMs,
  });

  SettingsState copyWith({
    ThemeMode? themeMode,
    Locale? locale,
    bool? biometricLockEnabled,
    bool? screenProtectionEnabled,
    int? autoLockDuration,
    int? timeOffsetMs,
  }) {
    return SettingsState(
      themeMode: themeMode ?? this.themeMode,
      locale: locale ?? this.locale,
      biometricLockEnabled: biometricLockEnabled ?? this.biometricLockEnabled,
      screenProtectionEnabled: screenProtectionEnabled ?? this.screenProtectionEnabled,
      autoLockDuration: autoLockDuration ?? this.autoLockDuration,
      timeOffsetMs: timeOffsetMs ?? this.timeOffsetMs,
    );
  }
}

class SettingsNotifier extends StateNotifier<SettingsState> {
  final SecureStorageService _secureStorage;

  SettingsNotifier(this._secureStorage)
      : super(SettingsState(
          themeMode: ThemeMode.system,
          locale: const Locale('en'),
          biometricLockEnabled: false,
          screenProtectionEnabled: false,
          autoLockDuration: 0,
          timeOffsetMs: 0,
        )) {
    loadSettings();
  }

  Future<void> loadSettings() async {
    final themeStr = await _secureStorage.getThemeMode();
    final langStr = await _secureStorage.getLanguage();
    final bioEnabled = await _secureStorage.getBiometricsEnabled();
    final screenProt = await _secureStorage.getScreenProtectionEnabled();
    final autoLockSec = await _secureStorage.getAutoLockDuration();
    final timeOff = await _secureStorage.getTimeOffset();

    ThemeMode mode;
    switch (themeStr) {
      case 'light':
        mode = ThemeMode.light;
        break;
      case 'dark':
        mode = ThemeMode.dark;
        break;
      case 'system':
      default:
        mode = ThemeMode.system;
        break;
    }

    state = SettingsState(
      themeMode: mode,
      locale: Locale(langStr),
      biometricLockEnabled: bioEnabled,
      screenProtectionEnabled: screenProt,
      autoLockDuration: autoLockSec,
      timeOffsetMs: timeOff,
    );

    // Apply screen protection setting on load
    await applyScreenProtection(screenProt);
  }

  Future<void> applyScreenProtection(bool enable) async {
    try {
      if (enable) {
        await ScreenProtector.preventScreenshotOn();
      } else {
        await ScreenProtector.preventScreenshotOff();
      }
    } catch (e) {
      debugPrint('Screen protector error: $e');
    }
  }

  Future<void> setThemeMode(ThemeMode mode) async {
    String themeStr = 'system';
    if (mode == ThemeMode.light) themeStr = 'light';
    if (mode == ThemeMode.dark) themeStr = 'dark';

    await _secureStorage.setThemeMode(themeStr);
    state = state.copyWith(themeMode: mode);
  }

  Future<void> setLanguage(Locale locale) async {
    await _secureStorage.setLanguage(locale.languageCode);
    state = state.copyWith(locale: locale);
  }

  Future<void> setBiometricsEnabled(bool enabled) async {
    await _secureStorage.setBiometricsEnabled(enabled);
    state = state.copyWith(biometricLockEnabled: enabled);
  }

  Future<void> setScreenProtectionEnabled(bool enabled) async {
    await _secureStorage.setScreenProtectionEnabled(enabled);
    state = state.copyWith(screenProtectionEnabled: enabled);
    await applyScreenProtection(enabled);
  }

  Future<void> setAutoLockDuration(int seconds) async {
    await _secureStorage.setAutoLockDuration(seconds);
    state = state.copyWith(autoLockDuration: seconds);
  }

  Future<void> setTimeOffset(int offsetMs) async {
    await _secureStorage.setTimeOffset(offsetMs);
    state = state.copyWith(timeOffsetMs: offsetMs);
  }
}

final settingsProvider = StateNotifierProvider<SettingsNotifier, SettingsState>((ref) {
  return SettingsNotifier(getIt<SecureStorageService>());
});
