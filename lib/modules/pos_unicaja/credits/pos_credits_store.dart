import 'dart:convert';
import 'dart:io';
import 'package:path_provider/path_provider.dart';
import 'pos_credit_models.dart';

class PosCreditsStore {
  static const _fileName = 'pos_credits.json';

  static Future<File> _file() async {
    final dir = await getApplicationSupportDirectory();
    return File('${dir.path}/$_fileName');
  }

  static Future<({List<PosCreditEntry> entries, List<PosCreditPayment> payments})> load() async {
    try {
      final f = await _file();
      if (!await f.exists()) return (entries: <PosCreditEntry>[], payments: <PosCreditPayment>[]);

      final raw = await f.readAsString();
      if (raw.trim().isEmpty) return (entries: <PosCreditEntry>[], payments: <PosCreditPayment>[]);

      final decoded = jsonDecode(raw);
      if (decoded is! Map) return (entries: <PosCreditEntry>[], payments: <PosCreditPayment>[]);

      final map = Map<String, dynamic>.from(decoded);

      final entries = ((map['entries'] as List?) ?? [])
          .whereType<Map>()
          .map((m) => PosCreditEntry.fromJson(Map<String, dynamic>.from(m)))
          .toList();

      final payments = ((map['payments'] as List?) ?? [])
          .whereType<Map>()
          .map((m) => PosCreditPayment.fromJson(Map<String, dynamic>.from(m)))
          .toList();

      return (entries: entries, payments: payments);
    } catch (_) {
      return (entries: <PosCreditEntry>[], payments: <PosCreditPayment>[]);
    }
  }

  static Future<void> save({
    required List<PosCreditEntry> entries,
    required List<PosCreditPayment> payments,
  }) async {
    final f = await _file();
    final tmp = File('${f.path}.tmp');

    final payload = {
      'entries': entries.map((e) => e.toJson()).toList(),
      'payments': payments.map((p) => p.toJson()).toList(),
    };

    final raw = const JsonEncoder.withIndent('  ').convert(payload);

    await tmp.writeAsString(raw);
    if (await f.exists()) await f.delete();
    await tmp.rename(f.path);
  }
}
