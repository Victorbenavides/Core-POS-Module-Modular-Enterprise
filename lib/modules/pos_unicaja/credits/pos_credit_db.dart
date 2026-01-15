import 'package:sqflite/sqflite.dart';

class PosCreditDb {
  static Database? _db;

  static Future<Database> db() async {
    if (_db != null) return _db!;
    final path = '${await getDatabasesPath()}/pos_unicaja_credit.db';

    _db = await openDatabase(
      path,
      version: 1,
      onCreate: (db, _) async => _ensureTables(db),
      onOpen: (db) async => _ensureTables(db),
    );

    return _db!;
  }

  static Future<void> _ensureTables(Database db) async {
    await db.execute('''
      CREATE TABLE IF NOT EXISTS customers (
        id TEXT PRIMARY KEY,
        name TEXT NOT NULL,
        phone TEXT,
        email TEXT,
        address TEXT,
        notes TEXT,
        discount REAL NOT NULL DEFAULT 0,
        credit_limit REAL NOT NULL DEFAULT 0,
        created_at INTEGER NOT NULL
      );
    ''');

    await db.execute('''
      CREATE TABLE IF NOT EXISTS credit_debts (
        id TEXT PRIMARY KEY,
        sale_id TEXT,
        customer_id TEXT NOT NULL,
        cashier_id TEXT,
        created_at INTEGER NOT NULL,
        original_amount REAL NOT NULL,
        remaining_amount REAL NOT NULL,
        status TEXT NOT NULL, -- open | paid | cancelled
        payload_json TEXT
      );
    ''');

    await db.execute('''
      CREATE TABLE IF NOT EXISTS credit_payments (
        id TEXT PRIMARY KEY,
        customer_id TEXT NOT NULL,
        cashier_id TEXT,
        created_at INTEGER NOT NULL,
        amount REAL NOT NULL,
        method TEXT NOT NULL, -- cash | card | transfer
        note TEXT
      );
    ''');
  }
}
