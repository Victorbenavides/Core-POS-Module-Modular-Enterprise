// lib/modules/pos_unicaja/controllers/pos_session.dart
import 'package:flutter/material.dart';

import '../models/cash_session.dart';
import '../models/cashier.dart';
import '../models/sale.dart';
import '../models/sale_item.dart';

// ✅ Créditos
import '../credits/pos_credits_controller.dart';

// ✅ DB
import '../data/database/app_database.dart';
import '../data/database/sales_dao.dart';
import '../data/database/cash_sessions_dao.dart';

class PosSessionController extends ChangeNotifier {
  Cashier? _cashier;
  CashSession? _session;
  final String customerCode;

  final List<Sale> _sales = [];
  final List<CashSession> _sessions = [];

  // ======================================================
  // ✅ VENTAS EN PAUSA (solo en memoria, mientras la app esté abierta)
  // ======================================================
  final List<PausedSale> _pausedSales = [];
  List<PausedSale> get pausedSales => List.unmodifiable(_pausedSales);

  bool _loaded = false;
  Future<void>? _loadFuture;


  PosSessionController({required this.customerCode}) {
    ensureLoaded();
  }

  // -------- Getters --------
  Cashier? get cashier => _cashier;
  Cashier? get currentCashier => _cashier;

  CashSession? get session => _session;
  CashSession? get currentSession => _session;

  List<Sale> get allSales => List.unmodifiable(_sales);
  List<CashSession> get sessions => List.unmodifiable(_sessions);

  bool get isLoggedIn => _cashier != null;
  bool get hasOpenSession => _session != null && _session!.isOpen;
  bool get isAdmin => _cashier?.isAdmin ?? false;

  bool get loaded => _loaded;

  Future<void> ensureLoaded() {
    _loadFuture ??= _loadFromDb();
    return _loadFuture!;
  }

String? _dbError;
String? get dbError => _dbError;
  Future<void> _loadFromDb() async {
    try {
      await AppDatabase.initForCustomer(customerCode);

      final sales = await SalesDao.instance.getAll();
      final sess = await CashSessionsDao.instance.getAll();

      _sales
        ..clear()
        ..addAll(sales.reversed); // los guardamos asc para tus screens
      _sessions
        ..clear()
        ..addAll(sess.reversed);

      // ✅ si hay una sesión abierta “más reciente”, la retomamos como _session
      final openSessions = _sessions.where((s) => s.isOpen).toList();
      if (openSessions.isNotEmpty) {
        openSessions.sort((a, b) => a.openedAt.compareTo(b.openedAt));
        _session = openSessions.last;
      }

      _loaded = true;
      notifyListeners();
      _dbError = null;
    } catch (e) {
      // no tronamos la app si algo falla
      _loaded = true;
      notifyListeners();
    }
  }

  // -------- Login / logout --------
  void login(Cashier cashier) {
    _cashier = cashier;
    notifyListeners();
  }

  void logout() {
    _cashier = null;
    _session = null;

    // ✅ Opcional: al desloguear limpiamos ventas en pausa del cajero anterior
    // (si prefieres que sobrevivan al logout, borra este bloque)
    _pausedSales.clear();

    notifyListeners();
  }

  // -------- Sesión de caja --------
  Future<void> openSession(double openingAmount) async {
    if (_cashier == null) {
      throw Exception("No hay cajero logueado para abrir caja.");
    }

    await ensureLoaded();

    final now = DateTime.now();

    final newSession = CashSession(
      id: now.millisecondsSinceEpoch.toString(),
      cashierId: _cashier!.id,
      openedAt: now,
      openingAmount: openingAmount,
    );

    _session = newSession;
    _sessions.add(newSession);

    await CashSessionsDao.instance.upsert(newSession);

    notifyListeners();
  }

  Future<void> closeSession() async {
    if (_session == null) return;

    await ensureLoaded();

    _session!.isOpen = false;
    _session!.closedAt ??= DateTime.now();

    await CashSessionsDao.instance.upsert(_session!);

    notifyListeners();
  }


    Future<void> registerCashIn({required double amount, String note = ''}) async {
    if (_session == null || !_session!.isOpen) {
      throw Exception('No hay sesión de caja abierta.');
    }

    await ensureLoaded();

    _session!.cashInTotal += amount;

    await CashSessionsDao.instance.upsert(_session!);
    notifyListeners();
  }

  Future<void> registerCashOut({required double amount, String note = ''}) async {
    if (_session == null || !_session!.isOpen) {
      throw Exception('No hay sesión de caja abierta.');
    }

    await ensureLoaded();

    _session!.cashOutTotal += amount;

    await CashSessionsDao.instance.upsert(_session!);
    notifyListeners();
  }


  // -------- Helpers por día --------
  bool _isSameDay(DateTime a, DateTime b) =>
      a.year == b.year && a.month == b.month && a.day == b.day;

  List<Sale> salesForDay(DateTime day) {
    final list = _sales.where((s) => _isSameDay(s.createdAt, day)).toList()
      ..sort((a, b) => a.createdAt.compareTo(b.createdAt));
    return list;
  }

  List<CashSession> sessionsForDay(DateTime day) {
    return _sessions.where((s) => _isSameDay(s.openedAt, day)).toList();
  }

  // -------- Ventas --------
  Future<void> registerSale(Sale sale) async {
    if (_session == null) {
      throw Exception('No hay sesión de caja abierta.');
    }

    await ensureLoaded();

    final cashier = _cashier;

    final saleWithCashier = (cashier != null && sale.cashierId.isEmpty)
        ? sale.copyWith(cashierId: cashier.id)
        : sale;

    _sales.add(saleWithCashier);

    // ✅ SOLO EFECTIVO impacta caja (salesTotal/cancelledTotal)
    if (saleWithCashier.paymentMethod == 'cash') {
      _session!.salesTotal += saleWithCashier.total;
      await CashSessionsDao.instance.upsert(_session!);
    }

    await SalesDao.instance.upsert(saleWithCashier);

    // ✅ Si es crédito, crea adeudo (si tu CreditsController ya es idempotente, perfecto)
    if (saleWithCashier.paymentMethod == 'credit') {
      PosCreditsController.instance.createCreditFromSale(saleWithCashier);
    }

    notifyListeners();
  }

  // ======================================================
  // ✅ VENTAS EN PAUSA (acciones)
  // ======================================================

  void addPausedSale(PausedSale p) {
    _pausedSales.add(p);
    notifyListeners();
  }

  PausedSale? popPausedSale(String id) {
    final i = _pausedSales.indexWhere((x) => x.id == id);
    if (i == -1) return null;
    final p = _pausedSales.removeAt(i);
    notifyListeners();
    return p;
  }

  void deletePausedSale(String id) {
    _pausedSales.removeWhere((x) => x.id == id);
    notifyListeners();
  }

  // -------- Cancelación detallada --------
  Future<void> cancelSaleItem({
    required String saleId,
    required int itemIndex,
  }) async {
    if (_session == null) {
      throw Exception('No hay sesión de caja abierta para cancelar.');
    }

    await ensureLoaded();

    final salePos = _sales.indexWhere((s) => s.id == saleId);
    if (salePos == -1) return;

    final sale = _sales[salePos];
    if (itemIndex < 0 || itemIndex >= sale.items.length) return;

    final item = sale.items[itemIndex];
    if (item.cancelled) return;

    final now = DateTime.now();
    final cancelBy = _cashier?.id ?? '';

    final updatedItems = List<SaleItem>.from(sale.items);
    updatedItems[itemIndex] = item.copyWith(
      cancelled: true,
      cancelledAt: now,
      cancelledByCashierId: cancelBy,
    );

    final updatedSale = sale.copyWith(items: updatedItems);
    _sales[salePos] = updatedSale;

    final amount = item.subtotal;

    if (sale.paymentMethod == 'cash') {
      _session!.cancelledTotal += amount;
      await CashSessionsDao.instance.upsert(_session!);
    }

    await SalesDao.instance.upsert(updatedSale);

    if (sale.paymentMethod == 'credit') {
      PosCreditsController.instance.onSaleUpdatedAfterCancellation(updatedSale);
    }

    notifyListeners();
  }

  Future<void> cancelEntireSale(String saleId) async {
    if (_session == null) {
      throw Exception('No hay sesión de caja abierta para cancelar.');
    }

    await ensureLoaded();

    final salePos = _sales.indexWhere((s) => s.id == saleId);
    if (salePos == -1) return;

    final sale = _sales[salePos];

    double amount = 0.0;
    final updatedItems = <SaleItem>[];
    final now = DateTime.now();
    final cancelBy = _cashier?.id ?? '';

    for (final item in sale.items) {
      if (item.cancelled) {
        updatedItems.add(item);
      } else {
        amount += item.subtotal;
        updatedItems.add(item.copyWith(
          cancelled: true,
          cancelledAt: now,
          cancelledByCashierId: cancelBy,
        ));
      }
    }

    final updatedSale = sale.copyWith(items: updatedItems);
    _sales[salePos] = updatedSale;

    if (sale.paymentMethod == 'cash') {
      _session!.cancelledTotal += amount;
      await CashSessionsDao.instance.upsert(_session!);
    }

    await SalesDao.instance.upsert(updatedSale);

    if (sale.paymentMethod == 'credit') {
      PosCreditsController.instance.onSaleUpdatedAfterCancellation(updatedSale);
    }

    notifyListeners();
  }

  // compat
  void cancelSale(Sale sale) => cancelEntireSale(sale.id);
}

// ======================================================
// ✅ Modelo para ventas en pausa (se mantiene en RAM)
// ======================================================
class PausedSale {
  final String id;
  final DateTime createdAt;
  final String cashierId;
  final List<SaleItem> items;

  /// info extra útil
  final double rawTotal;
  final bool roundingEnabled;
  final double roundingStep;

  /// wholesale
  final List<String> wholesaleProductIds;

  /// opcional (nota)
  final String note;

  const PausedSale({
    required this.id,
    required this.createdAt,
    required this.cashierId,
    required this.items,
    required this.rawTotal,
    required this.roundingEnabled,
    required this.roundingStep,
    required this.wholesaleProductIds,
    this.note = '',
  });
}
