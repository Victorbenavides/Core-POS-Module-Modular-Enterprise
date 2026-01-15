import 'dart:convert';
import 'package:sqflite/sqflite.dart';
import '../../promotions/pos_discount.dart';
import 'app_database.dart';

class DiscountsDao {
  DiscountsDao._();
  static final DiscountsDao instance = DiscountsDao._();

  Future<void> upsert(PosDiscount d) async {
    final db = AppDatabase.db;
    final jsonString = jsonEncode(d.toJson());

    await db.insert(
      'discounts',
      {
        'id': d.id,
        'productId': d.productId,
        'department': d.department,
        'enabled': d.enabled ? 1 : 0,
        'startsAtMs': d.startsAt?.millisecondsSinceEpoch,
        'endsAtMs': d.endsAt?.millisecondsSinceEpoch,
        'json': jsonString,
      },
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }

  Future<List<PosDiscount>> getAll() async {
    final db = AppDatabase.db;
    final rows = await db.query('discounts');

    if (rows.isEmpty) return [];

    return rows.map((e) {
      final raw = (e['json'] as String?) ?? '{}';
      return PosDiscount.fromJson(jsonDecode(raw) as Map<String, dynamic>);
    }).toList();
  }

  Future<void> delete(String id) async {
    final db = AppDatabase.db;
    await db.delete('discounts', where: 'id = ?', whereArgs: [id]);
  }
}