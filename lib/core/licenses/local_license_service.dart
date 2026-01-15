import 'package:sqflite/sqflite.dart';
import 'license_status.dart';

class LocalLicenseService {
  final Database db;
  LocalLicenseService(this.db);

  Future<LicenseStatus?> getStatus(String module) async {
    final res = await db.query(
      'licenses_cache',
      where: 'module = ?',
      whereArgs: [module],
      limit: 1,
    );

    if (res.isEmpty) return null;

    return LicenseStatus.values.firstWhere(
      (e) => e.name == res.first['status'],
    );
  }
}
