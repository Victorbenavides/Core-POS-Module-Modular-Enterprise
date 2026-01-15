// lib/modules/pos_unicaja/controllers/pos_cashiers_controller.dart
import 'package:flutter/foundation.dart';

import '../models/cashier.dart';
import '../data/database/cashiers_dao.dart';
import '../data/database/app_database.dart';

class PosCashiersController extends ChangeNotifier {
  /// ✅ IMPORTANTE:
  /// Este controller debe abrir SIEMPRE la DB aislada del cliente,
  /// NO la DB global. Por eso recibe customerCode/customerId.
  final String customerCode;

  final List<Cashier> _cashiers = [];

  bool _initialized = false;
  Future<void>? _initFuture;

  List<Cashier> get cashiers => List.unmodifiable(_cashiers);
  bool get initialized => _initialized;

  /// Admin raíz que siempre debe existir
  static const Cashier ROOT_ADMIN = Cashier(
    id: 'root',
    name: 'Admin Raíz',
    pin: '9999',
    isAdmin: true,

    // legacy
    canManageInventory: true,
    canViewReports: true,
    canCancelSales: true,

    // nuevos (operación)
    canOpenCash: true,
    canCloseCash: true,
    canCharge: true,
    canEditSale: true,

    // inventario
    canViewInventory: true,
    canEditInventory: true,
    canAdjustStock: true,

    // promos
    canManagePromotions: true,

    // clientes / créditos
    canManageCustomers: true,
    canUseCredits: true,
    canManageCredits: true,

    // reportes
    canDailyClose: true,
    canSalesReport: true,
    canSalesSummary: true,

    // administración
    canManageCashiers: true,
    canManagePeripherals: true,
    canManagePrintTemplate: true,
    canManageSettings: true,
  );

  PosCashiersController({required this.customerCode}) {
    // fire-and-forget, pero sin duplicar init
    ensureLoaded();
  }

  Future<void> ensureLoaded() {
    _initFuture ??= _init();
    return _initFuture!;
  }

  Future<void> _init() async {
    try {
      // ✅ CLAVE: abre la DB DEL CLIENTE (aislada)
      await AppDatabase.initForCustomer(customerCode);

      await _loadFromDatabase();
    } finally {
      _initialized = true;
      notifyListeners();
    }
  }

  Future<void> _loadFromDatabase() async {
    try {
      final list = await CashiersDao.instance.getAll();
      _cashiers
        ..clear()
        ..addAll(list);
    } catch (e) {
      if (kDebugMode) {
        // ignore: avoid_print
        print('Error cargando cajeros desde DB: $e');
      }
      _cashiers.clear();
    }

    await _ensureRootAdmin();
  }

  Future<void> _ensureRootAdmin() async {
    if (_cashiers.any((c) => c.id == ROOT_ADMIN.id)) return;

    _cashiers.add(ROOT_ADMIN);
    try {
      await CashiersDao.instance.upsert(ROOT_ADMIN);
    } catch (e) {
      if (kDebugMode) {
        // ignore: avoid_print
        print('No se pudo guardar ROOT_ADMIN en DB: $e');
      }
    }
  }

  // ----------------- helpers útiles -----------------

  /// ID simple (sin libs): "c_1700000000000_1234"
  String createCashierId() {
    final ms = DateTime.now().millisecondsSinceEpoch;
    final r = (ms % 10000).toString().padLeft(4, '0');
    return 'c_${ms}_$r';
  }

  /// Cajero estándar recomendado (puedes ajustar defaults)
  Cashier defaultCashier({
    required String id,
    required String name,
    required String pin,
  }) {
    return Cashier(
      id: id,
      name: name,
      pin: pin,

      // operación básica
      canOpenCash: true,
      canCloseCash: true,
      canCharge: true,

      // permitir quitar/editar venta (si quieres que NO pueda, pon false)
      canEditSale: true,

      // ver inventario (sin editar)
      canViewInventory: true,

      // reportes básicos (si quieres que NO vea, pon false)
      canSalesReport: true,
      canSalesSummary: true,
      canDailyClose: false,

      // créditos: normalmente NO
      canUseCredits: false,
      canManageCredits: false,
      canManageCustomers: false,

      // administración: NO
      canManageCashiers: false,
      canManageSettings: false,
      canManagePeripherals: false,
      canManagePrintTemplate: false,
      canManagePromotions: false,
      canEditInventory: false,
      canAdjustStock: false,
      canCancelSales: false, // legacy
      canManageInventory: false, // legacy
      canViewReports: false, // legacy
    );
  }

  // ----------------- operaciones -----------------

  /// Inserta o actualiza, protege admin raíz (con rollback si DB falla)
  Future<void> upsert(Cashier cashier) async {
    await ensureLoaded();

    if (cashier.id == ROOT_ADMIN.id) {
      throw Exception("No se puede modificar el admin raíz.");
    }

    final index = _cashiers.indexWhere((c) => c.id == cashier.id);
    final Cashier? before = index == -1 ? null : _cashiers[index];

    if (index == -1) {
      _cashiers.add(cashier);
    } else {
      _cashiers[index] = cashier;
    }
    notifyListeners();

    try {
      await CashiersDao.instance.upsert(cashier);
    } catch (e) {
      // rollback
      if (index == -1) {
        _cashiers.removeWhere((c) => c.id == cashier.id);
      } else if (before != null) {
        _cashiers[index] = before;
      }
      notifyListeners();

      if (kDebugMode) {
        // ignore: avoid_print
        print('Error guardando cajero en DB: $e');
      }
      rethrow;
    }
  }

  /// Elimina, protege admin raíz (con rollback si DB falla)
  Future<void> remove(String id, {String? currentUserId}) async {
    await ensureLoaded();

    if (id == ROOT_ADMIN.id) {
      throw Exception("No se puede eliminar el admin raíz.");
    }

    final before = _cashiers.where((c) => c.id == id).toList();
    _cashiers.removeWhere((c) => c.id == id);
    notifyListeners();

    try {
      await CashiersDao.instance.delete(id, currentUserId: currentUserId);
    } catch (e) {
      // rollback
      _cashiers.addAll(before);
      notifyListeners();

      if (kDebugMode) {
        // ignore: avoid_print
        print('Error eliminando cajero en DB: $e');
      }
      rethrow;
    }
  }

  Cashier? findById(String id) {
    try {
      return _cashiers.firstWhere((c) => c.id == id);
    } catch (_) {
      return null;
    }
  }

  /// Busca en memoria por PIN (rápido). Si no está, consulta DB.
  Future<Cashier?> findByPin(String pin) async {
    await ensureLoaded();
    final p = pin.trim();

    try {
      return _cashiers.firstWhere((c) => c.pin.trim() == p);
    } catch (_) {
      // ignore
    }

    return CashiersDao.instance.loginWithPin(p);
  }

  /// Login: devuelve cashier si OK y lo deja en memoria.
  Future<Cashier?> login(String pin) async {
    await ensureLoaded();
    final p = pin.trim();

    Cashier? c;
    try {
      c = _cashiers.firstWhere((e) => e.pin.trim() == p);
    } catch (_) {
      c = await CashiersDao.instance.loginWithPin(p);
    }

    if (c == null) return null;

    final idx = _cashiers.indexWhere((e) => e.id == c!.id);
    if (idx == -1) {
      _cashiers.add(c);
    } else {
      _cashiers[idx] = c;
    }

    notifyListeners();
    return c;
  }

  /// Útil si un día quieres “refrescar” desde DB (ej. después de migraciones)
  Future<void> reload() async {
    _initFuture = null;
    _initialized = false;
    await ensureLoaded();
  }
}
