import 'dart:convert';
import 'package:sqflite/sqflite.dart';
import '../../promotions/pos_promotion.dart';
import 'app_database.dart';

class PromotionsDao {
  PromotionsDao._();
  static final PromotionsDao instance = PromotionsDao._();

  Future<void> upsert(PosPromotion p) async {
    final db = AppDatabase.db;
    final jsonString = jsonEncode(p.toJson());

    await db.insert(
      'promotions',
      {
        'id': p.id,
        'productId': p.productId,
        'enabled': p.enabled ? 1 : 0,
        // Guardamos fechas en milisegundos para consultas rápidas si se requiere
        'startsAtMs': p.startsAt?.millisecondsSinceEpoch,
        'endsAtMs': p.endsAt?.millisecondsSinceEpoch,
        'json': jsonString,
      },
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }

  Future<List<PosPromotion>> getAll() async {
    final db = AppDatabase.db;
    // Ordenamos por fecha de creación (necesitamos parsearla del json o confiar en el insert order)
    // Para simpleza, traemos todo y el controller ya ordena en memoria.
    final rows = await db.query('promotions');

    if (rows.isEmpty) return [];

    return rows.map((e) {
      final raw = (e['json'] as String?) ?? '{}';
      return PosPromotion.fromJson(jsonDecode(raw) as Map<String, dynamic>);
    }).toList();
  }

  Future<void> delete(String id) async {
    final db = AppDatabase.db;
    await db.delete('promotions', where: 'id = ?', whereArgs: [id]);
  }
}