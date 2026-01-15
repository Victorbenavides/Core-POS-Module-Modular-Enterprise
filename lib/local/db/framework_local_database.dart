import 'package:sqflite/sqflite.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

import '../customer_local_paths.dart';

class FrameworkLocalDatabase {
  FrameworkLocalDatabase._();
  static final FrameworkLocalDatabase instance =
      FrameworkLocalDatabase._();

  Database? _db;
  String? _currentCustomer;

  /// Abre (o crea) la DB local del framework para un cliente
  Future<Database> openForCustomer(String customerCode) async {
    if (_db != null && _currentCustomer == customerCode) {
      return _db!;
    }

    // Si hay otra DB abierta, cerramos
    if (_db != null) {
      await _db!.close();
      _db = null;
      _currentCustomer = null;
    }

    // Path dinámico por cliente
    final path = await CustomerLocalPaths.instance
        .frameworkDbPath(customerCode);

    _db = await openDatabase(
      path,
      version: 1,
      onCreate: _onCreate,
    );

    _currentCustomer = customerCode;
    return _db!;
  }

  Database get db {
    if (_db == null) {
      throw StateError(
        'FrameworkLocalDatabase no inicializada. '
        'Llama openForCustomer() primero.',
      );
    }
    return _db!;
  }

  // ========================
  // SCHEMA
  // ========================

  Future<void> _onCreate(Database db, int version) async {
    // Usuarios locales (login offline)
    await db.execute('''
      CREATE TABLE users_local (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        username TEXT NOT NULL UNIQUE,
        password_hash TEXT NOT NULL,
        role TEXT NOT NULL,
        active INTEGER NOT NULL DEFAULT 1
      );
    ''');

    // Cache de licencias
    await db.execute('''
      CREATE TABLE license_cache (
        module TEXT PRIMARY KEY,
        expires_at INTEGER NOT NULL,
        last_sync INTEGER NOT NULL,
        status TEXT NOT NULL
      );
    ''');

    // Metadata local
    await db.execute('''
      CREATE TABLE meta (
        key TEXT PRIMARY KEY,
        value TEXT
      );
    ''');

    // Guardamos versión local
    await db.insert('meta', {
      'key': 'schema_version',
      'value': version.toString(),
    });
  }

  // ========================
  // HELPERS (opcionales)
  // ========================

  Future<void> clearAll() async {
    await db.delete('users_local');
    await db.delete('license_cache');
    await db.delete('meta');
  }

  Future<void> setMeta(String key, String value) async {
  await db.insert(
    'meta',
    {'key': key, 'value': value},
    conflictAlgorithm: ConflictAlgorithm.replace,
  );
}

Future<String?> getMeta(String key) async {
  final rows = await db.query(
    'meta',
    where: 'key = ?',
    whereArgs: [key],
    limit: 1,
  );
  if (rows.isEmpty) return null;
  return (rows.first['value'] as String?)?.toString();
}  
}
