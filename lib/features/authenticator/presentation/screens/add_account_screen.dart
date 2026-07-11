import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../core/localization/app_localizations.dart';
import '../../../../core/security/otp_service.dart';
import '../../domain/models/otp_account.dart';
import '../providers/authenticator_provider.dart';

class AddAccountScreen extends ConsumerStatefulWidget {
  const AddAccountScreen({super.key});

  @override
  ConsumerState<AddAccountScreen> createState() => _AddAccountScreenState();
}

class _AddAccountScreenState extends ConsumerState<AddAccountScreen> {
  final _formKey = GlobalKey<FormState>();
  final _issuerController = TextEditingController();
  final _accountNameController = TextEditingController();
  final _secretController = TextEditingController();
  final _counterController = TextEditingController(text: '0');
  final _notesController = TextEditingController();
  final _groupController = TextEditingController();

  String _type = 'totp';
  String _algorithm = 'SHA1';
  int _digits = 6;
  int _period = 30;

  @override
  void dispose() {
    _issuerController.dispose();
    _accountNameController.dispose();
    _secretController.dispose();
    _counterController.dispose();
    _notesController.dispose();
    _groupController.dispose();
    super.dispose();
  }

  void _submitForm() {
    if (!_formKey.currentState!.validate()) return;

    final localizations = AppLocalizations.of(context);
    final secret = _secretController.text.trim();

    if (!OtpService.isValidBase32(secret)) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(localizations.translate('invalid_qr')),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }

    final newAccount = OtpAccount(
      id: '${DateTime.now().microsecondsSinceEpoch}_${secret.hashCode}',
      issuer: _issuerController.text.trim(),
      accountName: _accountNameController.text.trim(),
      secret: secret,
      algorithm: _algorithm,
      digits: _digits,
      period: _period,
      type: _type,
      counter: int.tryParse(_counterController.text.trim()) ?? 0,
      notes: _notesController.text.trim(),
      isFavorite: false,
      groupName: _groupController.text.trim(),
      sortOrder: ref.read(authenticatorProvider).accounts.length,
    );

    ref.read(authenticatorProvider.notifier).addAccount(newAccount);

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('${newAccount.issuer} added successfully'),
        backgroundColor: Colors.green,
      ),
    );
    Navigator.pop(context);
  }

  @override
  Widget build(BuildContext context) {
    final localizations = AppLocalizations.of(context);

    return Scaffold(
      appBar: AppBar(
        title: Text(localizations.translate('manual_entry')),
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
                // Issuer
                TextFormField(
                  controller: _issuerController,
                  decoration: InputDecoration(
                    labelText: localizations.translate('issuer'),
                    prefixIcon: const Icon(Icons.business_outlined),
                  ),
                  validator: (value) {
                    if (value == null || value.trim().isEmpty) {
                      return 'Issuer is required';
                    }
                    return null;
                  },
                ),
                const SizedBox(height: 16),

                // Account Name
                TextFormField(
                  controller: _accountNameController,
                  decoration: InputDecoration(
                    labelText: localizations.translate('account_name'),
                    prefixIcon: const Icon(Icons.person_outline_rounded),
                  ),
                  validator: (value) {
                    if (value == null || value.trim().isEmpty) {
                      return 'Account name is required';
                    }
                    return null;
                  },
                ),
                const SizedBox(height: 16),

                // Secret Key
                TextFormField(
                  controller: _secretController,
                  decoration: InputDecoration(
                    labelText: localizations.translate('secret_key'),
                    prefixIcon: const Icon(Icons.vpn_key_outlined),
                  ),
                  validator: (value) {
                    if (value == null || value.trim().isEmpty) {
                      return 'Secret key is required';
                    }
                    if (!OtpService.isValidBase32(value.trim())) {
                      return 'Invalid Base32 secret key';
                    }
                    return null;
                  },
                ),
                const SizedBox(height: 16),

                // Group (Optional)
                TextFormField(
                  controller: _groupController,
                  decoration: InputDecoration(
                    labelText: localizations.translate('group_name'),
                    prefixIcon: const Icon(Icons.label_outline_rounded),
                  ),
                ),
                const SizedBox(height: 16),

                // Notes (Optional, Encrypted)
                TextFormField(
                  controller: _notesController,
                  maxLines: 2,
                  decoration: InputDecoration(
                    labelText: localizations.translate('notes'),
                    prefixIcon: const Icon(Icons.sticky_note_2_outlined),
                  ),
                ),
                const SizedBox(height: 24),

                // Dropdowns Grid
                Card(
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'OTP Settings',
                          style: Theme.of(context).textTheme.titleSmall?.copyWith(
                                fontWeight: FontWeight.bold,
                              ),
                        ),
                        const SizedBox(height: 16),
                        // Row 1: Type & Algorithm
                        Row(
                          children: [
                            Expanded(
                              child: DropdownButtonFormField<String>(
                                initialValue: _type,
                                decoration: const InputDecoration(labelText: 'Type'),
                                items: const [
                                  DropdownMenuItem(value: 'totp', child: Text('TOTP (Time-based)')),
                                  DropdownMenuItem(value: 'hotp', child: Text('HOTP (Counter-based)')),
                                ],
                                onChanged: (val) {
                                  if (val != null) {
                                    setState(() {
                                      _type = val;
                                    });
                                  }
                                },
                              ),
                            ),
                            const SizedBox(width: 16),
                            Expanded(
                              child: DropdownButtonFormField<String>(
                                initialValue: _algorithm,
                                decoration: InputDecoration(labelText: localizations.translate('algorithm')),
                                items: const [
                                  DropdownMenuItem(value: 'SHA1', child: Text('SHA-1')),
                                  DropdownMenuItem(value: 'SHA256', child: Text('SHA-256')),
                                  DropdownMenuItem(value: 'SHA512', child: Text('SHA-512')),
                                ],
                                onChanged: (val) {
                                  if (val != null) {
                                    setState(() {
                                      _algorithm = val;
                                    });
                                  }
                                },
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 16),

                        // Row 2: Digits & Period/Counter
                        Row(
                          children: [
                            Expanded(
                              child: DropdownButtonFormField<int>(
                                initialValue: _digits,
                                decoration: InputDecoration(labelText: localizations.translate('digits')),
                                items: const [
                                  DropdownMenuItem(value: 6, child: Text('6 Digits')),
                                  DropdownMenuItem(value: 8, child: Text('8 Digits')),
                                ],
                                onChanged: (val) {
                                  if (val != null) {
                                    setState(() {
                                      _digits = val;
                                    });
                                  }
                                },
                              ),
                            ),
                            const SizedBox(width: 16),
                            Expanded(
                              child: _type == 'totp'
                                  ? DropdownButtonFormField<int>(
                                      initialValue: _period,
                                      decoration: InputDecoration(labelText: localizations.translate('period')),
                                      items: const [
                                        DropdownMenuItem(value: 15, child: Text('15 Secs')),
                                        DropdownMenuItem(value: 30, child: Text('30 Secs')),
                                        DropdownMenuItem(value: 60, child: Text('60 Secs')),
                                      ],
                                      onChanged: (val) {
                                        if (val != null) {
                                          setState(() {
                                            _period = val;
                                          });
                                        }
                                      },
                                    )
                                  : TextFormField(
                                      controller: _counterController,
                                      decoration: InputDecoration(labelText: localizations.translate('counter')),
                                      keyboardType: TextInputType.number,
                                      validator: (value) {
                                        if (_type == 'hotp' && (value == null || int.tryParse(value) == null)) {
                                          return 'Must be an integer';
                                        }
                                        return null;
                                      },
                                    ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 32),

                // Save button
                ElevatedButton(
                  onPressed: _submitForm,
                  child: Text(localizations.translate('save')),
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
