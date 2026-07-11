import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../core/localization/app_localizations.dart';
import '../../../authenticator/presentation/providers/authenticator_provider.dart';
import '../../data/services/backup_service.dart';

class BackupScreen extends ConsumerStatefulWidget {
  const BackupScreen({super.key});

  @override
  ConsumerState<BackupScreen> createState() => _BackupScreenState();
}

class _BackupScreenState extends ConsumerState<BackupScreen> {
  final _exportPasswordController = TextEditingController();
  final _importPasswordController = TextEditingController();
  bool _exportPasswordVisible = false;
  bool _importPasswordVisible = false;
  bool _isExporting = false;
  bool _isImporting = false;

  @override
  void dispose() {
    _exportPasswordController.dispose();
    _importPasswordController.dispose();
    super.dispose();
  }

  void _handleExport(AppLocalizations localizations) async {
    final password = _exportPasswordController.text.trim();
    if (password.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please enter a password to secure your backup')),
      );
      return;
    }

    setState(() {
      _isExporting = true;
    });

    try {
      final accounts = ref.read(authenticatorProvider).accounts;
      if (accounts.isEmpty) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('No accounts available to backup')),
        );
        if (mounted) {
          setState(() {
            _isExporting = false;
          });
        }
        return;
      }

      final backupStr = BackupService.exportBackup(accounts, password);
      await BackupService.shareBackupFile(backupStr);

      if (!mounted) return;
      _exportPasswordController.clear();
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Backup file generated and shared successfully')),
      );
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Export failed: $e')),
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          _isExporting = false;
        });
      }
    }
  }

  void _handleImport(AppLocalizations localizations) async {
    setState(() {
      _isImporting = true;
    });

    try {
      final backupContent = await BackupService.pickBackupFile();
      if (backupContent == null || backupContent.isEmpty) {
        if (mounted) {
          setState(() {
            _isImporting = false;
          });
        }
        return;
      }

      // Prompt for password
      if (!mounted) return;
      final password = await _showPasswordPromptDialog(localizations);
      if (password == null || password.isEmpty) {
        if (mounted) {
          setState(() {
            _isImporting = false;
          });
        }
        return;
      }

      final importedAccounts = BackupService.importBackup(backupContent, password);

      // Confirm import
      if (!mounted) return;
      final confirm = await _showConfirmImportDialog(importedAccounts, localizations);
      if (confirm == true) {
        final notifier = ref.read(authenticatorProvider.notifier);
        for (final account in importedAccounts) {
          await notifier.addAccount(account);
        }
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text(localizations.translate('import_success'))),
          );
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(localizations.translate('import_failed')),
            backgroundColor: Colors.red,
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          _isImporting = false;
        });
      }
    }
  }

  Future<String?> _showPasswordPromptDialog(AppLocalizations localizations) {
    _importPasswordController.clear();
    return showDialog<String>(
      context: context,
      barrierDismissible: false,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setState) {
            return AlertDialog(
              title: Text(localizations.translate('enter_backup_password')),
              content: TextField(
                controller: _importPasswordController,
                obscureText: !_importPasswordVisible,
                decoration: InputDecoration(
                  labelText: localizations.translate('backup_password'),
                  suffixIcon: IconButton(
                    icon: Icon(_importPasswordVisible ? Icons.visibility : Icons.visibility_off),
                    onPressed: () {
                      setState(() {
                        _importPasswordVisible = !_importPasswordVisible;
                      });
                    },
                  ),
                ),
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(context, null),
                  child: Text(localizations.translate('cancel')),
                ),
                TextButton(
                  onPressed: () => Navigator.pop(context, _importPasswordController.text),
                  child: Text(localizations.translate('save').replaceAll('Save', 'Decrypt')),
                ),
              ],
            );
          },
        );
      },
    );
  }

  Future<bool?> _showConfirmImportDialog(List<dynamic> accounts, AppLocalizations localizations) {
    return showDialog<bool>(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Text('Confirm Import'),
          content: SizedBox(
            width: double.maxFinite,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Found ${accounts.length} accounts in backup:'),
                const SizedBox(height: 12),
                Flexible(
                  child: ListView.builder(
                    shrinkWrap: true,
                    itemCount: accounts.length,
                    itemBuilder: (context, idx) {
                      final acc = accounts[idx];
                      return ListTile(
                        dense: true,
                        title: Text(acc.issuer),
                        subtitle: Text(acc.accountName),
                      );
                    },
                  ),
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: Text(localizations.translate('cancel')),
            ),
            TextButton(
              onPressed: () => Navigator.pop(context, true),
              child: const Text('Import All'),
            ),
          ],
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final localizations = AppLocalizations.of(context);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Backup & Restore'),
      ),
      body: Center(
        child: Container(
          constraints: const BoxConstraints(maxWidth: 600),
          child: SingleChildScrollView(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // Info Card
              Card(
                color: Theme.of(context).colorScheme.primaryContainer,
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Row(
                    children: [
                      Icon(
                        Icons.security_rounded,
                        size: 36,
                        color: Theme.of(context).colorScheme.onPrimaryContainer,
                      ),
                      const SizedBox(width: 16),
                      Expanded(
                        child: Text(
                          'Your backup files are secured using AES-256 password-based encryption. Keep your password safe: there is no way to recover your data without it.',
                          style: TextStyle(
                            color: Theme.of(context).colorScheme.onPrimaryContainer,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 24),

              // Export Card
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(24),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Text(
                        localizations.translate('export_backup'),
                        style: Theme.of(context).textTheme.titleLarge?.copyWith(
                              fontWeight: FontWeight.bold,
                            ),
                      ),
                      const SizedBox(height: 12),
                      Text(
                        'Encrypt all MFA accounts and share/export the secure file to local storage or external apps.',
                        style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                              color: Theme.of(context).colorScheme.onSurfaceVariant,
                            ),
                      ),
                      const SizedBox(height: 20),
                      TextField(
                        controller: _exportPasswordController,
                        obscureText: !_exportPasswordVisible,
                        decoration: InputDecoration(
                          labelText: localizations.translate('backup_password'),
                          hintText: localizations.translate('backup_password_hint'),
                          suffixIcon: IconButton(
                            icon: Icon(_exportPasswordVisible ? Icons.visibility : Icons.visibility_off),
                            onPressed: () {
                              setState(() {
                                _exportPasswordVisible = !_exportPasswordVisible;
                              });
                            },
                          ),
                        ),
                      ),
                      const SizedBox(height: 20),
                      ElevatedButton.icon(
                        onPressed: _isExporting ? null : () => _handleExport(localizations),
                        icon: _isExporting
                            ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2))
                            : const Icon(Icons.download_rounded),
                        label: const Text('Export Now'),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 24),

              // Import Card
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(24),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Text(
                        localizations.translate('import_backup'),
                        style: Theme.of(context).textTheme.titleLarge?.copyWith(
                              fontWeight: FontWeight.bold,
                            ),
                      ),
                      const SizedBox(height: 12),
                      Text(
                        'Select an encrypted authenticator backup file from storage and decrypt it using your password.',
                        style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                              color: Theme.of(context).colorScheme.onSurfaceVariant,
                            ),
                      ),
                      const SizedBox(height: 24),
                      OutlinedButton.icon(
                        onPressed: _isImporting ? null : () => _handleImport(localizations),
                        icon: _isImporting
                            ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2))
                            : const Icon(Icons.upload_rounded),
                        label: const Text('Import Backup File'),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    ),
  ),
);
  }
}
