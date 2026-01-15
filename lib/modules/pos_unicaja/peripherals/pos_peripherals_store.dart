// lib/modules/pos_unicaja/peripherals/pos_peripherals_store.dart
import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';

import 'pos_peripherals_settings.dart';

class PosPeripheralsStore {
  static const String _kKey = 'pos_peripherals_settings_v1';

  static Future<PosPeripheralsSettings> load() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_kKey);
    if (raw == null || raw.trim().isEmpty) {
      return PosPeripheralsSettings.defaults();
    }

    try {
      final map = jsonDecode(raw) as Map<String, dynamic>;
      return PosPeripheralsSettings.fromJson(map);
    } catch (_) {
      return PosPeripheralsSettings.defaults();
    }
  }

  static Future<void> save(PosPeripheralsSettings settings) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_kKey, jsonEncode(settings.toJson()));
  }
}
