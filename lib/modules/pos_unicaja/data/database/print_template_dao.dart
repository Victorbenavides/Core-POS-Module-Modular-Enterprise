import 'dart:convert';
import 'package:sqflite/sqflite.dart';
import 'package:framework_as/modules/pos_unicaja/models/pos_print_template.dart';
import 'app_database.dart';

class PrintTemplateDao {
  PrintTemplateDao._();
  static final PrintTemplateDao instance = PrintTemplateDao._();

  static const _singleId = 'config';

  Future<void> save(PosPrintTemplate template) async {
    final db = AppDatabase.db;
    final jsonString = jsonEncode(template.toJson());

    await db.insert(
      'print_template',
      {
        'id': _singleId,
        'json': jsonString,
      },
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }

  Future<PosPrintTemplate?> get() async {
    final db = AppDatabase.db;
    final rows = await db.query(
      'print_template',
      where: 'id = ?',
      whereArgs: [_singleId],
      limit: 1,
    );

    if (rows.isEmpty) return null;

    final raw = rows.first['json'] as String;
    return PosPrintTemplate.fromJson(jsonDecode(raw));
  }
}