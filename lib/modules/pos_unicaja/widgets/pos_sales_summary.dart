import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:framework_as/modules/pos_unicaja/controllers/pos_session.dart';
import 'package:framework_as/modules/pos_unicaja/models/sale.dart';
import 'package:framework_as/modules/pos_unicaja/models/sale_item.dart';
import 'package:framework_as/modules/pos_unicaja/widgets/pos_receipt_preview.dart';
import 'package:framework_as/modules/pos_unicaja/controllers/pos_cashiers_controller.dart';
import 'package:framework_as/core/customers/customer_provider.dart';
import 'package:framework_as/core/branding/customer_branding_service.dart';
import 'package:framework_as/modules/pos_unicaja/widgets/pos_payment_dialog.dart';

class PosSalesSummaryScreen extends StatefulWidget {
  const PosSalesSummaryScreen({super.key});

  @override
  State<PosSalesSummaryScreen> createState() => _PosSalesSummaryScreenState();
}

enum _SummaryFilter { week, month, prevMonth, year, custom }

class _PosSalesSummaryScreenState extends State<PosSalesSummaryScreen> {
  _SummaryFilter _filter = _SummaryFilter.week;
  late DateTime _customFrom;
  late DateTime _customTo;

  @override
  void initState() {
    super.initState();
    final today = _truncateDate(DateTime.now());
    _customFrom = today;
    _customTo = today;
  }

  DateTime _truncateDate(DateTime d) => DateTime(d.year, d.month, d.day);

  DateTimeRange _currentRange() {
    final today = _truncateDate(DateTime.now());
    switch (_filter) {
      case _SummaryFilter.week:
        final start = today.subtract(Duration(days: today.weekday - 1));
        final end = start.add(const Duration(days: 6));
        return DateTimeRange(start: start, end: end);
      case _SummaryFilter.month:
        final start = DateTime(today.year, today.month, 1);
        final end = DateTime(today.year, today.month + 1, 0);
        return DateTimeRange(start: start, end: end);
      case _SummaryFilter.prevMonth:
        final int year = today.month == 1 ? today.year - 1 : today.year;
        final int month = today.month == 1 ? 12 : today.month - 1;
        final start = DateTime(year, month, 1);
        final end = DateTime(year, month + 1, 0);
        return DateTimeRange(start: start, end: end);
      case _SummaryFilter.year:
        final start = DateTime(today.year, 1, 1);
        final end = DateTime(today.year, 12, 31);
        return DateTimeRange(start: start, end: end);
      case _SummaryFilter.custom:
        return DateTimeRange(start: _truncateDate(_customFrom), end: _truncateDate(_customTo));
    }
  }

  bool _isInRange(DateTime date, DateTimeRange range) {
    final d = _truncateDate(date);
    return !d.isBefore(range.start) && !d.isAfter(range.end);
  }

  @override
  Widget build(BuildContext context) {
    final ctrl = context.watch<PosSessionController>();
    final allSales = ctrl.allSales;
    final cashier = ctrl.currentCashier;
    final canSummary = cashier != null && (cashier.isAdmin || cashier.canSalesSummary || cashier.canViewReports);

    if (!canSummary) {
      return Scaffold(
        appBar: AppBar(title: const Text('Resumen de ventas')),
        body: const Center(child: Text('No tienes permiso.')),
      );
    }

    final range = _currentRange();
    final List<Sale> sales = allSales.where((s) => _isInRange(s.createdAt, range)).toList()
      ..sort((a, b) => b.createdAt.compareTo(a.createdAt));

    double totalSales = 0;
    double totalCost = 0;
    
    final Map<String, double> salesByDept = {};
    final Map<DateTime, double> salesByDay = {};
    final Map<String, double> salesByPayment = {};

    for (final sale in sales) {
      totalSales += sale.total;
      final pm = sale.paymentMethod.isEmpty ? 'Sin especificar' : _paymentLabel(sale.paymentMethod);
      salesByPayment[pm] = (salesByPayment[pm] ?? 0) + sale.total;
      final day = _truncateDate(sale.createdAt);
      salesByDay[day] = (salesByDay[day] ?? 0) + sale.total;

      for (final SaleItem item in sale.items) {
        if (item.cancelled) continue;
        final dept = item.product.department.isEmpty ? 'GENERAL' : item.product.department;
        totalCost += item.product.costPrice * item.quantity;
        salesByDept[dept] = (salesByDept[dept] ?? 0) + item.subtotal;
      }
    }

    final double profit = totalSales - totalCost;
    final double margin = totalSales == 0 ? 0 : (profit / totalSales) * 100.0;
    
    return Scaffold(
      appBar: AppBar(title: const Text('Resumen de ventas')),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: ListView(
          children: [
            _buildFilterRow(),
            const SizedBox(height: 10),
            _buildSummaryCard(context, totalSales, profit, margin, sales.length),
            const SizedBox(height: 20),
            const Divider(),
            const Text('Historial de Tickets', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
            const SizedBox(height: 10),
            _buildSalesList(context, sales),
            const SizedBox(height: 40),
          ],
        ),
      ),
    );
  }

  Widget _buildSalesList(BuildContext context, List<Sale> sales) {
    if (sales.isEmpty) return const Text('No hay ventas.');
    return Card(
      child: Column(
        children: sales.map((sale) {
          return ListTile(
            leading: const Icon(Icons.receipt),
            title: Text('Folio: ${sale.id}'),
            subtitle: Text('${_fmtDate(sale.createdAt)} • ${_paymentLabel(sale.paymentMethod)}'),
            trailing: Text('\$${sale.total.toStringAsFixed(2)}', style: const TextStyle(fontWeight: FontWeight.bold)),
            onTap: () {
              final customerConfig = context.read<CustomerProvider>().config;
              final logoFile = CustomerBrandingService.instance.logoFile.value;
              
              String cashierName = sale.cashierId;
              try {
                final c = context.read<PosCashiersController>().findById(sale.cashierId);
                if (c != null) cashierName = c.name;
              } catch (_) {}

              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) => PosReceiptPreviewScreen(
                    sale: sale,
                    payment: PosPaymentResult(
                      method: _methodFromCode(sale.paymentMethod),
                      paidAmount: sale.paidAmount,
                      change: sale.change,
                      printTicket: false,
                    ),
                    customerName: customerConfig.name,
                    logoFile: logoFile,
                    cashierNameOverride: cashierName,
                  ),
                ),
              );
            },
          );
        }).toList(),
      ),
    );
  }

  Widget _buildFilterRow() {
    return Wrap(
      spacing: 8,
      children: [
        ChoiceChip(label: const Text('Semana'), selected: _filter == _SummaryFilter.week, onSelected: (_) => setState(() => _filter = _SummaryFilter.week)),
        ChoiceChip(label: const Text('Mes'), selected: _filter == _SummaryFilter.month, onSelected: (_) => setState(() => _filter = _SummaryFilter.month)),
        ChoiceChip(label: const Text('Año'), selected: _filter == _SummaryFilter.year, onSelected: (_) => setState(() => _filter = _SummaryFilter.year)),
      ],
    );
  }

  Widget _buildSummaryCard(BuildContext context, double total, double profit, double margin, int tickets) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            Text('Ventas Totales: \$${total.toStringAsFixed(2)}', style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
            Text('Ganancia: \$${profit.toStringAsFixed(2)}'),
            Text('Margen: ${margin.toStringAsFixed(1)}%'),
            Text('Tickets: $tickets'),
          ],
        ),
      ),
    );
  }

  String _fmtDate(DateTime d) => '${d.day}/${d.month} ${d.hour}:${d.minute.toString().padLeft(2, '0')}';
  
  String _paymentLabel(String method) {
    switch (method) {
      case 'cash': return 'Efectivo';
      case 'card': return 'Tarjeta';
      case 'transfer': return 'Transferencia';
      case 'voucher': return 'Vales';
      default: return method;
    }
  }

  PosPaymentMethod _methodFromCode(String code) {
    switch (code) {
      case 'card': return PosPaymentMethod.card;
      case 'transfer': return PosPaymentMethod.transfer;
      case 'credit': return PosPaymentMethod.credit;
      default: return PosPaymentMethod.cash;
    }
  }
}