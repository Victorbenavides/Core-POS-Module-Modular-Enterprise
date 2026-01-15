// lib/modules/pos_unicaja/widgets/pos_daily_close.dart
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import 'package:framework_as/modules/pos_unicaja/controllers/pos_session.dart';
import 'package:framework_as/modules/pos_unicaja/controllers/pos_cashiers_controller.dart';
import 'package:framework_as/modules/pos_unicaja/models/sale.dart';
import 'package:framework_as/modules/pos_unicaja/models/cash_session.dart';

class PosDailyCloseScreen extends StatelessWidget {
  /// ✅ Día a consultar. Si viene null, usa hoy.
  final DateTime? day;

  /// ✅ (Opcional) Filtra el corte para un cajero específico.
  final String? cashierId;

  const PosDailyCloseScreen({
    super.key,
    this.day,
    this.cashierId,
  });

  String _methodLabel(String code) {
    switch (code) {
      case 'cash':
        return 'Efectivo';
      case 'card':
        return 'Tarjeta';
      case 'transfer':
        return 'Transferencia';
      case 'credit':
        return 'Crédito';
      default:
        return code.isEmpty ? 'Desconocido' : code;
    }
  }

  String _fmtDate(DateTime dt) {
    final d = dt.day.toString().padLeft(2, '0');
    final m = dt.month.toString().padLeft(2, '0');
    final y = dt.year.toString();
    return '$d/$m/$y';
  }

  bool _isSameDay(DateTime a, DateTime b) =>
      a.year == b.year && a.month == b.month && a.day == b.day;

  @override
  Widget build(BuildContext context) {
    final sessionCtrl = context.watch<PosSessionController>();
    final cashiersCtrl = context.watch<PosCashiersController>();

    final selectedDay = day ?? DateTime.now();

    // Ventas del día (por fecha de creación)
    List<Sale> daySales = sessionCtrl.salesForDay(selectedDay);

    // Sesiones del día (cortes de cajero) cerradas
    List<CashSession> daySessions =
        sessionCtrl.sessionsForDay(selectedDay).where((s) => !s.isOpen).toList()
          ..sort((a, b) {
            final at = a.closedAt ?? a.openedAt;
            final bt = b.closedAt ?? b.openedAt;
            return at.compareTo(bt);
          });

    // ✅ Si viene filtro por cajero
    final cid = (cashierId ?? '').trim();
    if (cid.isNotEmpty) {
      daySales = daySales.where((s) => s.cashierId == cid).toList();
      daySessions = daySessions.where((s) => s.cashierId == cid).toList();
    }

    double sumItems(Sale sale, {required bool cancelled}) {
      return sale.items
          .where((i) => i.cancelled == cancelled)
          .fold(0.0, (sum, i) => sum + i.subtotal);
    }

    // Totales del día (bruto por tickets)
    final double totalSalesDay = daySales.fold(0.0, (sum, s) => sum + s.total);

    // Cancelado del día según sesiones
    final double totalCancelledDay =
        daySessions.fold(0.0, (sum, s) => sum + s.cancelledTotal);

    final double netDay = totalSalesDay - totalCancelledDay;
    final int ticketsCount = daySales.length;

    // ✅ Ventas por método (NETO) desde items vigentes
    final Map<String, double> netByMethodDay = {};
    for (final sale in daySales) {
      final method =
          sale.paymentMethod.trim().isEmpty ? 'cash' : sale.paymentMethod.trim();
      final ok = sumItems(sale, cancelled: false);
      netByMethodDay[method] = (netByMethodDay[method] ?? 0.0) + ok;
    }

    // Ventas por departamento (neto)
    final Map<String, _DeptSummary> deptMap = {};
    for (final sale in daySales) {
      for (final item in sale.items) {
        if (item.cancelled) continue;

        final deptRaw = item.product.department.trim();
        final dept = deptRaw.isEmpty ? 'GENERAL' : deptRaw;

        final summary = deptMap.putIfAbsent(
          dept,
          () => _DeptSummary(department: dept),
        );
        summary.total += item.subtotal;
        summary.items += 1;
      }
    }

    final List<_DeptSummary> departments = deptMap.values.toList()
      ..sort((a, b) =>
          a.department.toLowerCase().compareTo(b.department.toLowerCase()));

    String cashierName(String cashierId) {
      for (final c in cashiersCtrl.cashiers) {
        if (c.id == cashierId) return c.name;
      }
      return 'Cajero $cashierId';
    }

    // --- Helpers detalle por sesión ---
    List<Sale> salesForSession(CashSession s) {
      final start = s.openedAt;
      final end = s.closedAt ?? s.openedAt;

      return sessionCtrl.allSales.where((sale) {
        if (sale.cashierId != s.cashierId) return false;
        final created = sale.createdAt;
        return !created.isBefore(start) && !created.isAfter(end);
      }).toList();
    }

    Map<String, double> netByMethodForSession(CashSession s) {
      final map = <String, double>{};
      final sales = salesForSession(s);

      for (final sale in sales) {
        final method =
            sale.paymentMethod.trim().isEmpty ? 'cash' : sale.paymentMethod.trim();
        final ok = sumItems(sale, cancelled: false);
        final canc = sumItems(sale, cancelled: true);
        map[method] = (map[method] ?? 0.0) + (ok - canc);
      }
      return map;
    }

    final titleDate = _fmtDate(selectedDay);

    String subtitleFilter() {
      if (cid.isEmpty) return '';
      final name = cashierName(cid);
      return ' • $name';
    }

Future<void> pickDate() async {
  final picked = await showDatePicker(
    context: context,
    initialDate: selectedDay,
    firstDate: DateTime(2020, 1, 1),
    lastDate: DateTime.now().add(const Duration(days: 3650)),
  );
  if (picked == null) return;

  final sessionCtrl = context.read<PosSessionController>();
  final cashiersCtrl = context.read<PosCashiersController>();

  if (!context.mounted) return;

  Navigator.of(context).push(
    MaterialPageRoute(
      builder: (_) => MultiProvider(
        providers: [
          ChangeNotifierProvider<PosSessionController>.value(value: sessionCtrl),
          ChangeNotifierProvider<PosCashiersController>.value(value: cashiersCtrl),
        ],
        child: PosDailyCloseScreen(day: picked, cashierId: cashierId),
      ),
    ),
  );
}


    return Scaffold(
      appBar: AppBar(
        title: Text('Corte del día - $titleDate${subtitleFilter()}'),
        actions: [
          IconButton(
            tooltip: 'Elegir fecha',
            icon: const Icon(Icons.event),
            onPressed: pickDate,
          ),
          IconButton(
            tooltip: 'Historial de cortes',
            icon: const Icon(Icons.history),
            onPressed: () {
              PosCloseHistoryDialog.show(
                context,
                initialBaseDate: selectedDay,
              );
            },
          ),
        ],
      ),
      body: (daySales.isEmpty && daySessions.isEmpty)
          ? Center(
              child: Text(
                _isSameDay(selectedDay, DateTime.now())
                    ? 'No hay ventas registradas en el día de hoy.'
                    : 'No hay ventas registradas en esta fecha.',
              ),
            )
          : Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                children: [
                  // ---- Resumen general del día ----
                  Card(
                    elevation: 3,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Padding(
                      padding: const EdgeInsets.all(16),
                      child: Row(
                        children: [
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                const Text(
                                  'Resumen del día',
                                  style: TextStyle(
                                    fontSize: 16,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                                const SizedBox(height: 8),
                                Text('Tickets: $ticketsCount'),
                                Text('Total vendido (bruto): \$${totalSalesDay.toStringAsFixed(2)}'),
                                Text('Cancelado (en cierres): \$${totalCancelledDay.toStringAsFixed(2)}'),
                                Text(
                                  'Neto: \$${netDay.toStringAsFixed(2)}',
                                  style: const TextStyle(fontWeight: FontWeight.bold),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),

                  const SizedBox(height: 16),

                  // ---- Ventas por método (NETO) ----
                  Card(
                    elevation: 3,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Padding(
                      padding: const EdgeInsets.all(12),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            _isSameDay(selectedDay, DateTime.now())
                                ? 'Ventas por forma de pago (neto en tickets de hoy)'
                                : 'Ventas por forma de pago (neto en tickets del día)',
                            style: const TextStyle(fontSize: 15, fontWeight: FontWeight.bold),
                          ),
                          const SizedBox(height: 8),
                          if (netByMethodDay.isEmpty)
                            const Text('No hay ventas vigentes para desglosar.')
                          else
                            ...(() {
                              final order = ['cash', 'card', 'transfer', 'credit'];
                              final keys = netByMethodDay.keys.toList()
                                ..sort((a, b) {
                                  final ia = order.indexOf(a);
                                  final ib = order.indexOf(b);
                                  if (ia == -1 && ib == -1) return a.compareTo(b);
                                  if (ia == -1) return 1;
                                  if (ib == -1) return -1;
                                  return ia.compareTo(ib);
                                });

                              return keys.map((k) {
                                final v = netByMethodDay[k] ?? 0.0;
                                return ListTile(
                                  dense: true,
                                  title: Text(_methodLabel(k)),
                                  trailing: Text(
                                    '\$${v.toStringAsFixed(2)}',
                                    style: const TextStyle(fontWeight: FontWeight.w600),
                                  ),
                                );
                              }).toList();
                            })(),
                        ],
                      ),
                    ),
                  ),

                  const SizedBox(height: 16),

                  // ---- Detalle: departamentos + cortes de cajero ----
                  Expanded(
                    child: Row(
                      children: [
                        // Ventas por departamento
                        Expanded(
                          child: Card(
                            elevation: 3,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: Padding(
                              padding: const EdgeInsets.all(12),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  const Text(
                                    'Ventas por departamento (neto)',
                                    style: TextStyle(
                                      fontSize: 15,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                  const SizedBox(height: 8),
                                  if (departments.isEmpty)
                                    const Text('No hay ventas para mostrar por departamento.')
                                  else
                                    Expanded(
                                      child: ListView.builder(
                                        itemCount: departments.length,
                                        itemBuilder: (_, index) {
                                          final d = departments[index];
                                          return ListTile(
                                            dense: true,
                                            title: Text(d.department),
                                            subtitle: Text('Artículos: ${d.items}'),
                                            trailing: Text(
                                              '\$${d.total.toStringAsFixed(2)}',
                                              style: const TextStyle(fontWeight: FontWeight.w600),
                                            ),
                                          );
                                        },
                                      ),
                                    ),
                                ],
                              ),
                            ),
                          ),
                        ),

                        const SizedBox(width: 16),

                        // Cortes de cajero (día seleccionado)
                        Expanded(
                          child: Card(
                            elevation: 3,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: Padding(
                              padding: const EdgeInsets.all(12),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    _isSameDay(selectedDay, DateTime.now())
                                        ? 'Cortes de cajero (hoy)'
                                        : 'Cortes de cajero ($titleDate)',
                                    style: const TextStyle(fontSize: 15, fontWeight: FontWeight.bold),
                                  ),
                                  const SizedBox(height: 8),
                                  if (daySessions.isEmpty)
                                    const Text('No hay cortes de cajero registrados en esta fecha.')
                                  else
                                    Expanded(
                                      child: ListView.builder(
                                        itemCount: daySessions.length,
                                        itemBuilder: (_, index) {
                                          final s = daySessions[index];
                                          final name = cashierName(s.cashierId);

                                          final openTime =
                                              '${s.openedAt.hour.toString().padLeft(2, '0')}:${s.openedAt.minute.toString().padLeft(2, '0')}';
                                          final closeTime = (s.closedAt != null)
                                              ? '${s.closedAt!.hour.toString().padLeft(2, '0')}:${s.closedAt!.minute.toString().padLeft(2, '0')}'
                                              : '-';

                                          final byMethod = netByMethodForSession(s);
                                          final cashNet = byMethod['cash'] ?? 0.0;
                                          final expectedCash = s.openingAmount + cashNet + s.cashInTotal - s.cashOutTotal;

                                          double netAll = 0.0;
                                          for (final v in byMethod.values) {
                                            netAll += v;
                                          }

                                          final cardNet = byMethod['card'] ?? 0.0;
                                          final transferNet = byMethod['transfer'] ?? 0.0;
                                          final creditNet = byMethod['credit'] ?? 0.0;

                                          return Card(
                                            margin: const EdgeInsets.symmetric(vertical: 6),
                                            child: ListTile(
                                              title: Text(name),
                                              subtitle: Text(
                                                'Apertura: $openTime  •  Cierre: $closeTime\n'
                                                'Neto: \$${netAll.toStringAsFixed(2)}  •  '
                                                'Efectivo esperado: \$${expectedCash.toStringAsFixed(2)}\n'
                                                'Efectivo: \$${cashNet.toStringAsFixed(2)}  •  '
                                                'Tarjeta: \$${cardNet.toStringAsFixed(2)}  •  '
                                                'Transf: \$${transferNet.toStringAsFixed(2)}  •  '
                                                'Crédito: \$${creditNet.toStringAsFixed(2)}'
                                                'Entradas: \$${s.cashInTotal.toStringAsFixed(2)}  •  Salidas: \$${s.cashOutTotal.toStringAsFixed(2)}\n',
                                              ),
                                              trailing: Text(
                                                '\$${s.cancelledTotal.toStringAsFixed(2)}',
                                                style: const TextStyle(fontWeight: FontWeight.bold),
                                              ),
                                              onTap: () {
                                                PosCashSessionDetailDialog.show(
                                                  context,
                                                  session: s,
                                                  cashierName: name,
                                                  allSales: sessionCtrl.allSales,
                                                );
                                              },
                                            ),
                                          );
                                        },
                                      ),
                                    ),
                                ],
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
    );
  }
}

class _DeptSummary {
  final String department;
  double total;
  int items;

  _DeptSummary({
    required this.department,
    this.total = 0.0,
    this.items = 0,
  });
}

// ======================================================
// ✅ DIALOG: Historial (cuadriculado) con filtros
// ======================================================

enum _RangePreset { day, week, month, year, custom }

class PosCloseHistoryDialog extends StatefulWidget {
  final DateTime? initialBaseDate;

  // ✅ NUEVO: context “bueno” (el que sí está bajo los Providers)
  final BuildContext parentContext;

  const PosCloseHistoryDialog({
    super.key,
    this.initialBaseDate,
    required this.parentContext,
  });

  static Future<void> show(BuildContext context, {DateTime? initialBaseDate}) {
  // ✅ Este es el "parent context" real (el de la pantalla), antes de entrar al builder
  final parentContext = context;

  // ✅ Capturamos controllers desde el context correcto (pantalla)
  final sessionCtrl = parentContext.read<PosSessionController>();
  final cashiersCtrl = parentContext.read<PosCashiersController>();

  return showDialog<void>(
    context: parentContext,
    barrierDismissible: true,
    builder: (_) => MultiProvider(
      providers: [
        ChangeNotifierProvider<PosSessionController>.value(value: sessionCtrl),
        ChangeNotifierProvider<PosCashiersController>.value(value: cashiersCtrl),
      ],
      child: Dialog(
        insetPadding: const EdgeInsets.all(16),
        child: LayoutBuilder(
          builder: (dialogContext, c) {
            final w = c.maxWidth.clamp(680.0, 1400.0);
            final h = c.maxHeight.clamp(520.0, 900.0);

            return SizedBox(
              width: w,
              height: h,
              child: PosCloseHistoryDialog(
                parentContext: parentContext, // ✅ ahora sí, el de pantalla
                initialBaseDate: initialBaseDate,
              ),
            );
          },
        ),
      ),
    ),
  );
}


  @override
  State<PosCloseHistoryDialog> createState() => _PosCloseHistoryDialogState();
}

class _PosCloseHistoryDialogState extends State<PosCloseHistoryDialog> {
  _RangePreset _preset = _RangePreset.week;

  late DateTime _baseDate;
  DateTime? _from;
  DateTime? _to;

  String _cashierId = ''; // '' => todos
  String _cashierNameSearch = ''; // filtro por nombre (opcional)

  @override
  void initState() {
    super.initState();
    _baseDate = widget.initialBaseDate ?? DateTime.now();
  }

  DateTime _startOfDay(DateTime d) => DateTime(d.year, d.month, d.day);
  DateTime _endOfDay(DateTime d) =>
      DateTime(d.year, d.month, d.day, 23, 59, 59, 999);

  String _fmtDate(DateTime dt) {
    final d = dt.day.toString().padLeft(2, '0');
    final m = dt.month.toString().padLeft(2, '0');
    final y = dt.year.toString();
    return '$d/$m/$y';
  }

  String _fmtTime(DateTime dt) {
    final hh = dt.hour.toString().padLeft(2, '0');
    final mm = dt.minute.toString().padLeft(2, '0');
    return '$hh:$mm';
  }

  DateTime _weekStart(DateTime d) {
    final dd = _startOfDay(d);
    final delta = dd.weekday - DateTime.monday; // lunes=1
    return dd.subtract(Duration(days: delta));
  }

  DateTime _weekEnd(DateTime d) {
    final start = _weekStart(d);
    return _endOfDay(start.add(const Duration(days: 6)));
  }

  DateTime _monthStart(DateTime d) => DateTime(d.year, d.month, 1);
  DateTime _monthEnd(DateTime d) => _endOfDay(DateTime(d.year, d.month + 1, 0));

  DateTime _yearStart(DateTime d) => DateTime(d.year, 1, 1);
  DateTime _yearEnd(DateTime d) => _endOfDay(DateTime(d.year, 12, 31));

  DateTimeRange _calcRange() {
    switch (_preset) {
      case _RangePreset.day:
        return DateTimeRange(
          start: _startOfDay(_baseDate),
          end: _endOfDay(_baseDate),
        );
      case _RangePreset.week:
        return DateTimeRange(
          start: _weekStart(_baseDate),
          end: _weekEnd(_baseDate),
        );
      case _RangePreset.month:
        return DateTimeRange(
          start: _monthStart(_baseDate),
          end: _monthEnd(_baseDate),
        );
      case _RangePreset.year:
        return DateTimeRange(
          start: _yearStart(_baseDate),
          end: _yearEnd(_baseDate),
        );
      case _RangePreset.custom:
        final f = _startOfDay(_from ?? _baseDate);
        final t = _endOfDay(_to ?? _baseDate);
        final start = f.isBefore(t) ? f : t;
        final end = f.isBefore(t) ? t : f;
        return DateTimeRange(start: start, end: end);
    }
  }

  String _cashierName(PosCashiersController cCtrl, String id) {
    for (final c in cCtrl.cashiers) {
      if (c.id == id) return c.name;
    }
    return 'Cajero $id';
  }

  bool _matchCashierName(PosCashiersController cCtrl, String cashierId) {
    final q = _cashierNameSearch.trim().toLowerCase();
    if (q.isEmpty) return true;
    final name = _cashierName(cCtrl, cashierId).toLowerCase();
    return name.contains(q);
  }

  Future<void> _pickBaseDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _baseDate,
      firstDate: DateTime(2020, 1, 1),
      lastDate: DateTime.now().add(const Duration(days: 3650)),
    );
    if (picked == null) return;
    setState(() => _baseDate = picked);
  }

  Future<void> _pickFrom() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _from ?? _baseDate,
      firstDate: DateTime(2020, 1, 1),
      lastDate: DateTime.now().add(const Duration(days: 3650)),
    );
    if (picked == null) return;
    setState(() => _from = picked);
  }

  Future<void> _pickTo() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _to ?? _baseDate,
      firstDate: DateTime(2020, 1, 1),
      lastDate: DateTime.now().add(const Duration(days: 3650)),
    );
    if (picked == null) return;
    setState(() => _to = picked);
  }

  double _sumItems(Sale sale, {required bool cancelled}) {
    return sale.items
        .where((i) => i.cancelled == cancelled)
        .fold(0.0, (sum, i) => sum + i.subtotal);
  }

  @override
  Widget build(BuildContext context) {
    final sessionCtrl = context.watch<PosSessionController>();
    final cashiersCtrl = context.watch<PosCashiersController>();

    final cashier = sessionCtrl.currentCashier;

final canDailyClose = cashier != null &&
    (cashier.isAdmin || cashier.canDailyClose || cashier.canViewReports);

if (!canDailyClose) {
  return Scaffold(
    appBar: AppBar(title: const Text('Corte del día')),
    body: const Center(child: Text('No tienes permiso para ver el Corte diario.')),
  );
}


    final range = _calcRange();
    final from = range.start;
    final to = range.end;

    final cid = _cashierId.trim();

    final filteredSales = sessionCtrl.allSales.where((s) {
      if (s.createdAt.isBefore(from) || s.createdAt.isAfter(to)) return false;
      if (cid.isNotEmpty && s.cashierId != cid) return false;
      if (!_matchCashierName(cashiersCtrl, s.cashierId)) return false;
      return true;
    }).toList();

    final filteredSessions = sessionCtrl.sessions.where((s) {
      if (s.isOpen) return false;
      if (s.openedAt.isBefore(from) || s.openedAt.isAfter(to)) return false;
      if (cid.isNotEmpty && s.cashierId != cid) return false;
      if (!_matchCashierName(cashiersCtrl, s.cashierId)) return false;
      return true;
    }).toList()
      ..sort((a, b) {
        final at = a.closedAt ?? a.openedAt;
        final bt = b.closedAt ?? b.openedAt;
        return bt.compareTo(at);
      });

    // ===== Agrupación por día (corte del día) =====
    final Map<DateTime, _DailyAgg> dayMap = {};

    DateTime dayKey(DateTime d) => DateTime(d.year, d.month, d.day);

    for (final sale in filteredSales) {
      final k = dayKey(sale.createdAt);
      final agg = dayMap.putIfAbsent(k, () => _DailyAgg(day: k));
      agg.tickets += 1;
      agg.totalSales += sale.total;

      final method =
          sale.paymentMethod.trim().isEmpty ? 'cash' : sale.paymentMethod.trim();
      final ok = _sumItems(sale, cancelled: false);
      agg.netByMethod[method] = (agg.netByMethod[method] ?? 0.0) + ok;
    }

    for (final s in filteredSessions) {
      final k = dayKey(s.openedAt);
      final agg = dayMap.putIfAbsent(k, () => _DailyAgg(day: k));
      agg.totalCancelled += s.cancelledTotal;
      agg.closedSessions += 1;
    }

    final dailyList = dayMap.values.toList()
      ..sort((a, b) => b.day.compareTo(a.day));

    final sortedCashiers = cashiersCtrl.cashiers.toList()
      ..sort((a, b) => a.name.toLowerCase().compareTo(b.name.toLowerCase()));

    return DefaultTabController(
      length: 2,
      child: Column(
        children: [
          // Header + filtros
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 14, 16, 8),
            child: Row(
              children: [
                const Icon(Icons.history),
                const SizedBox(width: 10),
                const Expanded(
                  child: Text(
                    'Historial de cortes',
                    style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                  ),
                ),
                IconButton(
                  tooltip: 'Cerrar',
                  onPressed: () => Navigator.of(context).pop(),
                  icon: const Icon(Icons.close),
                ),
              ],
            ),
          ),

          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Wrap(
              spacing: 12,
              runSpacing: 12,
              crossAxisAlignment: WrapCrossAlignment.center,
              children: [
                DropdownButton<_RangePreset>(
                  value: _preset,
                  onChanged: (v) => setState(() => _preset = v ?? _RangePreset.week),
                  items: const [
                    DropdownMenuItem(value: _RangePreset.day, child: Text('Día')),
                    DropdownMenuItem(value: _RangePreset.week, child: Text('Semana')),
                    DropdownMenuItem(value: _RangePreset.month, child: Text('Mes')),
                    DropdownMenuItem(value: _RangePreset.year, child: Text('Año')),
                    DropdownMenuItem(value: _RangePreset.custom, child: Text('Rango')),
                  ],
                ),

                OutlinedButton.icon(
                  onPressed: _pickBaseDate,
                  icon: const Icon(Icons.event),
                  label: Text('Base: ${_fmtDate(_baseDate)}'),
                ),

                if (_preset == _RangePreset.custom) ...[
                  OutlinedButton.icon(
                    onPressed: _pickFrom,
                    icon: const Icon(Icons.calendar_month),
                    label: Text('Desde: ${_fmtDate(_from ?? _baseDate)}'),
                  ),
                  OutlinedButton.icon(
                    onPressed: _pickTo,
                    icon: const Icon(Icons.calendar_month),
                    label: Text('Hasta: ${_fmtDate(_to ?? _baseDate)}'),
                  ),
                ],

                DropdownButton<String>(
                  value: _cashierId,
                  onChanged: (v) => setState(() => _cashierId = v ?? ''),
                  items: [
                    const DropdownMenuItem(value: '', child: Text('Todos los cajeros')),
                    ...sortedCashiers.map(
                      (c) => DropdownMenuItem(
                        value: c.id,
                        child: Text(c.name),
                      ),
                    ),
                  ],
                ),

                SizedBox(
                  width: 240,
                  child: TextField(
                    decoration: const InputDecoration(
                      labelText: 'Buscar por nombre de cajero',
                      isDense: true,
                      border: OutlineInputBorder(),
                    ),
                    onChanged: (v) => setState(() => _cashierNameSearch = v),
                  ),
                ),

                const SizedBox(width: 8),
                Text('Rango: ${_fmtDate(from)} → ${_fmtDate(to)}'),
              ],
            ),
          ),

          const SizedBox(height: 10),
          const TabBar(
            tabs: [
              Tab(icon: Icon(Icons.calendar_today), text: 'Cortes del día'),
              Tab(icon: Icon(Icons.point_of_sale), text: 'Cortes de cajero'),
            ],
          ),
          const Divider(height: 1),

          Expanded(
            child: TabBarView(
              children: [
                // =============================
                // TAB 1: Cortes del día (grid)
                // =============================
                Padding(
                  padding: const EdgeInsets.all(12),
                  child: dailyList.isEmpty
                      ? const Center(child: Text('No hay cortes en ese rango.'))
                      : LayoutBuilder(
                          builder: (context, c) {
                            final w = c.maxWidth;
                            final cols = w >= 900 ? 3 : (w >= 620 ? 2 : 1);

                            return GridView.builder(
                              itemCount: dailyList.length,
                              gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                                crossAxisCount: cols,
                                childAspectRatio: 3.2,
                                crossAxisSpacing: 12,
                                mainAxisSpacing: 12,
                              ),
                              itemBuilder: (_, i) {
                                final d = dailyList[i];
                                final net = d.totalSales - d.totalCancelled;

                                return InkWell(
                                  onTap: () {
  Navigator.of(context).pop(); // cierra el dialog

  final sessionCtrl = widget.parentContext.read<PosSessionController>();
  final cashiersCtrl = widget.parentContext.read<PosCashiersController>();

  Future.microtask(() {
    Navigator.of(widget.parentContext, rootNavigator: false).push(
      MaterialPageRoute(
        builder: (_) => MultiProvider(
          providers: [
            ChangeNotifierProvider<PosSessionController>.value(value: sessionCtrl),
            ChangeNotifierProvider<PosCashiersController>.value(value: cashiersCtrl),
          ],
          child: PosDailyCloseScreen(
            day: d.day,
            cashierId: _cashierId.trim().isEmpty ? null : _cashierId.trim(),
          ),
        ),
      ),
    );
  });
},


                                  child: Card(
                                    elevation: 3,
                                    child: Padding(
                                      padding: const EdgeInsets.all(12),
                                      child: Row(
                                        children: [
                                          const Icon(Icons.calendar_today),
                                          const SizedBox(width: 10),
                                          Expanded(
                                            child: Column(
                                              crossAxisAlignment: CrossAxisAlignment.start,
                                              mainAxisAlignment: MainAxisAlignment.center,
                                              children: [
                                                Text(
                                                  _fmtDate(d.day),
                                                  style: const TextStyle(
                                                    fontSize: 15,
                                                    fontWeight: FontWeight.bold,
                                                  ),
                                                ),
                                                const SizedBox(height: 4),
                                                Text('Tickets: ${d.tickets}  •  Cortes: ${d.closedSessions}'),
                                                Text(
                                                  'Bruto: \$${d.totalSales.toStringAsFixed(2)}  •  Cancel: \$${d.totalCancelled.toStringAsFixed(2)}',
                                                ),
                                              ],
                                            ),
                                          ),
                                          const SizedBox(width: 10),
                                          Text(
                                            '\$${net.toStringAsFixed(2)}',
                                            style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                                          ),
                                        ],
                                      ),
                                    ),
                                  ),
                                );
                              },
                            );
                          },
                        ),
                ),

                // =============================
                // TAB 2: Cortes de cajero (grid)
                // =============================
                Padding(
                  padding: const EdgeInsets.all(12),
                  child: filteredSessions.isEmpty
                      ? const Center(child: Text('No hay cortes de cajero en ese rango.'))
                      : LayoutBuilder(
                          builder: (context, c) {
                            final w = c.maxWidth;
                            final cols = w >= 900 ? 3 : (w >= 620 ? 2 : 1);

                            // helper: ventas de la sesión (por tiempo y cajero)
                            List<Sale> salesForSession(CashSession s) {
                              final start = s.openedAt;
                              final end = s.closedAt ?? s.openedAt;

                              return sessionCtrl.allSales.where((sale) {
                                if (sale.cashierId != s.cashierId) return false;
                                final created = sale.createdAt;
                                return !created.isBefore(start) && !created.isAfter(end);
                              }).toList();
                            }

                            double sumItems(Sale sale, {required bool cancelled}) {
                              return sale.items
                                  .where((i) => i.cancelled == cancelled)
                                  .fold(0.0, (sum, i) => sum + i.subtotal);
                            }

                            Map<String, double> netByMethodForSession(CashSession s) {
                              final map = <String, double>{};
                              final sales = salesForSession(s);

                              for (final sale in sales) {
                                final method = sale.paymentMethod.trim().isEmpty
                                    ? 'cash'
                                    : sale.paymentMethod.trim();
                                final ok = sumItems(sale, cancelled: false);
                                final canc = sumItems(sale, cancelled: true);
                                map[method] = (map[method] ?? 0.0) + (ok - canc);
                              }
                              return map;
                            }

                            return GridView.builder(
                              itemCount: filteredSessions.length,
                              gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                                crossAxisCount: cols,
                                childAspectRatio: 3.2,
                                crossAxisSpacing: 12,
                                mainAxisSpacing: 12,
                              ),
                              itemBuilder: (_, i) {
                                final s = filteredSessions[i];
                                final name = _cashierName(cashiersCtrl, s.cashierId);

                                final open = '${_fmtDate(s.openedAt)} ${_fmtTime(s.openedAt)}';
                                final close = s.closedAt == null
                                    ? '-'
                                    : '${_fmtDate(s.closedAt!)} ${_fmtTime(s.closedAt!)}';

                                final byMethod = netByMethodForSession(s);
                                final cashNet = byMethod['cash'] ?? 0.0;
                                double _sessionCashIn(CashSession s) {
  final dynamic d = s;
  try {
    final v = d.cashInTotal;
    if (v is num) return v.toDouble();
  } catch (_) {}
  return 0.0;
}

double _sessionCashOut(CashSession s) {
  final dynamic d = s;
  try {
    final v = d.cashOutTotal;
    if (v is num) return v.toDouble();
  } catch (_) {}
  return 0.0;
}
final cashIn = _sessionCashIn(s);
final cashOut = _sessionCashOut(s);
final expectedCash = s.openingAmount + cashNet + cashIn - cashOut;


                                double netAll = 0.0;
                                for (final v in byMethod.values) {
                                  netAll += v;
                                }

                                return InkWell(
                                  onTap: () {
                                    PosCashSessionDetailDialog.show(
                                      context,
                                      session: s,
                                      cashierName: name,
                                      allSales: sessionCtrl.allSales,
                                    );
                                  },
                                  child: Card(
                                    elevation: 3,
                                    child: Padding(
                                      padding: const EdgeInsets.all(12),
                                      child: Row(
                                        children: [
                                          const Icon(Icons.point_of_sale),
                                          const SizedBox(width: 10),
                                          Expanded(
                                            child: Column(
                                              crossAxisAlignment: CrossAxisAlignment.start,
                                              mainAxisAlignment: MainAxisAlignment.center,
                                              children: [
                                                Text(
                                                  name,
                                                  style: const TextStyle(
                                                    fontSize: 15,
                                                    fontWeight: FontWeight.bold,
                                                  ),
                                                ),
                                                const SizedBox(height: 4),
                                                Text('Apertura: $open'),
                                                Text('Cierre:   $close'),
                                                Text('Efectivo esperado: \$${expectedCash.toStringAsFixed(2)}'),
                                              ],
                                            ),
                                          ),
                                          const SizedBox(width: 10),
                                          Column(
                                            mainAxisAlignment: MainAxisAlignment.center,
                                            crossAxisAlignment: CrossAxisAlignment.end,
                                            children: [
                                              Text(
                                                '\$${netAll.toStringAsFixed(2)}',
                                                style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                                              ),
                                              Text(
                                                'Cancel: \$${s.cancelledTotal.toStringAsFixed(2)}',
                                                style: const TextStyle(fontWeight: FontWeight.w600),
                                              ),
                                            ],
                                          ),
                                        ],
                                      ),
                                    ),
                                  ),
                                );
                              },
                            );
                          },
                        ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _DailyAgg {
  final DateTime day;
  int tickets = 0;
  int closedSessions = 0;
  double totalSales = 0.0;
  double totalCancelled = 0.0;

  final Map<String, double> netByMethod = {};

  _DailyAgg({required this.day});
}

// ======================================================
// ✅ DIALOG: Detalle de un corte de cajero histórico
// ======================================================

class PosCashSessionDetailDialog {
  static Future<void> show(
    BuildContext context, {
    required CashSession session,
    required String cashierName,
    required List<Sale> allSales,
  }) {
    String fmtDt(DateTime dt) {
      final d = dt.day.toString().padLeft(2, '0');
      final m = dt.month.toString().padLeft(2, '0');
      final y = dt.year.toString();
      final hh = dt.hour.toString().padLeft(2, '0');
      final mm = dt.minute.toString().padLeft(2, '0');
      return '$d/$m/$y $hh:$mm';
    }

    double cancelledAmountOfSale(Sale sale) {
      double sum = 0.0;
      for (final it in sale.items) {
        if (it.cancelled) sum += it.subtotal;
      }
      return sum;
    }

    double netSaleAmount(Sale sale) => sale.total - cancelledAmountOfSale(sale);

    final openTime = session.openedAt;
    final endTime = session.closedAt ?? session.openedAt;

    final sessionSales = allSales.where((sale) {
      if (sale.cashierId != session.cashierId) return false;
      final created = sale.createdAt;
      final afterOpen = !created.isBefore(openTime);
      final beforeEnd = !created.isAfter(endTime);
      return afterOpen && beforeEnd;
    }).toList();

    double cashGross = 0.0;
    double cashRefunds = 0.0;

    double cardNet = 0.0;
    double transferNet = 0.0;
    double creditNet = 0.0;
    double otherNet = 0.0;

    for (final sale in sessionSales) {
      final pm = sale.paymentMethod.trim().toLowerCase();
      final canc = cancelledAmountOfSale(sale);
      final net = netSaleAmount(sale);

      if (pm == 'cash') {
        cashGross += sale.total;
        cashRefunds += canc;
      } else if (pm == 'card') {
        cardNet += net;
      } else if (pm == 'transfer') {
        transferNet += net;
      } else if (pm == 'credit') {
        creditNet += net;
      } else {
        otherNet += net;
      }
    }

    final cashNetSales = cashGross - cashRefunds;
    final expectedCash = session.openingAmount + cashNetSales;

    // dept totals (sin cancelados)
    final Map<String, double> deptTotals = {};
    for (final sale in sessionSales) {
      for (final item in sale.items) {
        if (item.cancelled) continue;
        final deptRaw = item.product.department.trim();
        final dept = deptRaw.isEmpty ? 'GENERAL' : deptRaw;
        deptTotals[dept] = (deptTotals[dept] ?? 0.0) + item.subtotal;
      }
    }

    Widget moneyRow(String label, double value, {bool bold = false}) {
      return ListTile(
        dense: true,
        title: Text(label, style: bold ? const TextStyle(fontWeight: FontWeight.bold) : null),
        trailing: Text(
          '\$${value.toStringAsFixed(2)}',
          style: bold ? const TextStyle(fontWeight: FontWeight.bold, fontSize: 16) : null,
        ),
      );
    }

    return showDialog<void>(
      context: context,
      builder: (_) => AlertDialog(
        title: Text('Corte de caja - $cashierName'),
        content: SizedBox(
          width: 520,
          child: SingleChildScrollView(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Apertura: ${fmtDt(session.openedAt)}'),
                Text('Cierre:   ${session.closedAt == null ? '-' : fmtDt(session.closedAt!)}'),
                const SizedBox(height: 12),
                const Divider(),

                moneyRow('Fondo inicial', session.openingAmount),
                const Divider(),

                const Text('Ventas por método (neto)',
                    style: TextStyle(fontWeight: FontWeight.bold)),
                const SizedBox(height: 6),

                moneyRow('Efectivo (cobrado)', cashGross),
                moneyRow('Efectivo (cancelado/refund)', -cashRefunds),
                moneyRow('Efectivo neto por ventas', cashNetSales, bold: true),

                const SizedBox(height: 6),
                moneyRow('Tarjeta (neto)', cardNet),
                moneyRow('Transferencia (neto)', transferNet),
                moneyRow('Crédito (neto)', creditNet),
                if (otherNet.abs() > 0.000001) moneyRow('Otros (neto)', otherNet),

                const Divider(),
                moneyRow('Efectivo esperado en caja', expectedCash, bold: true),

                const SizedBox(height: 16),
                const Text('Ventas por departamento (sin cancelados)',
                    style: TextStyle(fontWeight: FontWeight.bold)),
                const SizedBox(height: 6),

                if (deptTotals.isEmpty)
                  const Text('No hay ventas registradas en esta sesión.')
                else
                  ...deptTotals.entries.map(
                    (e) => ListTile(
                      dense: true,
                      title: Text(e.key),
                      trailing: Text('\$${e.value.toStringAsFixed(2)}'),
                    ),
                  ),
              ],
            ),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Cerrar'),
          ),
        ],
      ),
    );
  }
}
