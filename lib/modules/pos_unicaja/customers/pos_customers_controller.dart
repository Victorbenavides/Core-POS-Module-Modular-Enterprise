import 'package:flutter/foundation.dart';
import 'pos_customer.dart';
// Importamos el nuevo DAO y la base de datos
import '../data/database/app_database.dart';
import '../data/database/customers_dao.dart';

class PosCustomersController extends ChangeNotifier {
  PosCustomersController._();
  static final PosCustomersController instance = PosCustomersController._();

  bool _loaded = false;
  bool _loading = false;

  final List<PosCustomer> _items = [];
  List<PosCustomer> get customers => List.unmodifiable(_items);

  /// Carga inicial desde SQLite
  Future<void> ensureLoaded() async {
    if (_loaded || _loading) return;
    _loading = true;

    try {
      // Nos aseguramos que la DB esté lista (por si entras directo aquí)
      // Nota: Si ya se inició en main.dart, esto es rápido y seguro.
      // Si prefieres pasar el customerCode, deberías inyectarlo, 
      // pero normalmente AppDatabase.db ya está lista si el login pasó.
      
      final list = await CustomersDao.instance.getAll();
      _items
        ..clear()
        ..addAll(list);
        
    } catch (e) {
      if (kDebugMode) print("Error cargando clientes SQL: $e");
    } finally {
      _loaded = true;
      _loading = false;
      notifyListeners();
    }
  }

  PosCustomer? byId(String id) {
    for (final c in _items) {
      if (c.id == id) return c;
    }
    return null;
  }

  String? validate(PosCustomer c) {
    if (c.name.trim().isEmpty) return 'Nombre requerido.';
    if (c.creditLimit < 0) return 'El crédito no puede ser negativo.';
    if (c.creditUsed < 0) return 'La deuda no puede ser negativa.';
    return null;
  }

  Future<void> upsert(PosCustomer c) async {
    await ensureLoaded();
    final err = validate(c);
    if (err != null) throw Exception(err);

    // 1. Actualizar Memoria
    final idx = _items.indexWhere((x) => x.id == c.id);
    if (idx >= 0) {
      _items[idx] = c;
    } else {
      _items.add(c);
    }
    _items.sort((a, b) => a.name.toLowerCase().compareTo(b.name.toLowerCase()));
    notifyListeners();

    // 2. Persistir en SQLite
    await CustomersDao.instance.upsert(c);
  }

  Future<void> remove(String id) async {
    await ensureLoaded();
    
    // 1. Memoria
    _items.removeWhere((c) => c.id == id);
    notifyListeners();

    // 2. SQLite
    await CustomersDao.instance.delete(id);
  }

  Future<void> setEnabled(String id, bool enabled) async {
    await ensureLoaded();
    final idx = _items.indexWhere((c) => c.id == id);
    if (idx < 0) return;

    final now = DateTime.now();
    final updated = _items[idx].copyWith(enabled: enabled, updatedAt: now);
    
    // Actualizamos memoria y DB
    _items[idx] = updated;
    notifyListeners();
    
    await CustomersDao.instance.upsert(updated);
  }

  // ✅ Sube o baja deuda (fiado)
  Future<void> bumpDebt(String customerId, double delta) async {
    await ensureLoaded();
    final idx = _items.indexWhere((c) => c.id == customerId);
    if (idx < 0) return;

    final c = _items[idx];
    final next = (c.creditUsed + delta);
    final clamped = next < 0 ? 0.0 : next;

    final updated = c.copyWith(
      creditUsed: clamped,
      updatedAt: DateTime.now(),
    );

    // Actualizamos memoria y DB
    _items[idx] = updated;
    notifyListeners();

    await CustomersDao.instance.upsert(updated);
  }
}