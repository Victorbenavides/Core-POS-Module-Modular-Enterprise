import 'dart:convert';
import 'package:crypto/crypto.dart';
import 'package:sqflite/sqflite.dart';

import 'db/framework_local_database.dart';
import 'package:framework_as/core/licenses/license_evaluator.dart';
import 'package:framework_as/core/licenses/license_status.dart';

class FrameworkBootstrapService {
  FrameworkBootstrapService._();
  static final FrameworkBootstrapService instance =
      FrameworkBootstrapService._();

  /// Se ejecuta SOLO después de un login ONLINE exitoso
  Future<void> bootstrapAfterOnlineLogin({
    required String customerCode,
    required String username,
    required String plainPassword,
    required List<LicenseSnapshot> licenses,
    String role = 'admin',
  }) async {
    final db =
        await FrameworkLocalDatabase.instance.openForCustomer(customerCode);

    // ============================================================
    // 🔑 ASEGURAR USUARIO LOCAL (NUNCA SE PIERDE)
    // ============================================================
    if (username.isNotEmpty) {
      final passwordHash = plainPassword.isNotEmpty
          ? _hashPassword(plainPassword)
          : await _getExistingPasswordHash(db, username);

      if (passwordHash != null) {
        await db.insert(
          'users_local',
          {
            'username': username,
            'password_hash': passwordHash,
            'role': role,
            'active': 1,
          },
          conflictAlgorithm: ConflictAlgorithm.replace,
        );
      }
    }

    // ============================================================
    // 🔐 LICENCIAS (SIEMPRE SE SINCRONIZAN)
    // ============================================================
    await db.delete('license_cache');

    final now = DateTime.now();
    final nowMs = now.millisecondsSinceEpoch;

    for (final lic in licenses) {
      final status = LicenseEvaluator.evaluate(
        expiresAt: lic.expiresAt,
        now: now,
      );

      await db.insert(
        'license_cache',
        {
          'module': lic.module,
          'expires_at': lic.expiresAt.millisecondsSinceEpoch,
          'last_sync': nowMs,
          'status': status.name,
        },
        conflictAlgorithm: ConflictAlgorithm.replace,
      );
    }

    // ============================================================
    // 📌 METADATA
    // ============================================================
    await db.insert(
      'meta',
      {
        'key': 'last_online_sync',
        'value': now.toIso8601String(),
      },
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }

  // ============================================================
  // 🔍 OBTENER HASH EXISTENTE (PARA REBOOTSTRAP)
  // ============================================================
  Future<String?> _getExistingPasswordHash(
    Database db,
    String username,
  ) async {
    final rows = await db.query(
      'users_local',
      columns: ['password_hash'],
      where: 'username = ?',
      whereArgs: [username],
      limit: 1,
    );

    if (rows.isEmpty) return null;
    return rows.first['password_hash'] as String;
  }

  String _hashPassword(String password) {
    return sha256.convert(utf8.encode(password)).toString();
  }
}

/// Snapshot local de una licencia (desde backend online)
class LicenseSnapshot {
  final String module;
  final DateTime expiresAt;

  LicenseSnapshot({
    required this.module,
    required this.expiresAt,
  });
}
