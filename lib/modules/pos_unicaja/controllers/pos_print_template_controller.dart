import 'package:flutter/foundation.dart';
import 'package:framework_as/modules/pos_unicaja/models/pos_print_template.dart';
// ✅ Importamos DAO y DB
import '../data/database/app_database.dart';
import '../data/database/print_template_dao.dart';

class PosPrintTemplateController extends ChangeNotifier {
  PosPrintTemplate _template = PosPrintTemplate.defaults();
  bool _loaded = false;

  PosPrintTemplate get template => _template;
  bool get loaded => _loaded;

  /// Carga la configuración desde SQLite
  Future<void> load() async {
    if (_loaded) return;

    try {
      // Aseguramos que la DB esté lista (por si se llama desde main o login)
      // Nota: Si ya hiciste login, AppDatabase.db ya está lista.
      // Si esto falla es porque se llamó antes de iniciar sesión.
      
      final saved = await PrintTemplateDao.instance.get();
      
      if (saved != null) {
        _template = saved;
      } else {
        _template = PosPrintTemplate.defaults();
      }
      
    } catch (e) {
      if (kDebugMode) print('Error cargando plantilla ticket SQL: $e');
      _template = PosPrintTemplate.defaults();
    } finally {
      _loaded = true;
      notifyListeners();
    }
  }

  /// Guarda cambios en SQLite
  Future<void> save() async {
    try {
      await PrintTemplateDao.instance.save(_template);
    } catch (e) {
      if (kDebugMode) print('Error guardando plantilla ticket SQL: $e');
    }
  }

  Future<void> update(PosPrintTemplate newTemplate) async {
    _template = newTemplate;
    notifyListeners();
    await save();
  }

  /// Helper estático para leer config rápido (ej: al imprimir)
  static Future<PosPrintTemplate> loadOnce() async {
    try {
      final saved = await PrintTemplateDao.instance.get();
      return saved ?? PosPrintTemplate.defaults();
    } catch (_) {
      return PosPrintTemplate.defaults();
    }
  }
}