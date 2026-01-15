// lib/modules/pos_unicaja/promotions/pos_discounts_store.dart
import 'dart:convert';
import 'dart:io';

import 'package:path_provider/path_provider.dart';
import 'pos_discount.dart';

class PosDiscountsStore {
  static const _fileName = 'pos_discounts.json';

  static Future<File> _file() async {
    final dir = await getApplicationSupportDirectory();
    return File('${dir.path}/$_fileName');
  }

  static Future<List<PosDiscount>> load() async {
    try {
      final f = await _file();
      if (!await f.exists()) return [];
      final raw = await f.readAsString();
      if (raw.trim().isEmpty) return [];
      final decoded = jsonDecode(raw);
      if (decoded is! List) return [];
      return decoded
          .whereType<Map>()
          .map((m) => PosDiscount.fromJson(Map<String, dynamic>.from(m)))
          .toList();
    } catch (_) {
      return [];
    }
  }

  static Future<void> save(List<PosDiscount> items) async {
    final f = await _file();
    final tmp = File('${f.path}.tmp');

    final data = items.map((e) => e.toJson()).toList();
    final raw = const JsonEncoder.withIndent('  ').convert(data);

    await tmp.writeAsString(raw);
    if (await f.exists()) await f.delete();
    await tmp.rename(f.path);
  }
}
