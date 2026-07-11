import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../../core/localization/app_localizations.dart';
import '../../../authenticator/presentation/providers/auth_provider.dart';
import '../providers/settings_provider.dart';

class SettingsScreen extends ConsumerWidget {
  const SettingsScreen({super.key});

  Future<void> _syncTimeCorrection(BuildContext context, WidgetRef ref, AppLocalizations localizations) async {
    try {
      final startTime = DateTime.now().millisecondsSinceEpoch;
      
      // Perform a lightweight network HEAD request to fetch standard network time
      final client = HttpClient();
      client.connectionTimeout = const Duration(seconds: 5);
      final request = await client.headUrl(Uri.parse('https://www.google.com'));
      final response = await request.close();
      
      final serverDateStr = response.headers.value('date');
      if (serverDateStr == null) throw Exception('No date header returned');
      
      final serverTimeMs = HttpDate.parse(serverDateStr).millisecondsSinceEpoch;
      final endTime = DateTime.now().millisecondsSinceEpoch;
      
      // Approximate round-trip latency correction
      final latency = (endTime - startTime) ~/ 2;
      final correctedServerTimeMs = serverTimeMs + latency;
      
      final offsetMs = correctedServerTimeMs - endTime;
      
      await ref.read(settingsProvider.notifier).setTimeOffset(offsetMs);
      
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(localizations.translate(
              'time_sync_success',
              arguments: {'offset': offsetMs.toString()},
            )),
            backgroundColor: Colors.green,
          ),
        );
      }
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Time correction failed: Ensure you have an internet connection. ($e)'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  void _showAboutDialog(BuildContext context, AppLocalizations localizations) {
    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: Text(localizations.translate('about')),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              ClipRRect(
                borderRadius: BorderRadius.circular(16),
                child: Image.asset(
                  'assets/digo_logo.png',
                  height: 96,
                  width: 96,
                  fit: BoxFit.cover,
                ),
              ),
              const SizedBox(height: 16),
              Text(
                localizations.translate('about_text'),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 12),
              const Text('Version: 1.0.0 (Enterprise)'),
              const SizedBox(height: 8),
              const Text(
                'Powered by DiGo',
                style: TextStyle(fontWeight: FontWeight.w600, fontSize: 12),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('OK'),
            ),
          ],
        );
      },
    );
  }

  void _showPrivacyDialog(BuildContext context, AppLocalizations localizations) {
    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: Text(localizations.translate('privacy_policy')),
          content: Text(
            localizations.translate('privacy_text'),
            textAlign: TextAlign.center,
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Close'),
            ),
          ],
        );
      },
    );
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final settings = ref.watch(settingsProvider);
    final auth = ref.watch(authProvider);
    final localizations = AppLocalizations.of(context);

    return Scaffold(
      appBar: AppBar(
        title: Text(localizations.translate('settings')),
      ),
      body: Center(
        child: Container(
          constraints: const BoxConstraints(maxWidth: 600),
          child: ListView(
        children: [
          // Security Section
          _buildSectionHeader(context, 'Security'),
          
          // PIN setup/removal
          ListTile(
            leading: const Icon(Icons.pin_outlined),
            title: Text(auth.isPinSetupCompleted ? 'Change PIN Lock' : 'Setup PIN Lock'),
            subtitle: Text(auth.isPinSetupCompleted ? 'App is protected by PIN code' : 'Setup PIN to secure your accounts'),
            trailing: auth.isPinSetupCompleted
                ? IconButton(
                    icon: const Icon(Icons.delete_outline, color: Colors.red),
                    onPressed: () async {
                      final confirm = await showDialog<bool>(
                        context: context,
                        builder: (context) => AlertDialog(
                          title: const Text('Remove Lock'),
                          content: const Text('Are you sure you want to disable the PIN lock? Your data will be stored un-locked.'),
                          actions: [
                            TextButton(onPressed: () => Navigator.pop(context, false), child: Text(localizations.translate('cancel'))),
                            TextButton(onPressed: () => Navigator.pop(context, true), child: const Text('Remove')),
                          ],
                        ),
                      );
                      if (confirm == true) {
                        await ref.read(authProvider.notifier).removeCredential();
                        await ref.read(settingsProvider.notifier).setBiometricsEnabled(false);
                      }
                    },
                  )
                : const Icon(Icons.chevron_right_rounded),
            onTap: () {
              if (!auth.isPinSetupCompleted) {
                // Navigate to lock screen to trigger setup
                context.push('/lock');
              } else {
                // Allow resetting PIN by locking the app first to force re-authentication
                ref.read(authProvider.notifier).lock();
              }
            },
          ),

          // Biometrics lock switcher
          if (auth.isPinSetupCompleted)
            SwitchListTile(
              secondary: const Icon(Icons.fingerprint_rounded),
              title: Text(localizations.translate('biometrics')),
              value: settings.biometricLockEnabled,
              onChanged: (val) {
                ref.read(settingsProvider.notifier).setBiometricsEnabled(val);
              },
            ),

          // Screenshot protector switcher
          SwitchListTile(
            secondary: const Icon(Icons.screen_lock_portrait_rounded),
            title: Text(localizations.translate('screen_protection')),
            value: settings.screenProtectionEnabled,
            onChanged: (val) {
              ref.read(settingsProvider.notifier).setScreenProtectionEnabled(val);
            },
          ),

          // Auto-Lock Inactivity switcher
          if (auth.isPinSetupCompleted)
            ListTile(
              leading: const Icon(Icons.timer_outlined),
              title: Text(localizations.translate('auto_lock')),
              trailing: DropdownButton<int>(
                value: settings.autoLockDuration,
                underline: const SizedBox(),
                items: [
                  DropdownMenuItem(value: 0, child: Text(localizations.translate('never'))),
                  DropdownMenuItem(value: 30, child: Text(localizations.translate('sec_30'))),
                  DropdownMenuItem(value: 60, child: Text(localizations.translate('min_1'))),
                  DropdownMenuItem(value: 300, child: Text(localizations.translate('min_5'))),
                  DropdownMenuItem(value: 600, child: Text(localizations.translate('min_10'))),
                ],
                onChanged: (val) {
                  if (val != null) {
                    ref.read(settingsProvider.notifier).setAutoLockDuration(val);
                  }
                },
              ),
            ),
          
          const Divider(),

          // System Configurations Section
          _buildSectionHeader(context, 'System'),

          // Theme Selection
          ListTile(
            leading: const Icon(Icons.palette_outlined),
            title: Text(localizations.translate('theme')),
            trailing: DropdownButton<ThemeMode>(
              value: settings.themeMode,
              underline: const SizedBox(),
              items: [
                DropdownMenuItem(value: ThemeMode.light, child: Text(localizations.translate('light_mode'))),
                DropdownMenuItem(value: ThemeMode.dark, child: Text(localizations.translate('dark_mode'))),
                DropdownMenuItem(value: ThemeMode.system, child: Text(localizations.translate('system_mode'))),
              ],
              onChanged: (val) {
                if (val != null) {
                  ref.read(settingsProvider.notifier).setThemeMode(val);
                }
              },
            ),
          ),

          // Language Selection
          ListTile(
            leading: const Icon(Icons.language_rounded),
            title: Text(localizations.translate('language')),
            trailing: DropdownButton<Locale>(
              value: settings.locale.languageCode == 'hi' ? const Locale('hi') : const Locale('en'),
              underline: const SizedBox(),
              items: const [
                DropdownMenuItem(value: Locale('en'), child: Text('English')),
                DropdownMenuItem(value: Locale('hi'), child: Text('हिन्दी')),
              ],
              onChanged: (val) {
                if (val != null) {
                  ref.read(settingsProvider.notifier).setLanguage(val);
                }
              },
            ),
          ),

          // Time Correction Sync
          ListTile(
            leading: const Icon(Icons.sync_rounded),
            title: Text(localizations.translate('time_correction')),
            subtitle: Text('Current offset: ${settings.timeOffsetMs} ms'),
            trailing: OutlinedButton(
              onPressed: () => _syncTimeCorrection(context, ref, localizations),
              child: const Text('Sync Now'),
            ),
          ),

          // Backup and Restore Link
          ListTile(
            leading: const Icon(Icons.backup_outlined),
            title: const Text('Backup & Restore'),
            subtitle: const Text('Manage encrypted backup files'),
            trailing: const Icon(Icons.chevron_right_rounded),
            onTap: () => context.push('/backup'),
          ),

          const Divider(),

          // Info Section
          _buildSectionHeader(context, 'Info'),
          ListTile(
            leading: const Icon(Icons.info_outline_rounded),
            title: Text(localizations.translate('about')),
            onTap: () => _showAboutDialog(context, localizations),
          ),
          ListTile(
            leading: const Icon(Icons.privacy_tip_outlined),
            title: Text(localizations.translate('privacy_policy')),
            onTap: () => _showPrivacyDialog(context, localizations),
          ),
          const SizedBox(height: 24),
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
          const SizedBox(height: 24),
        ],
      ),
    ),
  ),
);
  }

  Widget _buildSectionHeader(BuildContext context, String title) {
    return Padding(
      padding: const EdgeInsets.only(left: 16, top: 16, bottom: 8),
      child: Text(
        title,
        style: Theme.of(context).textTheme.titleSmall?.copyWith(
              color: Theme.of(context).colorScheme.primary,
              fontWeight: FontWeight.bold,
            ),
      ),
    );
  }
}
