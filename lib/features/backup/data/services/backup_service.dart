import 'dart:convert';
import 'dart:io';
import 'dart:math';
import 'package:file_picker/file_picker.dart';
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';
import '../../../../core/security/encryption_service.dart';
import '../../../authenticator/domain/models/otp_account.dart';

class BackupService {
  // Generate encrypted backup string
  static String exportBackup(List<OtpAccount> accounts, String password) {
    final List<Map<String, dynamic>> list = accounts.map((a) {
      return {
        'issuer': a.issuer,
        'account_name': a.accountName,
        'secret': a.secret,
        'algorithm': a.algorithm,
        'digits': a.digits,
        'period': a.period,
        'type': a.type,
        'counter': a.counter,
        'notes': a.notes,
        'is_favorite': a.isFavorite ? 1 : 0,
        'group_name': a.groupName,
        'sort_order': a.sortOrder,
      };
    }).toList();

    final payload = {
      'version': 1,
      'exported_at': DateTime.now().toIso8601String(),
      'accounts': list,
    };

    final plainTextJson = json.encode(payload);

    // Generate random 16-byte salt in hex format
    final random = Random.secure();
    final saltBytes = List<int>.generate(16, (_) => random.secure().nextInt(256));
    final saltHex = saltBytes.map((b) => b.toRadixString(16).padLeft(2, '0')).join();

    // Encrypt JSON with derived password key and salt
    final encryptedBase64 = EncryptionService.encryptWithPassword(plainTextJson, password, saltHex);

    // The output format: SALT_HEX:ENCRYPTED_BASE64
    return '$saltHex:$encryptedBase64';
  }

  // Decrypt and parse backup string
  static List<OtpAccount> importBackup(String backupContent, String password) {
    final parts = backupContent.trim().split(':');
    if (parts.length != 2) {
      throw const FormatException('Invalid backup file format');
    }

    final saltHex = parts[0];
    final encryptedBase64 = parts[1];

    final plainTextJson = EncryptionService.decryptWithPassword(encryptedBase64, password, saltHex);
    final payload = json.decode(plainTextJson) as Map<String, dynamic>;

    if (payload['version'] != 1) {
      throw const FormatException('Unsupported backup version');
    }

    final list = payload['accounts'] as List<dynamic>;
    final accounts = <OtpAccount>[];

    for (var i = 0; i < list.length; i++) {
      final map = list[i] as Map<String, dynamic>;
      accounts.add(OtpAccount(
        id: '${DateTime.now().microsecondsSinceEpoch}_$i',
        issuer: map['issuer'] as String? ?? 'Unknown',
        accountName: map['account_name'] as String? ?? 'Account',
        secret: map['secret'] as String,
        algorithm: map['algorithm'] as String? ?? 'SHA1',
        digits: map['digits'] as int? ?? 6,
        period: map['period'] as int? ?? 30,
        type: map['type'] as String? ?? 'totp',
        counter: map['counter'] as int? ?? 0,
        notes: map['notes'] as String? ?? '',
        isFavorite: (map['is_favorite'] as int? ?? 0) == 1,
        groupName: map['group_name'] as String? ?? '',
        sortOrder: map['sort_order'] as int? ?? 0,
      ));
    }

    return accounts;
  }

  // Helper to trigger file export sharing
  static Future<void> shareBackupFile(String content) async {
    final tempDir = await getTemporaryDirectory();
    final file = File('${tempDir.path}/digo_backup.authenticator');
    await file.writeAsString(content);
    await SharePlus.instance.share(
      ShareParams(
        files: [XFile(file.path)],
        subject: 'DiGo Authenticator Encrypted Backup',
      ),
    );
  }

  // Helper to select backup file from disk
  static Future<String?> pickBackupFile() async {
    final result = await FilePicker.platform.pickFiles();
    if (result != null && result.files.single.path != null) {
      final file = File(result.files.single.path!);
      return await file.readAsString();
    }
    return null;
  }
}
extension on Random {
  Random secure() => Random.secure();
}
