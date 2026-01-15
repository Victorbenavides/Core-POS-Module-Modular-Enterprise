// lib/modules/pos_unicaja/promotions/pos_promotions_store.dart
import 'dart:convert';
import 'dart:io';

import 'package:path_provider/path_provider.dart';

import 'pos_promotion.dart';

class PosPromotionsStore {
  static const _fileName = 'pos_promotions.json';

  static Future<File> _file() async {
    final dir = await getApplicationSupportDirectory();
    final f = File('${dir.path}/$_fileName');
    return f;
  }

  static Future<List<PosPromotion>> load() async {
    try {
      final f = await _file();
      if (!await f.exists()) return [];
      final raw = await f.readAsString();
      if (raw.trim().isEmpty) return [];
      final decoded = jsonDecode(raw);
      if (decoded is! List) return [];
      return decoded
          .whereType<Map>()
          .map((m) => PosPromotion.fromJson(Map<String, dynamic>.from(m)))
          .toList();
    } catch (_) {
      return [];
    }
  }

  static Future<void> save(List<PosPromotion> promotions) async {
    final f = await _file();
    final tmp = File('${f.path}.tmp');

    final data = promotions.map((p) => p.toJson()).toList();
    final raw = const JsonEncoder.withIndent('  ').convert(data);

    await tmp.writeAsString(raw);
    if (await f.exists()) {
      await f.delete();
    }
    await tmp.rename(f.path);
  }
}
