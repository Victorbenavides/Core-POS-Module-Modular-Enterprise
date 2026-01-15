import 'dart:convert';
import 'package:crypto/crypto.dart';
import 'package:sqflite/sqflite.dart';

import 'package:framework_as/local/db/framework_local_database.dart';
import 'package:framework_as/core/licenses/license_status.dart';
import 'auth_service.dart';

class LocalAuthService {
  static final LocalAuthService instance = LocalAuthService._();
  LocalAuthService._();

  Future<AuthResult?> loginOffline({
    required String customerCode,
    required String username,
    required String password,
  }) async {
    print("🧪 [OFFLINE] loginOffline customer=$customerCode user=$username");

    final db =
        await FrameworkLocalDatabase.instance.openForCustomer(customerCode);

    final rows = await db.query(
      'users_local',
      where: 'username = ? AND active = 1',
      whereArgs: [username],
      limit: 1,
    );

    print("🧪 [OFFLINE] users_local rows=${rows.length}");
    if (rows.isEmpty) return null;

    final row = rows.first;
    final inputHash = _hash(password);

    if (row['password_hash'] != inputHash) return null;

    final modules = await _loadCachedModules(db);

    return AuthResult(
      customer: customerCode,
      modules: modules,
      defaultModule: modules.isNotEmpty ? modules.first : null,
    );
  }

  Future<List<String>> _loadCachedModules(Database db) async {
    final rows = await db.query(
      'license_cache',
      where: 'status IN (?, ?)',
      whereArgs: [
        LicenseStatus.active.name,
        LicenseStatus.grace.name,
      ],
    );

    return rows
        .map((e) => e['module'].toString())
        .where((m) => m.isNotEmpty)
        .toList();
  }

  String _hash(String value) {
    return sha256.convert(utf8.encode(value)).toString();
  }
}
