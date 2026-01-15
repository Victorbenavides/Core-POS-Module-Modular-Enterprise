import 'package:flutter/foundation.dart';
import 'pos_discount.dart';
// ✅ Usamos DAO y DB en lugar del Store
import '../data/database/discounts_dao.dart';

class PosDiscountsController extends ChangeNotifier {
  PosDiscountsController._();
  static final PosDiscountsController instance = PosDiscountsController._();

  bool _loaded = false;
  bool _loading = false;

  final List<PosDiscount> _items = [];

  List<PosDiscount> get discounts => List.unmodifiable(_items);
  bool get isLoaded => _loaded;

  Future<void> ensureLoaded() async {
    if (_loaded || _loading) return;
    _loading = true;

    try {
      final list = await DiscountsDao.instance.getAll();
      _items
        ..clear()
        ..addAll(list);

      await _autoDisableExpiredIfNeeded();
      
    } catch (e) {
      if (kDebugMode) print("Error cargando descuentos SQL: $e");
    } finally {
      _loaded = true;
      _loading = false;
      notifyListeners();
    }
  }

  PosDiscount _normalize(PosDiscount d) {
    final now = DateTime.now();
    if (d.enabled && d.endsAt != null && now.isAfter(d.endsAt!)) {
      return d.copyWith(enabled: false);
    }
    return d;
  }

  Future<void> _autoDisableExpiredIfNeeded() async {
    final now = DateTime.now();
    for (int i = 0; i < _items.length; i++) {
      final d = _items[i];
      if (d.enabled && d.endsAt != null && now.isAfter(d.endsAt!)) {
        _items[i] = d.copyWith(enabled: false);
        // Actualizamos en DB
        await DiscountsDao.instance.upsert(_items[i]);
      }
    }
  }

  String? validate(PosDiscount d) {
    if (d.name.trim().isEmpty) return 'Nombre requerido.';
    if (d.percent <= 0 || d.percent >= 100) return 'El descuento debe ser > 0 y < 100.';

    final byProd = d.productId.trim().isNotEmpty;
    final byDept = d.department.trim().isNotEmpty;

    if (!byProd && !byDept) return 'Selecciona producto o departamento.';
    if (byProd && byDept) return 'Debe ser por producto o por departamento, no ambos.';

    if (d.startsAt != null && d.endsAt != null && d.endsAt!.isBefore(d.startsAt!)) {
      return 'Fin no puede ser menor que inicio.';
    }

    bool timeOverlaps(PosDiscount a, PosDiscount b) {
      final aStart = a.startsAt ?? DateTime.fromMillisecondsSinceEpoch(0);
      final bStart = b.startsAt ?? DateTime.fromMillisecondsSinceEpoch(0);
      final aEnd = a.endsAt ?? DateTime(9999, 12, 31, 23, 59, 59);
      final bEnd = b.endsAt ?? DateTime(9999, 12, 31, 23, 59, 59);
      return !aStart.isAfter(bEnd) && !bStart.isAfter(aEnd);
    }

    for (final other in _items) {
      if (other.id == d.id) continue;
      if (!other.enabled || !d.enabled) continue;

      final sameTarget = d.isByProduct
          ? other.productId == d.productId
          : other.department.trim().toUpperCase() == d.department.trim().toUpperCase();

      if (!sameTarget) continue;

      if (timeOverlaps(other, d)) {
        return 'Ya existe un descuento habilitado que se cruza en vigencia para ese producto/departamento.';
      }
    }

    return null;
  }

  Future<void> upsert(PosDiscount d) async {
    await ensureLoaded();

    final normalized = _normalize(d);
    final err = validate(normalized);
    if (err != null) throw Exception(err);

    final idx = _items.indexWhere((x) => x.id == normalized.id);
    if (idx >= 0) {
      _items[idx] = normalized;
    } else {
      _items.add(normalized);
    }

    _items.sort((a, b) {
      if (a.enabled != b.enabled) return a.enabled ? -1 : 1;
      return b.createdAt.compareTo(a.createdAt);
    });

    notifyListeners();
    // ✅ Guardar en SQLite
    await DiscountsDao.instance.upsert(normalized);
  }

  Future<void> remove(String id) async {
    await ensureLoaded();
    _items.removeWhere((x) => x.id == id);
    notifyListeners();
    // ✅ Borrar de SQLite
    await DiscountsDao.instance.delete(id);
  }

  Future<void> setEnabled(String id, bool enabled) async {
    await ensureLoaded();
    final idx = _items.indexWhere((x) => x.id == id);
    if (idx < 0) return;

    final updated = _normalize(_items[idx].copyWith(enabled: enabled));
    
    // Validación extra al habilitar
    if (enabled) {
       final err = validate(updated);
       if (err != null) throw Exception(err);
    }

    _items[idx] = updated;
    _items.sort((a, b) {
      if (a.enabled != b.enabled) return a.enabled ? -1 : 1;
      return b.createdAt.compareTo(a.createdAt);
    });

    notifyListeners();
    // ✅ Actualizar en SQLite
    await DiscountsDao.instance.upsert(updated);
  }
}