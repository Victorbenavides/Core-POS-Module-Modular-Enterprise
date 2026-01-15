import 'package:flutter/foundation.dart';

import '../models/sale.dart';
import '../models/sale_item.dart';
import '../customers/pos_customers_controller.dart';

// Promos (para capturar snapshot exacto al momento de la venta)
import '../promotions/pos_promotions_controller.dart';
import '../promotions/pos_promotion_engine.dart';

import 'pos_credit_models.dart';

// ✅ CAMBIO: Importamos el DAO y la DB en lugar del Store
import '../data/database/app_database.dart';
import '../data/database/credits_dao.dart';

import 'package:framework_as/modules/pos_unicaja/promotions/pos_discounts_controller.dart';

class PosCreditsController extends ChangeNotifier {
  PosCreditsController._();
  static final PosCreditsController instance = PosCreditsController._();

  bool _loaded = false;
  bool _loading = false;

  final List<PosCreditEntry> _entries = [];
  final List<PosCreditPayment> _payments = [];

  List<PosCreditEntry> get entries => List.unmodifiable(_entries);
  List<PosCreditPayment> get payments => List.unmodifiable(_payments);

  /// Carga inicial desde SQLite
  Future<void> ensureLoaded() async {
    if (_loaded || _loading) return;
    _loading = true;

    try {
      final dbEntries = await CreditsDao.instance.getAllEntries();
      _entries
        ..clear()
        ..addAll(dbEntries);

      final dbPayments = await CreditsDao.instance.getAllPayments();
      _payments
        ..clear()
        ..addAll(dbPayments);
        
    } catch (e) {
      if (kDebugMode) print("Error cargando créditos SQL: $e");
    } finally {
      _loaded = true;
      _loading = false;
      notifyListeners();
    }
  }

  PosCreditEntry? entryBySaleId(String saleId) {
    for (final e in _entries) {
      if (e.saleId == saleId) return e;
    }
    return null;
  }

  PosCreditEntry? entryById(String id) {
    for (final e in _entries) {
      if (e.id == id) return e;
    }
    return null;
  }

  List<PosCreditEntry> openEntries({String? customerId}) {
    return _entries.where((e) {
      if (e.status != 'open') return false;
      if (customerId != null && customerId.isNotEmpty) {
        return e.customerId == customerId;
      }
      return true;
    }).toList()
      ..sort((a, b) => b.createdAt.compareTo(a.createdAt));
  }

  List<PosCreditPayment> paymentsInRange({
    required DateTime from,
    required DateTime to,
    String? cashierId,
  }) {
    bool inRange(DateTime t) => !t.isBefore(from) && !t.isAfter(to);

    return _payments.where((p) {
      if (!inRange(p.createdAt)) return false;
      if (cashierId != null && cashierId.isNotEmpty && p.cashierId != cashierId) return false;
      return true;
    }).toList();
  }

  Future<void> createCreditFromSale(Sale sale) async {
    await ensureLoaded();

    if (sale.paymentMethod != 'credit') return;
    if (sale.customerId.trim().isEmpty) return;

    // evitar duplicado si reintentas
    if (entryBySaleId(sale.id) != null) return;

    // Consolidar qty por producto (solo no cancelados)
    final Map<String, _Agg> map = {};
    for (final SaleItem it in sale.items) {
      if (it.cancelled) continue;
      final pid = it.product.id;
      final prev = map[pid];
      if (prev == null) {
        map[pid] = _Agg(
          productId: pid,
          name: it.product.name,
          unit: it.product.unit,
          department: it.product.department,
          basePrice: it.product.salePrice,
          qty: it.quantity,
        );
      } else {
        map[pid] = prev.copyWith(qty: prev.qty + it.quantity);
      }
    }

    final promoCtrl = PosPromotionsController.instance;
    await promoCtrl.ensureLoaded();

    final discCtrl = PosDiscountsController.instance;
    await discCtrl.ensureLoaded();

    final lines = <PosCreditLineSnapshot>[];

    for (final agg in map.values) {
      final pricing = PosPromotionEngine.bestLinePricing(
        promotions: promoCtrl.promotions,
        discounts: discCtrl.discounts,
        productId: agg.productId,
        department: agg.department,
        qty: agg.qty,
        baseUnitPrice: agg.basePrice,
        now: sale.createdAt,
      );

      final hasPromo = pricing.promo != null && pricing.discountAmount > 0.000001;

      lines.add(
        PosCreditLineSnapshot(
          productId: agg.productId,
          name: agg.name,
          unit: agg.unit,
          qtyOriginal: agg.qty,
          qtyRemaining: agg.qty,
          baseUnitPrice: agg.basePrice,
          hasPromo: hasPromo,
          promoName: pricing.promo?.name ?? '',
          isBundle: pricing.isBundle,
          bundleSize: pricing.bundleSize,
          bundlePrice: pricing.bundlePrice,
          promoUnitPrice: pricing.promo?.promoUnitPrice ?? agg.basePrice,
          originalSubtotal: pricing.subtotal,
          remainingSubtotal: pricing.subtotal,
        ),
      );
    }

    final now = DateTime.now();

    final entry = PosCreditEntry(
      id: 'cr_${now.millisecondsSinceEpoch}',
      customerId: sale.customerId,
      saleId: sale.id,
      createdCashierId: sale.cashierId,
      createdAt: sale.createdAt,
      status: 'open',
      lines: lines,
    );

    // 1. Memoria
    _entries.add(entry);
    notifyListeners();
    
    // 2. SQLite
    await CreditsDao.instance.upsertEntry(entry);

    // Sube deuda del cliente
    await PosCustomersController.instance.bumpDebt(entry.customerId, entry.remainingAmount);
  }

  Future<void> onSaleUpdatedAfterCancellation(Sale updatedSale) async {
    await ensureLoaded();

    if (updatedSale.paymentMethod != 'credit') return;
    if (updatedSale.customerId.trim().isEmpty) return;

    final entryIdx = _entries.indexWhere((e) => e.saleId == updatedSale.id);
    if (entryIdx < 0) return;

    final entry = _entries[entryIdx];
    if (entry.status != 'open') return;

    final Map<String, double> qtyMap = {};
    for (final it in updatedSale.items) {
      if (it.cancelled) continue;
      qtyMap[it.product.id] = (qtyMap[it.product.id] ?? 0.0) + it.quantity;
    }

    final oldRemaining = entry.remainingAmount;

    final newLines = entry.lines.map((l) {
      final newQty = qtyMap[l.productId] ?? 0.0;
      final newSubtotal = l.subtotalForQty(newQty);
      return l.copyWith(
        qtyRemaining: newQty,
        remainingSubtotal: newSubtotal,
      );
    }).toList();

    final newEntry = entry.copyWith(lines: newLines);
    final newRemaining = newEntry.remainingAmount;
    final delta = newRemaining - oldRemaining;

    if (delta.abs() > 0.000001) {
      await PosCustomersController.instance.bumpDebt(entry.customerId, delta);
    }

    final finalEntry = (newRemaining <= 0.000001)
        ? newEntry.copyWith(status: 'cancelled')
        : newEntry;

    // Actualizar Memoria y DB
    _entries[entryIdx] = finalEntry;
    notifyListeners();
    
    await CreditsDao.instance.upsertEntry(finalEntry);
  }

  Future<void> settleEntry({
    required String entryId,
    required String cashierId,
    required String method,
  }) async {
    await ensureLoaded();

    final idx = _entries.indexWhere((e) => e.id == entryId);
    if (idx < 0) return;

    final e = _entries[idx];
    if (e.status != 'open') return;

    final amount = e.remainingAmount;
    if (amount <= 0.000001) return;

    final now = DateTime.now();

    final updated = e.copyWith(
      status: 'paid',
      settledAt: now,
      settledCashierId: cashierId,
      settledMethod: method,
    );
    
    final payment = PosCreditPayment(
      id: 'cp_${now.millisecondsSinceEpoch}',
      entryId: e.id,
      customerId: e.customerId,
      cashierId: cashierId,
      createdAt: now,
      amount: amount,
      method: method,
    );

    // Actualizar Memoria
    _entries[idx] = updated;
    _payments.add(payment);
    notifyListeners();

    // Actualizar SQLite
    await CreditsDao.instance.upsertEntry(updated);
    await CreditsDao.instance.upsertPayment(payment);

    // Baja deuda del cliente
    await PosCustomersController.instance.bumpDebt(e.customerId, -amount);
  }
}

class _Agg {
  final String productId;
  final String name;
  final String unit;
  final String department;
  final double basePrice;
  final double qty;

  _Agg({
    required this.productId,
    required this.name,
    required this.unit,
    required this.department,
    required this.basePrice,
    required this.qty,
  });

  _Agg copyWith({double? qty}) => _Agg(
        productId: productId,
        name: name,
        unit: unit,
        department: department,
        basePrice: basePrice,
        qty: qty ?? this.qty,
      );
}