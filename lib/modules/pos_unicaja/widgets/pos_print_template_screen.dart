import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:framework_as/modules/pos_unicaja/controllers/pos_print_template_controller.dart';
import 'package:framework_as/modules/pos_unicaja/models/pos_print_template.dart';
import 'package:framework_as/modules/pos_unicaja/widgets/pos_receipt_preview.dart';
import 'package:framework_as/core/customers/customer_provider.dart';
import 'package:framework_as/core/branding/customer_branding_service.dart';
import 'package:framework_as/modules/pos_unicaja/models/sale.dart';
import 'package:framework_as/modules/pos_unicaja/models/sale_item.dart';
import 'package:framework_as/modules/pos_unicaja/models/product.dart';
import 'package:framework_as/modules/pos_unicaja/widgets/pos_payment_dialog.dart';

class PosPrintTemplateScreen extends StatefulWidget {
  const PosPrintTemplateScreen({super.key});

  @override
  State<PosPrintTemplateScreen> createState() => _PosPrintTemplateScreenState();
}

class _PosPrintTemplateScreenState extends State<PosPrintTemplateScreen> {
  PosPrintTemplate _temp = PosPrintTemplate.defaults();
  bool _dirty = false;
  bool _loading = true;

  final Sale _demoSale = Sale(
    id: 'DEMO-123',
    createdAt: DateTime.now(),
    cashierId: 'Cajero 1',
    paymentMethod: 'cash',
    items: [
      const SaleItem(
        product: Product(id: '1', name: 'Coca Cola 600ml', barcode: '123', salePrice: 18.00, costPrice: 10, gainPercent: 0, wholesalePrice: 0, usesInventory: false, stock: 0, minStock: 0, maxStock: 0, isWeighed: false),
        quantity: 2,
      ),
      const SaleItem(
        product: Product(id: '2', name: 'Sabritas Sal', barcode: '124', salePrice: 15.00, costPrice: 10, gainPercent: 0, wholesalePrice: 0, usesInventory: false, stock: 0, minStock: 0, maxStock: 0, isWeighed: false),
        quantity: 1,
      ),
    ],
    total: 51.00,
    paidAmount: 100.00,
    change: 49.00,
  );

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _loadTemplate();
    });
  }

  Future<void> _loadTemplate() async {
    try {
      final ctrl = context.read<PosPrintTemplateController>();
      await ctrl.load();
      if (mounted) {
        setState(() {
          _temp = ctrl.template;
          _loading = false;
        });
      }
    } catch (e) {
      if (mounted) setState(() => _loading = false);
    }
  }

  void _update(PosPrintTemplate newT) {
    setState(() {
      _temp = newT;
      _dirty = true;
    });
  }

  Future<void> _save() async {
    try {
      await context.read<PosPrintTemplateController>().update(_temp);
      setState(() => _dirty = false);
      if (mounted) {
        // ✅ FIX: Anti-stacking (Limpiar notificaciones previas)
        ScaffoldMessenger.of(context).clearSnackBars();
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Guardado.')));
      }
    } catch (e) {
      if (mounted) {
        // ✅ FIX: Anti-stacking
        ScaffoldMessenger.of(context).clearSnackBars();
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Error al guardar.')));
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final customer = context.watch<CustomerProvider>().config;

    if (_loading) {
      return Scaffold(
        appBar: AppBar(title: const Text('Cargando configuración...')),
        body: const Center(child: CircularProgressIndicator()),
      );
    }

    return Scaffold(
      appBar: AppBar(
        title: const Text('Configurar Ticket'),
        actions: [
          if (_dirty)
            IconButton(icon: const Icon(Icons.save), onPressed: _save),
        ],
      ),
      body: Row(
        children: [
          Expanded(
            flex: 4,
            child: ListView(
              padding: const EdgeInsets.all(16),
              children: [
                _switch('Mostrar Logo', _temp.showLogo, (v) => _update(_temp.copyWith(showLogo: v))),
                _switch('Nombre de Negocio', true, null),
                _switch('Dirección', _temp.showBusinessAddress, (v) => _update(_temp.copyWith(showBusinessAddress: v))),
                _switch('Teléfono', _temp.showBusinessPhone, (v) => _update(_temp.copyWith(showBusinessPhone: v))),
                const Divider(),
                _switch('Folio', _temp.showFolio, (v) => _update(_temp.copyWith(showFolio: v))),
                _switch('Fecha y Hora', _temp.showDatetime, (v) => _update(_temp.copyWith(showDatetime: v))),
                _switch('Nombre Cajero', _temp.showCashier, (v) => _update(_temp.copyWith(showCashier: v))),
                const Divider(),
                _switch('Desglose de Pago', _temp.showPaymentInfo, (v) => _update(_temp.copyWith(showPaymentInfo: v))),
                _switch('Mensaje de Gracias', _temp.showThankYou, (v) => _update(_temp.copyWith(showThankYou: v))),
                const SizedBox(height: 10),
                TextFormField(
                  initialValue: _temp.footerText,
                  decoration: const InputDecoration(labelText: 'Pie de página', border: OutlineInputBorder()),
                  onChanged: (v) => _update(_temp.copyWith(footerText: v)),
                ),
                const SizedBox(height: 20),
                const Text('Configuración Técnica', style: TextStyle(fontWeight: FontWeight.bold)),
                _switch('Mostrar vista previa al cobrar', _temp.showPreviewOnPrint, (v) => _update(_temp.copyWith(showPreviewOnPrint: v))),
              ],
            ),
          ),
          
          Expanded(
            flex: 5,
            child: Container(
              color: Colors.grey[200],
              alignment: Alignment.center,
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(20),
                child: PosTicketWidget(
                  template: _temp,
                  customerName: customer.name,
                  logoFile: CustomerBrandingService.instance.logoFile.value,
                  sale: _demoSale,
                  payment: PosPaymentResult(
                    method: PosPaymentMethod.cash,
                    paidAmount: _demoSale.paidAmount,
                    change: _demoSale.change,
                    printTicket: false,
                  ),
                  cashierName: 'Juan Pérez',
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _switch(String label, bool val, Function(bool)? onChanged) {
    return SwitchListTile(
      title: Text(label),
      value: val,
      onChanged: onChanged,
      contentPadding: EdgeInsets.zero,
    );
  }
}