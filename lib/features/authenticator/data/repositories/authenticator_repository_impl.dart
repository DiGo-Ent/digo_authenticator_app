import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:sqflite/sqflite.dart';
import '../../domain/models/otp_account.dart';
import '../../domain/repositories/authenticator_repository.dart';
import '../../../../core/di/di.dart';
import '../../../../core/security/database_service.dart';
import '../../../../core/security/encryption_service.dart';
import '../../../../core/security/secure_storage_service.dart';

class AuthenticatorRepositoryImpl implements AuthenticatorRepository {
  final DatabaseService _dbService;
  final EncryptionService _encryptionService;

  AuthenticatorRepositoryImpl(this._dbService, this._encryptionService);

  // Web local storage helper to read accounts
  Future<List<OtpAccount>> _getWebAccounts() async {
    final secureStorage = getIt<SecureStorageService>();
    final jsonStr = await secureStorage.getWebAccountsJson();
    if (jsonStr == null || jsonStr.isEmpty) return [];
    
    try {
      final List<dynamic> list = json.decode(jsonStr);
      final accounts = <OtpAccount>[];
      for (var i = 0; i < list.length; i++) {
        final map = list[i] as Map<String, dynamic>;
        try {
          final encryptedSecret = map['encrypted_secret'] as String;
          final encryptedNotes = map['encrypted_notes'] as String? ?? '';
          
          final decryptedSecret = _encryptionService.decrypt(encryptedSecret);
          final decryptedNotes = encryptedNotes.isNotEmpty 
              ? _encryptionService.decrypt(encryptedNotes) 
              : '';
          
          accounts.add(OtpAccount.fromSqlMap(map, decryptedSecret, decryptedNotes));
        } catch (e) {
          debugPrint('Error decrypting web account at index $i: $e');
        }
      }
      return accounts;
    } catch (e) {
      debugPrint('Error parsing web accounts: $e');
      return [];
    }
  }

  // Web local storage helper to save all accounts
  Future<void> _saveAllWebAccounts(List<OtpAccount> accounts) async {
    final secureStorage = getIt<SecureStorageService>();
    final List<Map<String, dynamic>> list = [];
    for (final account in accounts) {
      final encryptedSecret = _encryptionService.encrypt(account.secret);
      final encryptedNotes = account.notes.isNotEmpty 
          ? _encryptionService.encrypt(account.notes) 
          : '';
      list.add(account.toSqlMap(encryptedSecret, encryptedNotes));
    }
    await secureStorage.setWebAccountsJson(json.encode(list));
  }

  @override
  Future<List<OtpAccount>> getAccounts() async {
    if (kIsWeb) {
      return await _getWebAccounts();
    }

    final db = await _dbService.database;
    if (db == null) return [];
    final List<Map<String, dynamic>> maps = await db.query('accounts', orderBy: 'sort_order ASC');
    
    final accounts = <OtpAccount>[];
    for (final map in maps) {
      try {
        final encryptedSecret = map['encrypted_secret'] as String;
        final encryptedNotes = map['encrypted_notes'] as String? ?? '';
        
        final decryptedSecret = _encryptionService.decrypt(encryptedSecret);
        final decryptedNotes = encryptedNotes.isNotEmpty 
            ? _encryptionService.decrypt(encryptedNotes) 
            : '';
        
        accounts.add(OtpAccount.fromSqlMap(map, decryptedSecret, decryptedNotes));
      } catch (e) {
        debugPrint('Error decrypting account: $e');
      }
    }
    return accounts;
  }

  @override
  Future<void> saveAccount(OtpAccount account) async {
    if (kIsWeb) {
      final accounts = await _getWebAccounts();
      final idx = accounts.indexWhere((a) => a.id == account.id);
      if (idx >= 0) {
        accounts[idx] = account;
      } else {
        accounts.add(account);
      }
      await _saveAllWebAccounts(accounts);
      return;
    }

    final db = await _dbService.database;
    if (db == null) return;
    final encryptedSecret = _encryptionService.encrypt(account.secret);
    final encryptedNotes = account.notes.isNotEmpty 
        ? _encryptionService.encrypt(account.notes) 
        : '';
        
    await db.insert(
      'accounts',
      account.toSqlMap(encryptedSecret, encryptedNotes),
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }

  @override
  Future<void> updateAccount(OtpAccount account) async {
    if (kIsWeb) {
      await saveAccount(account);
      return;
    }

    final db = await _dbService.database;
    if (db == null) return;
    final encryptedSecret = _encryptionService.encrypt(account.secret);
    final encryptedNotes = account.notes.isNotEmpty 
        ? _encryptionService.encrypt(account.notes) 
        : '';
        
    await db.update(
      'accounts',
      account.toSqlMap(encryptedSecret, encryptedNotes),
      where: 'id = ?',
      whereArgs: [account.id],
    );
  }

  @override
  Future<void> deleteAccount(String id) async {
    if (kIsWeb) {
      final accounts = await _getWebAccounts();
      accounts.removeWhere((a) => a.id == id);
      await _saveAllWebAccounts(accounts);
      return;
    }

    final db = await _dbService.database;
    if (db == null) return;
    await db.delete(
      'accounts',
      where: 'id = ?',
      whereArgs: [id],
    );
  }

  @override
  Future<void> updateSortOrders(List<OtpAccount> accounts) async {
    if (kIsWeb) {
      final updated = <OtpAccount>[];
      for (var i = 0; i < accounts.length; i++) {
        updated.add(accounts[i].copyWith(sortOrder: i));
      }
      await _saveAllWebAccounts(updated);
      return;
    }

    final db = await _dbService.database;
    if (db == null) return;
    final batch = db.batch();
    for (var i = 0; i < accounts.length; i++) {
      batch.update(
        'accounts',
        {'sort_order': i},
        where: 'id = ?',
        whereArgs: [accounts[i].id],
      );
    }
    await batch.commit(noResult: true);
  }
}
