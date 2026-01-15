// lib/modules/pos_unicaja/data/database/cash_sessions_dao.dart
import 'dart:convert';

import 'package:sqflite/sqflite.dart';

import 'app_database.dart';
import '../../models/cash_session.dart';

class CashSessionsDao {
  CashSessionsDao._();
  static final CashSessionsDao instance = CashSessionsDao._();

  Map<String, Object?> _toRow(CashSession s) {
    return {
      'id': s.id,
      'cashierId': s.cashierId,
      'openedAtMs': s.openedAt.millisecondsSinceEpoch,
      'closedAtMs': s.closedAt?.millisecondsSinceEpoch,
      'openingAmount': s.openingAmount,
      'salesTotal': s.salesTotal,
      'cancelledTotal': s.cancelledTotal,
      'isOpen': s.isOpen ? 1 : 0,
      'json': jsonEncode(s.toJson()),
    };
  }

  CashSession _fromRow(Map<String, Object?> row) {
    final raw = (row['json'] as String?) ?? '';
    if (raw.trim().isNotEmpty) {
      return CashSession.fromJson(jsonDecode(raw) as Map<String, dynamic>);
    }

    // Fallback si por alguna razón no hubiera json
    return CashSession.fromJson({
      'id': row['id'],
      'cashierId': row['cashierId'],
      'openedAtMs': row['openedAtMs'],
      'closedAtMs': row['closedAtMs'],
      'openingAmount': row['openingAmount'],
      'salesTotal': row['salesTotal'],
      'cancelledTotal': row['cancelledTotal'],
      'isOpen': row['isOpen'],
    });
  }

  Future<void> upsert(CashSession s) async {
    final db = AppDatabase.db;
    await db.insert(
      'cash_sessions',
      _toRow(s),
      conflictAlgorithm: ConflictAlgorithm.replace, // ✅ ya no marca error
    );
  }

  Future<CashSession?> getById(String id) async {
    final db = AppDatabase.db;
    final rows = await db.query(
      'cash_sessions',
      where: 'id = ?',
      whereArgs: [id],
      limit: 1,
    );
    if (rows.isEmpty) return null;
    return _fromRow(rows.first);
  }

  Future<List<CashSession>> getAll({int? limit}) async {
    final db = AppDatabase.db;
    final rows = await db.query(
      'cash_sessions',
      orderBy: 'openedAtMs DESC',
      limit: limit,
    );
    return rows.map(_fromRow).toList();
  }

  Future<List<CashSession>> getClosedForDay(DateTime day, {String? cashierId}) async {
    final db = AppDatabase.db;
    final from = DateTime(day.year, day.month, day.day);
    final to = DateTime(day.year, day.month, day.day, 23, 59, 59, 999);

    final where = StringBuffer('isOpen = 0 AND openedAtMs BETWEEN ? AND ?');
    final args = <Object?>[
      from.millisecondsSinceEpoch,
      to.millisecondsSinceEpoch,
    ];

    final cid = (cashierId ?? '').trim();
    if (cid.isNotEmpty) {
      where.write(' AND cashierId = ?');
      args.add(cid);
    }

    final rows = await db.query(
      'cash_sessions',
      where: where.toString(),
      whereArgs: args,
      orderBy: 'openedAtMs DESC',
    );
    return rows.map(_fromRow).toList();
  }

  Future<CashSession?> getOpenSession({required String cashierId}) async {
    final db = AppDatabase.db;
    final rows = await db.query(
      'cash_sessions',
      where: 'isOpen = 1 AND cashierId = ?',
      whereArgs: [cashierId],
      orderBy: 'openedAtMs DESC',
      limit: 1,
    );
    if (rows.isEmpty) return null;
    return _fromRow(rows.first);
  }

  Future<void> closeSession(String sessionId, {DateTime? closedAt}) async {
    final existing = await getById(sessionId);
    if (existing == null) return;

    final updated = existing.copyWith(
      isOpen: false,
      closedAt: closedAt ?? DateTime.now(),
    );

    await upsert(updated);
  }

  Future<void> delete(String id) async {
    final db = AppDatabase.db;
    await db.delete('cash_sessions', where: 'id = ?', whereArgs: [id]);
  }
}
