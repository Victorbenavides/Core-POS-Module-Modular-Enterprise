import 'dart:convert';
import 'package:sqflite/sqflite.dart';
import '../../customers/pos_customer.dart';
import 'app_database.dart';

class CustomersDao {
  CustomersDao._();
  static final CustomersDao instance = CustomersDao._();

  Future<void> upsert(PosCustomer c) async {
    final db = AppDatabase.db;
    final jsonString = jsonEncode(c.toJson());

    await db.insert(
      'customers',
      {
        'id': c.id,
        'name': c.name,
        'phone': c.phone,
        'notes': c.notes,
        'creditLimit': c.creditLimit,
        'creditUsed': c.creditUsed,
        'enabled': c.enabled ? 1 : 0,
        'createdAtMs': c.createdAt.millisecondsSinceEpoch,
        'updatedAtMs': c.updatedAt.millisecondsSinceEpoch,
        'json': jsonString,
      },
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }

  Future<List<PosCustomer>> getAll() async {
    final db = AppDatabase.db;
    // Ordenados por nombre alfabéticamente
    final rows = await db.query('customers', orderBy: 'name ASC');

    if (rows.isEmpty) return [];

    return rows.map((e) {
      final raw = (e['json'] as String?) ?? '{}';
      return PosCustomer.fromJson(jsonDecode(raw) as Map<String, dynamic>);
    }).toList();
  }

  Future<void> delete(String id) async {
    final db = AppDatabase.db;
    await db.delete('customers', where: 'id = ?', whereArgs: [id]);
  }
}