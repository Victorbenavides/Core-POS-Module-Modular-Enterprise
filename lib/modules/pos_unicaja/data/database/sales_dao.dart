// lib/modules/pos_unicaja/data/database/sales_dao.dart
import 'dart:convert';
import 'package:sqflite/sqflite.dart';

import '../../models/sale.dart';
import 'app_database.dart';

class SalesDao {
  SalesDao._();
  static final SalesDao instance = SalesDao._();

  Future<void> upsert(Sale sale) async {
    final db = AppDatabase.db;
    await db.insert(
      'sales',
      {
        'id': sale.id,
        'createdAtMs': sale.createdAt.millisecondsSinceEpoch,
        'cashierId': sale.cashierId,
        'paymentMethod': sale.paymentMethod,
        'customerId': sale.customerId,
        'total': sale.total,
        'json': jsonEncode(sale.toJson()),
      },
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }

  Future<List<Sale>> getAll({int? limit}) async {
    final db = AppDatabase.db;
    final rows = await db.query(
      'sales',
      orderBy: 'createdAtMs DESC',
      limit: limit,
    );

    return rows.map((e) {
      final raw = (e['json'] as String?) ?? '{}';
      return Sale.fromJson(jsonDecode(raw) as Map<String, dynamic>);
    }).toList();
  }

  Future<List<Sale>> getInRange(DateTime from, DateTime to, {String? cashierId}) async {
    final db = AppDatabase.db;

    final fromMs = from.millisecondsSinceEpoch;
    final toMs = to.millisecondsSinceEpoch;

    final where = StringBuffer('createdAtMs BETWEEN ? AND ?');
    final args = <Object>[fromMs, toMs];

    if (cashierId != null && cashierId.trim().isNotEmpty) {
      where.write(' AND cashierId = ?');
      args.add(cashierId.trim());
    }

    final rows = await db.query(
      'sales',
      where: where.toString(),
      whereArgs: args,
      orderBy: 'createdAtMs ASC',
    );

    return rows.map((e) {
      final raw = (e['json'] as String?) ?? '{}';
      return Sale.fromJson(jsonDecode(raw) as Map<String, dynamic>);
    }).toList();
  }

  Future<List<Sale>> getForDay(DateTime day, {String? cashierId}) async {
    final start = DateTime(day.year, day.month, day.day);
    final end = DateTime(day.year, day.month, day.day, 23, 59, 59, 999);
    return getInRange(start, end, cashierId: cashierId);
  }
}
