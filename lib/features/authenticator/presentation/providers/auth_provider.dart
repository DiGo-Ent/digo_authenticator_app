import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:local_auth/local_auth.dart';
import '../../../../core/di/di.dart';
import '../../../../core/security/secure_storage_service.dart';

class AuthState {
  final bool isLocked;
  final String lockType; // 'none', 'pin', 'password'
  final bool isPinSetupCompleted;
  final int remainingAttempts;

  AuthState({
    required this.isLocked,
    required this.lockType,
    required this.isPinSetupCompleted,
    required this.remainingAttempts,
  });

  AuthState copyWith({
    bool? isLocked,
    String? lockType,
    bool? isPinSetupCompleted,
    int? remainingAttempts,
  }) {
    return AuthState(
      isLocked: isLocked ?? this.isLocked,
      lockType: lockType ?? this.lockType,
      isPinSetupCompleted: isPinSetupCompleted ?? this.isPinSetupCompleted,
      remainingAttempts: remainingAttempts ?? this.remainingAttempts,
    );
  }
}

class AuthNotifier extends StateNotifier<AuthState> {
  final SecureStorageService _secureStorage;
  final LocalAuthentication _localAuth = LocalAuthentication();
  DateTime? _pausedTime;

  AuthNotifier(this._secureStorage)
      : super(AuthState(
          isLocked: true,
          lockType: 'none',
          isPinSetupCompleted: false,
          remainingAttempts: 5,
        )) {
    checkInitialLock();
  }

  Future<void> checkInitialLock() async {
    final lockType = await _secureStorage.getLockType();
    state = AuthState(
      isLocked: lockType != 'none',
      lockType: lockType,
      isPinSetupCompleted: lockType != 'none',
      remainingAttempts: 5,
    );
  }

  Future<bool> authenticateWithCredential(String credential) async {
    final isValid = await _secureStorage.verifyLock(credential);
    if (isValid) {
      state = state.copyWith(isLocked: false, remainingAttempts: 5);
      return true;
    } else {
      state = state.copyWith(remainingAttempts: state.remainingAttempts - 1);
      return false;
    }
  }

  Future<void> setupCredential(String credential, String type) async {
    await _secureStorage.setLock(credential, type);
    state = state.copyWith(
      isLocked: false,
      lockType: type,
      isPinSetupCompleted: credential.isNotEmpty,
    );
  }

  Future<void> removeCredential() async {
    await _secureStorage.setLock('', 'none');
    state = state.copyWith(
      isLocked: false,
      lockType: 'none',
      isPinSetupCompleted: false,
    );
  }

  Future<bool> authenticateBiometrically(String localizedReason) async {
    final bioEnabled = await _secureStorage.getBiometricsEnabled();
    if (!bioEnabled) return false;

    final canAuthenticate = await _localAuth.canCheckBiometrics || await _localAuth.isDeviceSupported();
    if (!canAuthenticate) return false;

    try {
      final success = await _localAuth.authenticate(
        localizedReason: localizedReason,
        biometricOnly: true,
        persistAcrossBackgrounding: true,
      );
      if (success) {
        state = state.copyWith(isLocked: false);
        return true;
      }
    } catch (_) {}
    return false;
  }

  void handleAppPaused() {
    _pausedTime = DateTime.now();
  }

  Future<void> handleAppResumed(int autoLockDurationSeconds) async {
    if (state.lockType == 'none') return;
    if (autoLockDurationSeconds == 0) return; // 0 is Never

    if (_pausedTime != null) {
      final secondsPassed = DateTime.now().difference(_pausedTime!).inSeconds;
      if (secondsPassed >= autoLockDurationSeconds) {
        state = state.copyWith(isLocked: true);
      }
      _pausedTime = null;
    }
  }

  void lock() {
    if (state.lockType != 'none') {
      state = state.copyWith(isLocked: true);
    }
  }
}

final authProvider = StateNotifierProvider<AuthNotifier, AuthState>((ref) {
  return AuthNotifier(getIt<SecureStorageService>());
});
