import 'dart:convert';
import 'package:sqflite/sqflite.dart';
import '../../credits/pos_credit_models.dart';
import 'app_database.dart';

class CreditsDao {
  CreditsDao._();
  static final CreditsDao instance = CreditsDao._();

  // --- ENTRIES (Deudas) ---

  Future<void> upsertEntry(PosCreditEntry entry) async {
    final db = AppDatabase.db;
    await db.insert(
      'credit_entries',
      {
        'id': entry.id,
        'customerId': entry.customerId,
        'saleId': entry.saleId,
        'status': entry.status,
        'createdAtMs': entry.createdAt.millisecondsSinceEpoch,
        'json': jsonEncode(entry.toJson()),
      },
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }

  Future<List<PosCreditEntry>> getAllEntries() async {
    final db = AppDatabase.db;
    final rows = await db.query('credit_entries', orderBy: 'createdAtMs ASC');
    
    return rows.map((row) {
      final raw = row['json'] as String;
      return PosCreditEntry.fromJson(jsonDecode(raw));
    }).toList();
  }

  // --- PAYMENTS (Abonos) ---

  Future<void> upsertPayment(PosCreditPayment payment) async {
    final db = AppDatabase.db;
    await db.insert(
      'credit_payments',
      {
        'id': payment.id,
        'customerId': payment.customerId,
        'entryId': payment.entryId,
        'createdAtMs': payment.createdAt.millisecondsSinceEpoch,
        'json': jsonEncode(payment.toJson()),
      },
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }

  Future<List<PosCreditPayment>> getAllPayments() async {
    final db = AppDatabase.db;
    final rows = await db.query('credit_payments', orderBy: 'createdAtMs ASC');

    return rows.map((row) {
      final raw = row['json'] as String;
      return PosCreditPayment.fromJson(jsonDecode(raw));
    }).toList();
  }
}