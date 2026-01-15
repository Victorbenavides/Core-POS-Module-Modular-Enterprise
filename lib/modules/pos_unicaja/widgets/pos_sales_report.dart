import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'dart:io';
import 'dart:typed_data';

import 'package:framework_as/modules/pos_unicaja/controllers/pos_session.dart';
import 'package:framework_as/modules/pos_unicaja/controllers/pos_cashiers_controller.dart';
import 'package:framework_as/modules/pos_unicaja/controllers/pos_inventory_controller.dart';

import 'package:framework_as/modules/pos_unicaja/models/sale.dart';
import 'package:framework_as/modules/pos_unicaja/models/sale_item.dart';
import 'package:framework_as/modules/pos_unicaja/models/cashier.dart';

import 'package:framework_as/modules/pos_unicaja/credits/pos_credits_controller.dart';

import 'package:framework_as/core/customers/customer_provider.dart';
import 'package:framework_as/core/customers/customer_asset_loader.dart';
import 'package:framework_as/core/branding/customer_branding_service.dart';

import 'package:framework_as/modules/pos_unicaja/controllers/pos_print_template_controller.dart';
import 'package:framework_as/modules/pos_unicaja/models/pos_print_template.dart';

import 'package:framework_as/modules/pos_unicaja/widgets/pos_receipt_preview.dart';
import 'package:framework_as/modules/pos_unicaja/widgets/pos_payment_dialog.dart';
import 'package:framework_as/modules/pos_unicaja/peripherals/pos_peripheral_actions.dart';

// ✅ Definimos las clases y enums AQUÍ ARRIBA o al final, pero fuera de las clases
// para evitar los errores de "Undefined name" que te salían.
enum _SalesRangePreset { day, week, month, year, custom }

class _SalesDayAgg {
  final DateTime day;
  int tickets = 0;
  double baseOk = 0.0;
  double baseCancelled = 0.0;

  _SalesDayAgg({required this.day});
}

class PosSalesReportScreen extends StatefulWidget {
  final DateTime? day;
  final String? cashierId;

  const PosSalesReportScreen({
    super.key,
    this.day,
    this.cashierId,
  });

  @override
  State<PosSalesReportScreen> createState() => _PosSalesReportScreenState();
}

class _PosSalesReportScreenState extends State<PosSalesReportScreen> {
  String _cashierId = '';
  String _query = '';
  bool _showCancelledOnly = false;

  @override
  void initState() {
    super.initState();
    _cashierId = (widget.cashierId ?? '').trim();
  }

  // ✅ Helper para mostrar mensajes rápidos (borra el anterior)
  void _showSnack(String msg) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).clearSnackBars();
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(msg), duration: const Duration(seconds: 2)),
    );
  }

  bool _isSameDay(DateTime a, DateTime b) =>
      a.year == b.year && a.month == b.month && a.day == b.day;

  String _formatTime(DateTime dt) =>
      '${dt.hour.toString().padLeft(2, '0')}:${dt.minute.toString().padLeft(2, '0')}';

  String _formatDate(DateTime dt) =>
      '${dt.day.toString().padLeft(2, '0')}/${dt.month.toString().padLeft(2, '0')}/${dt.year}';

  String _cashierName(String cashierId, List<Cashier> cashiers) {
    for (final c in cashiers) {
      if (c.id == cashierId) return c.name;
    }
    return 'Cajero $cashierId';
  }

  String _pmLabel(String pm) {
    switch (pm) {
      case 'cash': return 'Efectivo';
      case 'card': return 'Tarjeta';
      case 'transfer': return 'Transferencia';
      case 'credit': return 'Crédito';
      default: return pm.isEmpty ? 'Desconocido' : pm;
    }
  }

  double _totalOf(Iterable<SaleItem> items, {bool cancelled = false}) {
    return items
        .where((i) => i.cancelled == cancelled)
        .fold(0.0, (sum, i) => sum + i.subtotal);
  }

  bool _isSaleFullyCancelled(Sale sale) {
    if (sale.items.isEmpty) return false;
    return sale.items.every((i) => i.cancelled);
  }

  bool _isCreditSale(Sale sale) =>
      sale.paymentMethod.toLowerCase() == 'credit' &&
      sale.customerId.trim().isNotEmpty;

  Sale _getUpdatedSale(PosSessionController sessionCtrl, Sale fallback) {
    try {
      return sessionCtrl.allSales.firstWhere((s) => s.id == fallback.id);
    } catch (_) {
      return fallback;
    }
  }

  bool _canReprintSale(Sale sale) {
    final cutoff = DateTime.now().subtract(const Duration(days: 30));
    return !sale.createdAt.isBefore(cutoff);
  }

  PosPaymentMethod _methodFromCode(String code) {
    switch (code.toLowerCase()) {
      case 'cash': return PosPaymentMethod.cash;
      case 'card': return PosPaymentMethod.card;
      case 'transfer': return PosPaymentMethod.transfer;
      case 'credit': return PosPaymentMethod.credit;
      default: return PosPaymentMethod.cash;
    }
  }

  Future<void> _reprintSale(Sale sale) async {
    final customer = context.read<CustomerProvider>().config;
    final logoFile = CustomerBrandingService.instance.logoFile.value;

    String cashierName = sale.cashierId;
    try {
      final c = context.read<PosCashiersController>().findById(sale.cashierId);
      if (c != null) cashierName = c.name;
    } catch (_) {}

    try {
      final template = await PosPrintTemplateController.loadOnce();
      if (!mounted) return;

      final method = _methodFromCode(sale.paymentMethod);

      final payment = PosPaymentResult(
        method: method,
        paidAmount: sale.paidAmount > 0 ? sale.paidAmount : sale.total,
        change: sale.change,
        creditCustomerId: sale.customerId.trim().isEmpty ? null : sale.customerId.trim(),
        creditCustomerName: sale.customerId.trim().isEmpty ? null : sale.customerId.trim(),
        printTicket: true,
      );

      if (template.showPreviewOnPrint) {
        await Navigator.of(context).push(
          MaterialPageRoute(
            builder: (_) => PosReceiptPreviewScreen(
              sale: sale,
              payment: payment,
              customerName: customer.name,
              logoFile: logoFile,
              cashierNameOverride: cashierName,
            ),
          ),
        );
        return;
      }

      Uint8List? logoBytes;
      if (template.showLogo && logoFile != null && await logoFile.exists()) {
        logoBytes = await logoFile.readAsBytes();
      } else if (template.showLogo && customer.logo.isNotEmpty) {
        try {
          logoBytes = await CustomerAssets.bytes(customer.logo);
        } catch (_) {}
      }

      final pdfBytes = await PosReceiptPreviewScreen.buildPdf(
        customerName: customer.name,
        template: template,
        sale: sale,
        payment: payment,
        logoBytes: logoBytes,
        cashierDisplayName: cashierName,
      );

      await PosPeripheralActions.printTicketAuto(
        customerName: customer.name,
        template: template,
        sale: sale,
        payment: payment,
        pdfBytes: pdfBytes,
        jobName: 'reprint_ticket_${sale.id}.pdf',
      );

      _showSnack('Ticket reenviado a imprimir.');
    } catch (e) {
      _showSnack('Error reimprimiendo: $e');
    }
  }


  Future<void> _syncCreditAfterCancel(
    PosSessionController sessionCtrl,
    Sale originalSale,
  ) async {
    if (!_isCreditSale(originalSale)) return;

    final updated = _getUpdatedSale(sessionCtrl, originalSale);
    await PosCreditsController.instance.onSaleUpdatedAfterCancellation(updated);
  }

  String _shortTicket(String id) {
    final s = id.toString();
    if (s.length <= 6) return s;
    return s.substring(s.length - 6);
  }

  String _fmtQty(SaleItem item) {
    final p = item.product;
    final v = item.quantity;
    if (p.isWeighed) return v.toStringAsFixed(3);
    final nearInt = (v - v.roundToDouble()).abs() < 0.000001;
    return nearInt ? v.round().toString() : v.toStringAsFixed(3);
  }

  Future<void> _pickDate(DateTime selectedDay) async {
    final picked = await showDatePicker(
      context: context,
      initialDate: selectedDay,
      firstDate: DateTime(2020, 1, 1),
      lastDate: DateTime.now().add(const Duration(days: 3650)),
    );
    if (picked == null) return;
    if (!mounted) return;

    final sessionCtrl = context.read<PosSessionController>();
    final cashiersCtrl = context.read<PosCashiersController>();
    final inventoryCtrl = context.read<PosInventoryController>();

    Navigator.of(context).pushReplacement(
      MaterialPageRoute(
        builder: (_) => MultiProvider(
          providers: [
            ChangeNotifierProvider<PosSessionController>.value(value: sessionCtrl),
            ChangeNotifierProvider<PosCashiersController>.value(value: cashiersCtrl),
            ChangeNotifierProvider<PosInventoryController>.value(value: inventoryCtrl),
          ],
          child: PosSalesReportScreen(
            day: picked,
            cashierId: _cashierId.trim().isEmpty ? null : _cashierId.trim(),
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final sessionCtrl = context.watch<PosSessionController>();
    final cashiersCtrl = context.watch<PosCashiersController>();
    final inventoryCtrl = context.read<PosInventoryController>();

    final cashier = sessionCtrl.currentCashier;
    final bool canViewReport = cashier != null &&
        (cashier.isAdmin || cashier.canSalesReport || cashier.canViewReports);

    if (!canViewReport) {
      return Scaffold(
        appBar: AppBar(title: const Text('Reporte de ventas')),
        body: const Center(child: Text('No tienes permiso para ver Reportes.')),
      );
    }

    final bool canCancelSales =
        cashier != null && (cashier.isAdmin || cashier.canCancelSales);

    final selectedDay = widget.day ?? DateTime.now();
    final isToday = _isSameDay(selectedDay, DateTime.now());

    final bool allowMutations = isToday && sessionCtrl.hasOpenSession && canCancelSales;

    final sortedCashiers = cashiersCtrl.cashiers.toList()
      ..sort((a, b) => a.name.toLowerCase().compareTo(b.name.toLowerCase()));
    final cashierIds = sortedCashiers.map((e) => e.id).toSet();
    final dropdownCashierValue = cashierIds.contains(_cashierId) ? _cashierId : '';

    List<Sale> salesDay = sessionCtrl.salesForDay(selectedDay);

    final cid = _cashierId.trim();
    if (cid.isNotEmpty) {
      salesDay = salesDay.where((s) => s.cashierId == cid).toList();
    }

    final q = _query.trim().toLowerCase();
    if (q.isNotEmpty) {
      salesDay = salesDay.where((sale) {
        if (sale.id.toLowerCase().contains(q)) return true;
        if (sale.paymentMethod.toLowerCase().contains(q)) return true;
        if (sale.customerId.toLowerCase().contains(q)) return true;

        final cName = _cashierName(sale.cashierId, cashiersCtrl.cashiers).toLowerCase();
        if (cName.contains(q)) return true;

        for (final it in sale.items) {
          if (it.product.name.toLowerCase().contains(q)) return true;
          if (it.product.barcode.toLowerCase().contains(q)) return true;
        }
        return false;
      }).toList();
    }

    if (_showCancelledOnly) {
      salesDay = salesDay.where(_isSaleFullyCancelled).toList();
    }

    final titleDate = _formatDate(selectedDay);
    final title = isToday ? 'Reporte de ventas (hoy)' : 'Reporte de ventas ($titleDate)';

    return Scaffold(
      appBar: AppBar(
        title: Text(title),
        actions: [
          IconButton(
            tooltip: 'Elegir fecha',
            icon: const Icon(Icons.event),
            onPressed: () => _pickDate(selectedDay),
          ),
          IconButton(
            tooltip: 'Historial de ventas',
            icon: const Icon(Icons.history),
            onPressed: () {
              PosSalesHistoryDialog.show(context, initialBaseDate: selectedDay);
            },
          ),
        ],
      ),
      body: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          children: [
            Card(
              elevation: 2,
              child: Padding(
                padding: const EdgeInsets.all(12),
                child: Wrap(
                  spacing: 12,
                  runSpacing: 12,
                  crossAxisAlignment: WrapCrossAlignment.center,
                  children: [
                    DropdownButton<String>(
                      value: dropdownCashierValue,
                      onChanged: (v) => setState(() => _cashierId = v ?? ''),
                      items: <DropdownMenuItem<String>>[
                        const DropdownMenuItem<String>(
                          value: '',
                          child: Text('Todos los cajeros'),
                        ),
                        ...sortedCashiers.map(
                          (c) => DropdownMenuItem<String>(
                            value: c.id,
                            child: Text(c.name),
                          ),
                        ),
                      ],
                    ),
                    SizedBox(
                      width: 320,
                      child: TextField(
                        decoration: const InputDecoration(
                          labelText: 'Buscar (ticket, producto, barcode, cajero, cliente)',
                          isDense: true,
                          border: OutlineInputBorder(),
                        ),
                        onChanged: (v) => setState(() => _query = v),
                      ),
                    ),
                    FilterChip(
                      label: const Text('Solo canceladas'),
                      selected: _showCancelledOnly,
                      onSelected: (v) => setState(() => _showCancelledOnly = v),
                    ),
                    if (!allowMutations)
                      Padding(
                        padding: const EdgeInsets.only(left: 8),
                        child: Text(
                          isToday
                              ? 'Cancelación deshabilitada (no hay caja abierta o sin permiso).'
                              : 'Cancelación deshabilitada en días anteriores.',
                          style: TextStyle(
                            color: Colors.orange.shade800,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 10),
            Expanded(
              child: salesDay.isEmpty
                  ? Center(
                      child: Text(
                        isToday
                            ? 'No hay ventas registradas en el día de hoy.'
                            : 'No hay ventas registradas en esta fecha.',
                      ),
                    )
                  : ListView.builder(
                      itemCount: salesDay.length,
                      itemBuilder: (_, index) {
                        final sale = salesDay[index];

                        final timeStr = _formatTime(sale.createdAt);
                        final cName = _cashierName(sale.cashierId, cashiersCtrl.cashiers);

                        final double baseOk = _totalOf(sale.items, cancelled: false);
                        final double baseCancelled = _totalOf(sale.items, cancelled: true);

                        final bool fullyCancelled = _isSaleFullyCancelled(sale);

                        return Card(
                          margin: const EdgeInsets.symmetric(vertical: 6),
                          child: ExpansionTile(
                            tilePadding:
                                const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                            title: Row(
                              children: [
                                Expanded(
                                  child: Row(
                                    children: [
                                      Text('$timeStr — Ticket #${_shortTicket(sale.id)}'),
                                      const SizedBox(width: 8),
                                      if (fullyCancelled)
                                        Container(
                                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                                          decoration: BoxDecoration(
                                            color: Colors.red.shade100,
                                            borderRadius: BorderRadius.circular(20),
                                          ),
                                          child: Text(
                                            'CANCELADA',
                                            style: TextStyle(
                                              color: Colors.red.shade700,
                                              fontSize: 11,
                                              fontWeight: FontWeight.bold,
                                            ),
                                          ),
                                        ),
                                    ],
                                  ),
                                ),
                                IconButton(
                                  tooltip: _canReprintSale(sale)
                                      ? 'Reimprimir ticket'
                                      : 'Solo disponible en últimos 30 días',
                                  icon: const Icon(Icons.print),
                                  onPressed: _canReprintSale(sale)
                                      ? () => _reprintSale(sale)
                                      : null,
                                ),
                              ],
                            ),
                            subtitle: Text(
                              '$cName\n'
                              'Método: ${_pmLabel(sale.paymentMethod)}'
                              '${sale.paymentMethod == 'credit' && sale.customerId.isNotEmpty ? '  •  Cliente: ${sale.customerId}' : ''}\n'
                              'Registrado: \$${sale.total.toStringAsFixed(2)}  •  '
                              'Vigente (base): \$${baseOk.toStringAsFixed(2)}  •  '
                              'Cancelado (base): \$${baseCancelled.toStringAsFixed(2)}',
                            ),
                            children: [
                              const Divider(height: 1),
                              ...sale.items.asMap().entries.map((entry) {
                                final i = entry.key;
                                final item = entry.value;
                                final isCancelled = item.cancelled;

                                return ListTile(
                                  dense: true,
                                  leading: Icon(
                                    isCancelled
                                        ? Icons.cancel_outlined
                                        : Icons.check_circle_outline,
                                    color: isCancelled
                                        ? Colors.red.shade400
                                        : Colors.green.shade400,
                                  ),
                                  title: Text(
                                    item.product.name,
                                    style: TextStyle(
                                      decoration: isCancelled
                                          ? TextDecoration.lineThrough
                                          : TextDecoration.none,
                                    ),
                                  ),
                                  subtitle: Text(
                                    'Cant: ${_fmtQty(item)} ${item.product.unit}  '
                                    '• P.U.: \$${item.product.salePrice.toStringAsFixed(2)}',
                                  ),
                                  trailing: Column(
                                    mainAxisAlignment: MainAxisAlignment.center,
                                    crossAxisAlignment: CrossAxisAlignment.end,
                                    children: [
                                      Text(
                                        '\$${item.subtotal.toStringAsFixed(2)}',
                                        style: const TextStyle(fontWeight: FontWeight.w600),
                                      ),
                                      if (!isCancelled && allowMutations)
                                        TextButton(
                                          onPressed: () async {
                                            final messenger = ScaffoldMessenger.of(context);

                                            final confirm = await showDialog<bool>(
                                              context: context,
                                              builder: (dialogCtx) => AlertDialog(
                                                title: const Text('Cancelar artículo'),
                                                content: Text(
                                                    '¿Cancelar "${item.product.name}" de esta venta?'),
                                                actions: [
                                                  TextButton(
                                                    onPressed: () =>
                                                        Navigator.of(dialogCtx).pop(false),
                                                    child: const Text('No'),
                                                  ),
                                                  ElevatedButton(
                                                    onPressed: () =>
                                                        Navigator.of(dialogCtx).pop(true),
                                                    child: const Text('Sí, cancelar'),
                                                  ),
                                                ],
                                              ),
                                            );

                                            if (confirm != true) return;

                                            sessionCtrl.cancelSaleItem(
                                              saleId: sale.id,
                                              itemIndex: i,
                                            );

                                            inventoryCtrl.restoreStock(
                                              item.product.id,
                                              item.quantity,
                                            );

                                            await _syncCreditAfterCancel(sessionCtrl, sale);

                                            messenger.clearSnackBars();
                                            messenger.showSnackBar(
                                              const SnackBar(
                                                content: Text('Artículo cancelado correctamente.'),
                                                duration: Duration(seconds: 2),
                                              ),
                                            );
                                          },
                                          child: const Text('Cancelar'),
                                        ),
                                    ],
                                  ),
                                );
                              }).toList(),
                              if (allowMutations && !fullyCancelled)
                                Padding(
                                  padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
                                  child: Align(
                                    alignment: Alignment.centerRight,
                                    child: TextButton.icon(
                                      onPressed: () async {
                                        final messenger = ScaffoldMessenger.of(context);

                                        final confirm = await showDialog<bool>(
                                          context: context,
                                          builder: (dialogCtx) => AlertDialog(
                                            title: const Text('Cancelar venta completa'),
                                            content: const Text(
                                              '¿Cancelar TODOS los artículos de esta venta?\n\n'
                                              'Se devolverá el inventario y se registrará el monto como cancelado.',
                                            ),
                                            actions: [
                                              TextButton(
                                                onPressed: () =>
                                                    Navigator.of(dialogCtx).pop(false),
                                                child: const Text('No'),
                                              ),
                                              ElevatedButton(
                                                onPressed: () =>
                                                    Navigator.of(dialogCtx).pop(true),
                                                child: const Text('Sí, cancelar venta'),
                                              ),
                                            ],
                                          ),
                                        );

                                        if (confirm != true) return;

                                        for (final it in sale.items) {
                                          if (!it.cancelled) {
                                            inventoryCtrl.restoreStock(it.product.id, it.quantity);
                                          }
                                        }

                                        sessionCtrl.cancelEntireSale(sale.id);

                                        await _syncCreditAfterCancel(sessionCtrl, sale);

                                        messenger.clearSnackBars();
                                        messenger.showSnackBar(
                                          const SnackBar(
                                            content: Text('Venta cancelada correctamente.'),
                                            duration: Duration(seconds: 2),
                                          ),
                                        );
                                      },
                                      icon: const Icon(Icons.delete_forever),
                                      label: const Text('Cancelar toda la venta'),
                                      style: TextButton.styleFrom(
                                        foregroundColor: Colors.red,
                                      ),
                                    ),
                                  ),
                                ),
                            ],
                          ),
                        );
                      },
                    ),
            ),
          ],
        ),
      ),
    );
  }
}

class PosSalesHistoryDialog extends StatefulWidget {
  final DateTime? initialBaseDate;
  final BuildContext parentContext;

  const PosSalesHistoryDialog({
    super.key,
    this.initialBaseDate,
    required this.parentContext,
  });

  static Future<void> show(
    BuildContext context, {
    DateTime? initialBaseDate,
  }) {
    final parentContext = context;
    final sessionCtrl = parentContext.read<PosSessionController>();
    final cashiersCtrl = parentContext.read<PosCashiersController>();
    final inventoryCtrl = parentContext.read<PosInventoryController>();

    return showDialog<void>(
      context: parentContext,
      barrierDismissible: true,
      builder: (_) => MultiProvider(
        providers: [
          ChangeNotifierProvider<PosSessionController>.value(value: sessionCtrl),
          ChangeNotifierProvider<PosCashiersController>.value(value: cashiersCtrl),
          ChangeNotifierProvider<PosInventoryController>.value(value: inventoryCtrl),
        ],
        child: Dialog(
          insetPadding: const EdgeInsets.all(16),
          child: LayoutBuilder(
            builder: (dialogContext, c) {
              final w = (c.maxWidth * 0.96).clamp(680.0, 1400.0);
              final h = (c.maxHeight * 0.94).clamp(520.0, 900.0);

              return SizedBox(
                width: w,
                height: h,
                child: PosSalesHistoryDialog(
                  parentContext: parentContext,
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
  State<PosSalesHistoryDialog> createState() => _PosSalesHistoryDialogState();
}

class _PosSalesHistoryDialogState extends State<PosSalesHistoryDialog> {
  // ✅ Usamos el enum definido al inicio del archivo
  _SalesRangePreset _preset = _SalesRangePreset.week;

  late DateTime _baseDate;
  DateTime? _from;
  DateTime? _to;

  String _cashierId = '';
  String _cashierNameSearch = '';

  @override
  void initState() {
    super.initState();
    _baseDate = widget.initialBaseDate ?? DateTime.now();
  }

  DateTime _startOfDay(DateTime d) => DateTime(d.year, d.month, d.day);
  DateTime _endOfDay(DateTime d) => DateTime(d.year, d.month, d.day, 23, 59, 59, 999);

  String _fmtDate(DateTime dt) =>
      '${dt.day.toString().padLeft(2, '0')}/${dt.month.toString().padLeft(2, '0')}/${dt.year}';

  DateTime _weekStart(DateTime d) {
    final dd = _startOfDay(d);
    final delta = dd.weekday - DateTime.monday;
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

  (DateTime from, DateTime to) _calcRange() {
    switch (_preset) {
      case _SalesRangePreset.day:
        return (_startOfDay(_baseDate), _endOfDay(_baseDate));
      case _SalesRangePreset.week:
        return (_weekStart(_baseDate), _weekEnd(_baseDate));
      case _SalesRangePreset.month:
        return (_monthStart(_baseDate), _monthEnd(_baseDate));
      case _SalesRangePreset.year:
        return (_yearStart(_baseDate), _yearEnd(_baseDate));
      case _SalesRangePreset.custom:
        final f = _startOfDay(_from ?? _baseDate);
        final t = _endOfDay(_to ?? _baseDate);
        final okFrom = f.isBefore(t) ? f : t;
        final okTo = f.isBefore(t) ? t : f;
        return (okFrom, okTo);
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
    context.read<PosInventoryController>();

    final sortedCashiers = cashiersCtrl.cashiers.toList()
      ..sort((a, b) => a.name.toLowerCase().compareTo(b.name.toLowerCase()));
    final cashierIds = sortedCashiers.map((e) => e.id).toSet();
    final dropdownCashierValue = cashierIds.contains(_cashierId) ? _cashierId : '';

    final range = _calcRange();
    final from = range.$1;
    final to = range.$2;

    final cid = _cashierId.trim();

    final filteredSales = sessionCtrl.allSales.where((s) {
      if (s.createdAt.isBefore(from) || s.createdAt.isAfter(to)) return false;
      if (cid.isNotEmpty && s.cashierId != cid) return false;
      if (!_matchCashierName(cashiersCtrl, s.cashierId)) return false;
      return true;
    }).toList();

    DateTime dayKey(DateTime d) => DateTime(d.year, d.month, d.day);

    final Map<DateTime, _SalesDayAgg> map = {};
    for (final sale in filteredSales) {
      final k = dayKey(sale.createdAt);
      // ✅ Usamos la clase helper definida al inicio
      final agg = map.putIfAbsent(k, () => _SalesDayAgg(day: k));
      agg.tickets += 1;
      agg.baseOk += _sumItems(sale, cancelled: false);
      agg.baseCancelled += _sumItems(sale, cancelled: true);
    }

    final list = map.values.toList()..sort((a, b) => b.day.compareTo(a.day));

    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 14, 16, 8),
          child: Row(
            children: [
              const Icon(Icons.history),
              const SizedBox(width: 10),
              const Expanded(
                child: Text(
                  'Historial de ventas',
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
              DropdownButton<_SalesRangePreset>(
                value: _preset,
                onChanged: (v) => setState(() => _preset = v ?? _SalesRangePreset.week),
                items: const [
                  DropdownMenuItem(value: _SalesRangePreset.day, child: Text('Día')),
                  DropdownMenuItem(value: _SalesRangePreset.week, child: Text('Semana')),
                  DropdownMenuItem(value: _SalesRangePreset.month, child: Text('Mes')),
                  DropdownMenuItem(value: _SalesRangePreset.year, child: Text('Año')),
                  DropdownMenuItem(value: _SalesRangePreset.custom, child: Text('Rango')),
                ],
              ),
              OutlinedButton.icon(
                onPressed: _pickBaseDate,
                icon: const Icon(Icons.event),
                label: Text('Base: ${_fmtDate(_baseDate)}'),
              ),
              if (_preset == _SalesRangePreset.custom) ...[
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
                value: dropdownCashierValue,
                onChanged: (v) => setState(() => _cashierId = v ?? ''),
                items: <DropdownMenuItem<String>>[
                  const DropdownMenuItem<String>(
                    value: '',
                    child: Text('Todos los cajeros'),
                  ),
                  ...sortedCashiers.map(
                    (c) => DropdownMenuItem<String>(
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
              Text('Rango: ${_fmtDate(from)} → ${_fmtDate(to)}'),
            ],
          ),
        ),
        const SizedBox(height: 10),
        const Divider(height: 1),
        Expanded(
          child: list.isEmpty
              ? const Center(child: Text('No hay ventas en ese rango.'))
              : Padding(
                  padding: const EdgeInsets.all(12),
                  child: LayoutBuilder(
                    builder: (context, c) {
                      final w = c.maxWidth;
                      final cols = w >= 900 ? 3 : (w >= 620 ? 2 : 1);

                      return GridView.builder(
                        itemCount: list.length,
                        gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                          crossAxisCount: cols,
                          childAspectRatio: 3.2,
                          crossAxisSpacing: 12,
                          mainAxisSpacing: 12,
                        ),
                        itemBuilder: (_, i) {
                          final d = list[i];
                          final netBase = d.baseOk;
                          final cancBase = d.baseCancelled;

                          return InkWell(
                            onTap: () {
                              Navigator.of(context).pop();

                              final sessionCtrl =
                                  widget.parentContext.read<PosSessionController>();
                              final cashiersCtrl =
                                  widget.parentContext.read<PosCashiersController>();
                              final inventoryCtrl =
                                  widget.parentContext.read<PosInventoryController>();

                              Future.microtask(() {
                                Navigator.of(widget.parentContext).push(
                                  MaterialPageRoute(
                                    builder: (_) => MultiProvider(
                                      providers: [
                                        ChangeNotifierProvider<PosSessionController>.value(
                                            value: sessionCtrl),
                                        ChangeNotifierProvider<PosCashiersController>.value(
                                            value: cashiersCtrl),
                                        ChangeNotifierProvider<PosInventoryController>.value(
                                            value: inventoryCtrl),
                                      ],
                                      child: PosSalesReportScreen(
                                        day: d.day,
                                        cashierId:
                                            _cashierId.trim().isEmpty ? null : _cashierId.trim(),
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
                                          Text('Tickets: ${d.tickets}'),
                                          Text('Vigente (base): \$${netBase.toStringAsFixed(2)}'),
                                          Text(
                                              'Cancelado (base): \$${cancBase.toStringAsFixed(2)}'),
                                        ],
                                      ),
                                    ),
                                    const SizedBox(width: 10),
                                    Text(
                                      '\$${(netBase - cancBase).toStringAsFixed(2)}',
                                      style: const TextStyle(
                                          fontWeight: FontWeight.bold, fontSize: 16),
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
        ),
      ],
    );
  }
}