///
///import 'dart:convert';
///import 'dart:io';
///import 'package:path_provider/path_provider.dart';
///import 'pos_customer.dart';

///class PosCustomersStore {
///  static const _fileName = 'pos_customers.json';

///  static Future<File> _file() async {
///    final dir = await getApplicationSupportDirectory();
///    return File('${dir.path}/$_fileName');
///  }

///  static Future<List<PosCustomer>> load() async {
///    try {
///      final f = await _file();
///      if (!await f.exists()) return [];
///      final raw = await f.readAsString();
///      if (raw.trim().isEmpty) return [];
///      final decoded = jsonDecode(raw);
///      if (decoded is! List) return [];
///      return decoded
///          .whereType<Map>()
///          .map((m) => PosCustomer.fromJson(Map<String, dynamic>.from(m)))
///          .toList();
///    } catch (_) {
///      return [];
///    }
///  }
///
///  static Future<void> save(List<PosCustomer> items) async {
///    final f = await _file();
///    final tmp = File('${f.path}.tmp');
///    final data = items.map((c) => c.toJson()).toList();
///    final raw = const JsonEncoder.withIndent('  ').convert(data);
///
///    await tmp.writeAsString(raw);
///    if (await f.exists()) await f.delete();
///    await tmp.rename(f.path);
///  }
///}
///