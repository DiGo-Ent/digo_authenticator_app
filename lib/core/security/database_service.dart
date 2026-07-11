import 'package:flutter/foundation.dart';
import 'dart:io';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

class DatabaseService {
  Database? _db;

  Future<Database?> get database async {
    if (kIsWeb) return null;
    if (_db != null) return _db!;
    _db = await _initDb();
    return _db!;
  }

  Future<Database> _initDb() async {
    // If running on desktop (Windows, Linux), initialize sqflite FFI
    if (!kIsWeb && (Platform.isWindows || Platform.isLinux)) {
      sqfliteFfiInit();
      databaseFactory = databaseFactoryFfi;
    }
    
    final dbDir = await getApplicationDocumentsDirectory();
    final dbPath = p.join(dbDir.path, 'authenticator.db');

    return await openDatabase(
      dbPath,
      version: 1,
      onCreate: (db, version) async {
        await db.execute('''
          CREATE TABLE accounts (
            id TEXT PRIMARY KEY,
            issuer TEXT,
            account_name TEXT,
            encrypted_secret TEXT,
            algorithm TEXT,
            digits INTEGER,
            period INTEGER,
            type TEXT,
            counter INTEGER,
            encrypted_notes TEXT,
            is_favorite INTEGER,
            group_name TEXT,
            sort_order INTEGER
          )
        ''');
      },
    );
  }
}
