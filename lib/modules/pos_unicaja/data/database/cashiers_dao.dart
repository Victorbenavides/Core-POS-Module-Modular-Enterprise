// lib/modules/pos_unicaja/data/database/cashiers_dao.dart
import 'package:sqflite/sqflite.dart';

import '../../models/cashier.dart';
import 'app_database.dart';

class CashiersDao {
  CashiersDao._();
  static final CashiersDao instance = CashiersDao._();

  Cashier _fromRow(Map<String, Object?> e) => Cashier.fromDbMap(e);

  Future<List<Cashier>> getAll() async {
    final db = AppDatabase.db;
    final rows = await db.query('cashiers');
    return rows.map(_fromRow).toList();
  }

  Future<void> upsert(Cashier c) async {
    final db = AppDatabase.db;
    await db.insert(
      'cashiers',
      c.toDbMap(),
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }

  Future<Cashier?> loginWithPin(String pin) async {
    final db = AppDatabase.db;
    final rows = await db.query(
      'cashiers',
      where: 'pin = ?',
      whereArgs: [pin],
      limit: 1,
    );
    if (rows.isEmpty) return null;
    return _fromRow(rows.first);
  }

  Future<void> delete(String id, {String? currentUserId}) async {
    final db = AppDatabase.db;

    if (id == 'root') {
      throw Exception("No se puede eliminar el admin raíz.");
    }

    await db.delete('cashiers', where: 'id = ?', whereArgs: [id]);
  }
}
