import 'dart:async';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../core/di/di.dart';
import '../../../../core/security/otp_service.dart';
import '../../domain/models/otp_account.dart';
import '../../domain/repositories/authenticator_repository.dart';
import '../../../settings/presentation/providers/settings_provider.dart';

class AuthenticatorState {
  final List<OtpAccount> accounts;
  final String searchQuery;
  final Map<String, String> currentOtps; // id -> OTP string
  final Map<String, double> otpProgress; // id -> progress fraction (0.0 to 1.0)
  final Map<String, int> otpSecondsRemaining; // id -> seconds remaining
  final bool isLoading;

  AuthenticatorState({
    required this.accounts,
    required this.searchQuery,
    required this.currentOtps,
    required this.otpProgress,
    required this.otpSecondsRemaining,
    required this.isLoading,
  });

  AuthenticatorState copyWith({
    List<OtpAccount>? accounts,
    String? searchQuery,
    Map<String, String>? currentOtps,
    Map<String, double>? otpProgress,
    Map<String, int>? otpSecondsRemaining,
    bool? isLoading,
  }) {
    return AuthenticatorState(
      accounts: accounts ?? this.accounts,
      searchQuery: searchQuery ?? this.searchQuery,
      currentOtps: currentOtps ?? this.currentOtps,
      otpProgress: otpProgress ?? this.otpProgress,
      otpSecondsRemaining: otpSecondsRemaining ?? this.otpSecondsRemaining,
      isLoading: isLoading ?? this.isLoading,
    );
  }
}

class AuthenticatorNotifier extends StateNotifier<AuthenticatorState> {
  final AuthenticatorRepository _repository;
  final Ref _ref;
  Timer? _ticker;
  final Map<String, int> _lastSteps = {};
  final Map<String, int> _lastCounters = {};

  AuthenticatorNotifier(this._repository, this._ref)
      : super(AuthenticatorState(
          accounts: [],
          searchQuery: '',
          currentOtps: {},
          otpProgress: {},
          otpSecondsRemaining: {},
          isLoading: true,
        )) {
    loadAccounts();
    _startTicker();
  }

  Future<void> loadAccounts() async {
    state = state.copyWith(isLoading: true);
    final accounts = await _repository.getAccounts();
    _lastSteps.clear();
    _lastCounters.clear();
    state = state.copyWith(accounts: accounts, isLoading: false);
    _calculateOtps();
  }

  void setSearchQuery(String query) {
    state = state.copyWith(searchQuery: query);
  }

  void _startTicker() {
    _ticker = Timer.periodic(const Duration(seconds: 1), (_) {
      _calculateOtps();
    });
  }

  void _calculateOtps() {
    if (state.accounts.isEmpty) return;

    final otps = Map<String, String>.from(state.currentOtps);
    final progress = <String, double>{};
    final remaining = <String, int>{};

    final timeOffsetMs = _ref.read(settingsProvider).timeOffsetMs;
    final nowMs = DateTime.now().millisecondsSinceEpoch;

    for (final account in state.accounts) {
      if (account.type == 'totp') {
        final correctedSec = (nowMs + timeOffsetMs) ~/ 1000;
        final step = correctedSec ~/ account.period;
        final elapsed = correctedSec % account.period;
        final rem = account.period - elapsed;
        final prog = rem / account.period;

        progress[account.id] = prog;
        remaining[account.id] = rem;

        // Only calculate TOTP if step changes or it is missing
        if (otps[account.id] == null || _lastSteps[account.id] != step) {
          try {
            final otp = OtpService.generateTotp(
              secret: account.secret,
              timeMs: nowMs,
              timeOffsetMs: timeOffsetMs,
              period: account.period,
              digits: account.digits,
              algorithm: account.algorithm,
            );
            otps[account.id] = otp;
            _lastSteps[account.id] = step;
          } catch (e) {
            otps[account.id] = '------';
          }
        }
      } else {
        // Only calculate HOTP if counter changes or it is missing
        if (otps[account.id] == null || _lastCounters[account.id] != account.counter) {
          try {
            final otp = OtpService.generateHotp(
              secret: account.secret,
              counter: account.counter,
              digits: account.digits,
              algorithm: account.algorithm,
            );
            otps[account.id] = otp;
            _lastCounters[account.id] = account.counter;
          } catch (e) {
            otps[account.id] = '------';
          }
        }
        progress[account.id] = 1.0;
        remaining[account.id] = 0;
      }
    }

    state = state.copyWith(
      currentOtps: otps,
      otpProgress: progress,
      otpSecondsRemaining: remaining,
    );
  }

  Future<void> addAccount(OtpAccount account) async {
    await _repository.saveAccount(account);
    await loadAccounts();
  }

  Future<void> updateAccount(OtpAccount account) async {
    await _repository.updateAccount(account);
    await loadAccounts();
  }

  Future<void> deleteAccount(String id) async {
    await _repository.deleteAccount(id);
    await loadAccounts();
  }

  Future<void> toggleFavorite(String id) async {
    final updated = state.accounts.map((a) {
      if (a.id == id) {
        final newAccount = a.copyWith(isFavorite: !a.isFavorite);
        _repository.updateAccount(newAccount);
        return newAccount;
      }
      return a;
    }).toList();
    state = state.copyWith(accounts: updated);
  }

  Future<void> incrementHotpCounter(String id) async {
    final updated = state.accounts.map((a) {
      if (a.id == id && a.type == 'hotp') {
        final newAccount = a.copyWith(counter: a.counter + 1);
        _repository.updateAccount(newAccount);
        return newAccount;
      }
      return a;
    }).toList();
    state = state.copyWith(accounts: updated);
    _calculateOtps();
  }

  Future<void> reorderAccounts(int oldIndex, int newIndex, {bool adjustForRemoval = true}) async {
    if (adjustForRemoval && oldIndex < newIndex) {
      newIndex -= 1;
    }
    final list = List<OtpAccount>.from(state.accounts);
    if (oldIndex >= 0 && oldIndex < list.length && newIndex >= 0 && newIndex <= list.length) {
      final item = list.removeAt(oldIndex);
      list.insert(newIndex, item);
      state = state.copyWith(accounts: list);
      await _repository.updateSortOrders(list);
    }
  }

  @override
  void dispose() {
    _ticker?.cancel();
    super.dispose();
  }
}

final authenticatorProvider = StateNotifierProvider<AuthenticatorNotifier, AuthenticatorState>((ref) {
  return AuthenticatorNotifier(getIt<AuthenticatorRepository>(), ref);
});
