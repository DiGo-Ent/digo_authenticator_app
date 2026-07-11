import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../core/localization/app_localizations.dart';
import '../providers/auth_provider.dart';

class LockScreen extends ConsumerStatefulWidget {
  const LockScreen({super.key});

  @override
  ConsumerState<LockScreen> createState() => _LockScreenState();
}

class _LockScreenState extends ConsumerState<LockScreen> {
  final List<String> _pin = [];
  bool _isConfirming = false;
  String _firstPin = '';
  String _errorMessage = '';

  @override
  void initState() {
    super.initState();
    // Try biometrics on startup if enabled
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _triggerBiometrics();
    });
  }

  Future<void> _triggerBiometrics() async {
    final localizations = AppLocalizations.of(context);
    final authState = ref.read(authProvider);
    if (authState.isPinSetupCompleted && authState.isLocked) {
      await ref.read(authProvider.notifier).authenticateBiometrically(
        localizations.translate('biometric_prompt'),
      );
    }
  }

  void _onKeyPress(String key) {
    if (_pin.length >= 6) return;
    setState(() {
      _pin.add(key);
      _errorMessage = '';
    });
    if (_pin.length == 6) {
      _submitPin();
    }
  }

  void _onBackspace() {
    if (_pin.isEmpty) return;
    setState(() {
      _pin.removeLast();
    });
  }

  void _submitPin() async {
    final enteredPin = _pin.join();
    final authState = ref.read(authProvider);
    final localizations = AppLocalizations.of(context);

    if (!authState.isPinSetupCompleted) {
      // PIN Setup Mode
      if (!_isConfirming) {
        setState(() {
          _firstPin = enteredPin;
          _isConfirming = true;
          _pin.clear();
        });
      } else {
        if (enteredPin == _firstPin) {
          await ref.read(authProvider.notifier).setupCredential(enteredPin, 'pin');
        } else {
          setState(() {
            _errorMessage = localizations.translate('pins_do_not_match');
            _isConfirming = false;
            _firstPin = '';
            _pin.clear();
          });
        }
      }
    } else {
      // PIN Authentication Mode
      final success = await ref.read(authProvider.notifier).authenticateWithCredential(enteredPin);
      if (!success) {
        final currentAttempts = ref.read(authProvider).remainingAttempts;
        setState(() {
          _errorMessage = localizations.translate(
            'incorrect_pin',
            arguments: {'attempts': currentAttempts.toString()},
          );
          _pin.clear();
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final authState = ref.watch(authProvider);
    final localizations = AppLocalizations.of(context);

    String titleText;
    if (!authState.isPinSetupCompleted) {
      titleText = _isConfirming
          ? localizations.translate('confirm_pin')
          : localizations.translate('setup_pin');
    } else {
      titleText = localizations.translate('enter_pin');
    }

    return Scaffold(
      body: SafeArea(
        child: Stack(
          children: [
            // Main content
            Center(
              child: Container(
                constraints: const BoxConstraints(maxWidth: 400),
                child: Column(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const SizedBox(height: 20),
            // Header: Logo + Title
            Column(
              children: [
                ClipRRect(
                  borderRadius: BorderRadius.circular(28),
                  child: Image.asset(
                    'assets/digo_logo.png',
                    height: 140,
                    width: 140,
                    fit: BoxFit.cover,
                  ),
                ),
                const SizedBox(height: 16),
                Text(
                  titleText,
                  style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                        fontWeight: FontWeight.bold,
                      ),
                ),
                const SizedBox(height: 8),
                if (_errorMessage.isNotEmpty)
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 24),
                    child: Text(
                      _errorMessage,
                      style: const TextStyle(color: Colors.red, fontWeight: FontWeight.w500),
                      textAlign: TextAlign.center,
                    ),
                  ),
              ],
            ),

            // PIN Dots Indicator
            Column(
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: List.generate(
                    6,
                    (index) {
                      final active = index < _pin.length;
                      return Container(
                        margin: const EdgeInsets.symmetric(horizontal: 12),
                        width: 16,
                        height: 16,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: active
                              ? Theme.of(context).colorScheme.primary
                              : Theme.of(context).colorScheme.outlineVariant,
                        ),
                      );
                    },
                  ),
                ),
                const SizedBox(height: 10),
                if (!authState.isPinSetupCompleted)
                  Text(
                    _isConfirming
                        ? 'Re-enter your 6-digit PIN to confirm'
                        : 'Enter 6 digits to setup your PIN',
                    style: Theme.of(context).textTheme.bodySmall,
                  ),
                if (authState.isPinSetupCompleted)
                  Text(
                    'Enter 6 digits to unlock',
                    style: Theme.of(context).textTheme.bodySmall,
                  ),
              ],
            ),

            // Keypad
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 20),
              child: Column(
                children: [
                  for (var row = 0; row < 3; row++)
                    Padding(
                      padding: const EdgeInsets.only(bottom: 12),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                        children: [
                          for (var col = 1; col <= 3; col++)
                            _buildKeypadButton((row * 3 + col).toString()),
                        ],
                      ),
                    ),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                    children: [
                      // Bottom Left: Biometric trigger or empty
                      authState.isPinSetupCompleted
                          ? _buildIconButton(
                              Icons.fingerprint_rounded,
                              _triggerBiometrics,
                            )
                          : const SizedBox(width: 80, height: 80),
                      _buildKeypadButton('0'),
                      _buildIconButton(
                        Icons.backspace_outlined,
                        _onBackspace,
                      ),
                    ],
                  ),
                  const SizedBox(height: 20),
                  Center(
                    child: Text(
                      'Powered by DiGo',
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                            color: Theme.of(context).colorScheme.onSurfaceVariant.withValues(alpha: 0.6),
                            fontWeight: FontWeight.w500,
                            letterSpacing: 1.0,
                          ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    ),
            // Back button overlay (only during PIN setup, not during unlock)
            if (!authState.isPinSetupCompleted)
              Positioned(
                top: 8,
                left: 8,
                child: IconButton(
                  icon: Icon(
                    Icons.arrow_back_rounded,
                    color: Theme.of(context).colorScheme.onSurface,
                  ),
                  style: IconButton.styleFrom(
                    backgroundColor: Theme.of(context).colorScheme.surfaceContainerHighest.withValues(alpha: 0.6),
                  ),
                  onPressed: () {
                    // Skip PIN setup and go to home
                    ref.read(authProvider.notifier).setupCredential('', 'none');
                  },
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildKeypadButton(String text) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: () => _onKeyPress(text),
        borderRadius: BorderRadius.circular(40),
        child: Container(
          width: 80,
          height: 80,
          alignment: Alignment.center,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            border: Border.all(
              color: Theme.of(context).colorScheme.outlineVariant,
              width: 1,
            ),
          ),
          child: Text(
            text,
            style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                  fontWeight: FontWeight.w600,
                ),
          ),
        ),
      ),
    );
  }

  Widget _buildIconButton(IconData icon, VoidCallback onPressed) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onPressed,
        borderRadius: BorderRadius.circular(40),
        child: Container(
          width: 80,
          height: 80,
          alignment: Alignment.center,
          child: Icon(
            icon,
            size: 32,
            color: Theme.of(context).colorScheme.onSurface,
          ),
        ),
      ),
    );
  }
}
