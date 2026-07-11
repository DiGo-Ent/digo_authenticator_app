import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:qr_flutter/qr_flutter.dart';
import '../../../../core/localization/app_localizations.dart';
import '../../domain/models/otp_account.dart';
import '../providers/authenticator_provider.dart';

class AccountDetailScreen extends ConsumerStatefulWidget {
  final String accountId;

  const AccountDetailScreen({super.key, required this.accountId});

  @override
  ConsumerState<AccountDetailScreen> createState() => _AccountDetailScreenState();
}

class _AccountDetailScreenState extends ConsumerState<AccountDetailScreen> {
  final _formKey = GlobalKey<FormState>();
  late TextEditingController _issuerController;
  late TextEditingController _nameController;
  late TextEditingController _groupController;
  late TextEditingController _notesController;
  bool _isInit = false;
  OtpAccount? _account;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (!_isInit) {
      final state = ref.watch(authenticatorProvider);
      _account = state.accounts.firstWhere((a) => a.id == widget.accountId);
      
      _issuerController = TextEditingController(text: _account?.issuer);
      _nameController = TextEditingController(text: _account?.accountName);
      _groupController = TextEditingController(text: _account?.groupName);
      _notesController = TextEditingController(text: _account?.notes);
      
      _isInit = true;
    }
  }

  @override
  void dispose() {
    _issuerController.dispose();
    _nameController.dispose();
    _groupController.dispose();
    _notesController.dispose();
    super.dispose();
  }

  void _saveChanges() {
    if (!_formKey.currentState!.validate() || _account == null) return;

    final updated = _account!.copyWith(
      issuer: _issuerController.text.trim(),
      accountName: _nameController.text.trim(),
      groupName: _groupController.text.trim(),
      notes: _notesController.text.trim(),
    );

    ref.read(authenticatorProvider.notifier).updateAccount(updated);

    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Account updated successfully')),
    );
    Navigator.pop(context);
  }

  void _deleteAccount(AppLocalizations localizations) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: Text(localizations.translate('delete_account')),
          content: Text(localizations.translate('delete_confirm')),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: Text(localizations.translate('cancel')),
            ),
            TextButton(
              style: TextButton.styleFrom(foregroundColor: Colors.red),
              onPressed: () => Navigator.pop(context, true),
              child: Text(localizations.translate('delete_account')),
            ),
          ],
        );
      },
    );

    if (confirm == true && _account != null) {
      ref.read(authenticatorProvider.notifier).deleteAccount(_account!.id);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Account deleted')),
      );
      Navigator.pop(context); // Close detail screen
    }
  }

  void _copyUri(AppLocalizations localizations) {
    if (_account == null) return;
    Clipboard.setData(ClipboardData(text: _account!.toUri()));
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(localizations.translate('copied_uri'))),
    );
  }

  @override
  Widget build(BuildContext context) {
    final localizations = AppLocalizations.of(context);
    if (_account == null) {
      return Scaffold(
        appBar: AppBar(),
        body: const Center(child: Text('Account not found')),
      );
    }

    final accountUri = _account!.toUri();

    return Scaffold(
      appBar: AppBar(
        title: Text(localizations.translate('edit_account')),
        actions: [
          IconButton(
            icon: Icon(_account!.isFavorite ? Icons.star_rounded : Icons.star_outline_rounded),
            color: _account!.isFavorite ? Colors.amber[700] : null,
            onPressed: () {
              ref.read(authenticatorProvider.notifier).toggleFavorite(_account!.id);
              setState(() {
                _account = _account!.copyWith(isFavorite: !_account!.isFavorite);
              });
            },
          ),
          IconButton(
            icon: const Icon(Icons.delete_outline_rounded),
            color: Colors.red,
            onPressed: () => _deleteAccount(localizations),
          ),
        ],
      ),
      body: Center(
        child: Container(
          constraints: const BoxConstraints(maxWidth: 600),
          child: SingleChildScrollView(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Form(
            key: _formKey,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                // Edit Fields
                TextFormField(
                  controller: _issuerController,
                  decoration: InputDecoration(
                    labelText: localizations.translate('issuer'),
                    prefixIcon: const Icon(Icons.business_outlined),
                  ),
                  validator: (value) => value == null || value.trim().isEmpty ? 'Required' : null,
                ),
                const SizedBox(height: 16),
                TextFormField(
                  controller: _nameController,
                  decoration: InputDecoration(
                    labelText: localizations.translate('account_name'),
                    prefixIcon: const Icon(Icons.person_outline_rounded),
                  ),
                  validator: (value) => value == null || value.trim().isEmpty ? 'Required' : null,
                ),
                const SizedBox(height: 16),
                TextFormField(
                  controller: _groupController,
                  decoration: InputDecoration(
                    labelText: localizations.translate('group_name'),
                    prefixIcon: const Icon(Icons.label_outline_rounded),
                  ),
                ),
                const SizedBox(height: 16),
                TextFormField(
                  controller: _notesController,
                  maxLines: 2,
                  decoration: InputDecoration(
                    labelText: localizations.translate('notes'),
                    prefixIcon: const Icon(Icons.sticky_note_2_outlined),
                  ),
                ),
                const SizedBox(height: 24),

                // Save Button
                ElevatedButton(
                  onPressed: _saveChanges,
                  child: Text(localizations.translate('save')),
                ),
                const SizedBox(height: 32),

                // Transfer QR Section
                Card(
                  child: Padding(
                    padding: const EdgeInsets.all(24),
                    child: Column(
                      children: [
                        Text(
                          localizations.translate('show_qr'),
                          style: Theme.of(context).textTheme.titleMedium?.copyWith(
                                fontWeight: FontWeight.bold,
                              ),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          'Scan this QR code using another authenticator to securely clone/transfer this account offline.',
                          textAlign: TextAlign.center,
                          style: Theme.of(context).textTheme.bodySmall?.copyWith(
                                color: Theme.of(context).colorScheme.onSurfaceVariant,
                              ),
                        ),
                        const SizedBox(height: 24),
                        Container(
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            color: Colors.white,
                            borderRadius: BorderRadius.circular(16),
                          ),
                          child: QrImageView(
                            data: accountUri,
                            version: QrVersions.auto,
                            size: 200.0,
                            gapless: false,
                          ),
                        ),
                        const SizedBox(height: 16),
                        OutlinedButton.icon(
                          onPressed: () => _copyUri(localizations),
                          icon: const Icon(Icons.copy_rounded),
                          label: Text(localizations.translate('copied_uri').replaceAll('clipboard', 'URI')),
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
  ),
);
  }
}
