// lib/modules/pos_unicaja/widgets/pos_receipt_preview.dart
import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:intl/intl.dart';
import 'dart:io';

import 'package:framework_as/modules/pos_unicaja/controllers/pos_print_template_controller.dart';
import 'package:framework_as/modules/pos_unicaja/controllers/pos_cashiers_controller.dart';
import 'package:framework_as/modules/pos_unicaja/models/pos_print_template.dart';
import 'package:framework_as/modules/pos_unicaja/models/sale.dart';
import 'package:framework_as/modules/pos_unicaja/widgets/pos_payment_dialog.dart';
import 'package:framework_as/modules/pos_unicaja/peripherals/pos_peripheral_actions.dart';
import 'package:framework_as/core/branding/customer_branding_service.dart';
import 'package:framework_as/core/customers/customer_provider.dart';

class PosReceiptPreviewScreen extends StatelessWidget {
  final Sale sale;
  final PosPaymentResult? payment;
  final String? customerName;
  final File? logoFile;
  final String? cashierNameOverride;

  const PosReceiptPreviewScreen({
    super.key,
    required this.sale,
    this.payment,
    this.customerName,
    this.logoFile,
    this.cashierNameOverride,
  });

  @override
  Widget build(BuildContext context) {
    // 🛡️ ANTI-CRASH: Datos por defecto si faltan
    String finalCustomerName = customerName ?? "MI NEGOCIO";
    if (customerName == null) {
      try { finalCustomerName = context.watch<CustomerProvider>().config.name; } catch (_) {}
    }

    File? finalLogo = logoFile;
    if (logoFile == null) {
      try { finalLogo = CustomerBrandingService.instance.logoFile.value; } catch (_) {}
    }

    String finalCashierName = cashierNameOverride ?? sale.cashierId;
    if (cashierNameOverride == null) {
      try {
        final c = Provider.of<PosCashiersController>(context, listen: false).findById(sale.cashierId);
        if (c != null) finalCashierName = c.name;
      } catch (_) {}
    }

    final finalPayment = payment ?? PosPaymentResult(
      method: _methodFromCode(sale.paymentMethod),
      paidAmount: sale.paidAmount,
      change: sale.change,
      printTicket: false,
      creditCustomerId: sale.customerId,
      creditCustomerName: sale.customerId,
    );

    return FutureBuilder<PosPrintTemplate>(
      future: PosPrintTemplateController.loadOnce(),
      builder: (context, snap) {
        if (!snap.hasData) {
          return Scaffold(
            appBar: AppBar(title: const Text('Vista previa del ticket')),
            body: const Center(child: CircularProgressIndicator()),
          );
        }

        final template = snap.data!;

        return Scaffold(
          backgroundColor: Colors.grey[100],
          appBar: AppBar(
            title: const Text('Vista previa del ticket'),
            centerTitle: true,
          ),
          body: Center(
            child: SingleChildScrollView(
              padding: const EdgeInsets.symmetric(vertical: 24),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  PosTicketWidget(
                    customerName: finalCustomerName,
                    logoFile: finalLogo,
                    template: template,
                    sale: sale,
                    payment: finalPayment,
                    cashierName: finalCashierName,
                  ),
                  const SizedBox(height: 24),
                  Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      OutlinedButton(
                        onPressed: () => Navigator.of(context).pop(),
                        child: const Text('Cerrar'),
                      ),
                      const SizedBox(width: 16),
                      ElevatedButton.icon(
                        icon: const Icon(Icons.print),
                        label: const Text('Imprimir'),
                        onPressed: () => _print(context, template, finalCustomerName, finalCashierName, finalPayment, finalLogo),
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
  }

  Future<void> _print(BuildContext context, PosPrintTemplate template, String cName, String kName, PosPaymentResult pay, File? logo) async {
    try {
      Uint8List? logoBytes;
      if (template.showLogo && logo != null && await logo.exists()) {
        logoBytes = await logo.readAsBytes();
      }

      final bytes = await buildPdf(
        customerName: cName,
        template: template,
        sale: sale,
        payment: pay,
        logoBytes: logoBytes,
        cashierDisplayName: kName,
      );

      await PosPeripheralActions.printTicketAuto(
        customerName: cName,
        template: template,
        sale: sale,
        payment: pay,
        pdfBytes: bytes,
        jobName: 'ticket_${sale.id}.pdf',
      );

      if (context.mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Enviado a imprimir.')));
    } catch (e) {
      if (context.mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error: $e')));
    }
  }

  static PosPaymentMethod _methodFromCode(String code) {
    switch (code) {
      case 'card': return PosPaymentMethod.card;
      case 'transfer': return PosPaymentMethod.transfer;
      case 'credit': return PosPaymentMethod.credit;
      default: return PosPaymentMethod.cash;
    }
  }

  // =========================
  // GENERADOR PDF (Impresión Real)
  // =========================
  static Future<Uint8List> buildPdf({
    required String customerName,
    required PosPrintTemplate template,
    required Sale sale,
    required PosPaymentResult payment,
    Uint8List? logoBytes,
    String? cashierDisplayName,
  }) async {
    final doc = pw.Document();
    final mm = PdfPageFormat.mm;
    final width = template.paperWidthMm * mm;
    final pageFormat = PdfPageFormat(width, double.infinity, marginAll: 0);

    // Cálculos
    final double savings = sale.rawTotal - sale.total;
    final int totalItems = sale.items.fold(0, (sum, i) => sum + i.quantity.ceil());

    doc.addPage(
      pw.Page(
        pageFormat: pageFormat,
        margin: pw.EdgeInsets.only(
          left: template.marginLeftMm * mm,
          right: template.marginRightMm * mm,
          top: 5 * mm,
          bottom: 10 * mm,
        ),
        build: (_) {
          final fontReg = pw.Font.helvetica();
          final fontBold = pw.Font.helveticaBold();
          final align = _pdfTextAlign(template.headerAlign);
          
          final styleReg = pw.TextStyle(font: fontReg, fontSize: 9);
          final styleBold = pw.TextStyle(font: fontBold, fontSize: 9, fontWeight: pw.FontWeight.bold);
          final styleSmall = pw.TextStyle(font: fontReg, fontSize: 7, color: PdfColors.grey700);
          
          // ✅ AHORRO GRANDE PDF
          final styleSavings = pw.TextStyle(font: fontBold, fontSize: 13, fontWeight: pw.FontWeight.bold);

          return pw.Column(
            crossAxisAlignment: pw.CrossAxisAlignment.stretch,
            children: [
              // Logo
              if (logoBytes != null) ...[
                pw.Center(child: pw.Image(pw.MemoryImage(logoBytes), height: 45, fit: pw.BoxFit.contain)),
                pw.SizedBox(height: 6),
              ],
              
              // Nombre Negocio (Siempre visible)
              pw.Text(customerName.toUpperCase(), textAlign: align, style: styleBold.copyWith(fontSize: 12)),
              
              // Dirección / Teléfono
              if (template.showBusinessAddress && (template.headerLine1?.isNotEmpty ?? false))
                pw.Text(template.headerLine1!, textAlign: align, style: styleReg),
              if (template.showBusinessPhone && (template.headerLine2?.isNotEmpty ?? false))
                pw.Text(template.headerLine2!, textAlign: align, style: styleReg),

              pw.SizedBox(height: 6),
              _dashedLinePdf(),

              // Meta
              if (template.showSaleMeta) ...[
                if (template.showFolio) 
                  pw.Row(mainAxisAlignment: pw.MainAxisAlignment.spaceBetween, children: [
                    pw.Text('FOLIO:', style: styleBold),
                    pw.Text(sale.id, style: styleReg),
                  ]),
                if (template.showDatetime) 
                  pw.Row(mainAxisAlignment: pw.MainAxisAlignment.spaceBetween, children: [
                    pw.Text('FECHA:', style: styleBold),
                    pw.Text(_fmtDate(sale.createdAt), style: styleReg),
                  ]),
              ],

              pw.SizedBox(height: 4),
              _dashedLinePdf(),

              // Encabezados
              pw.Row(children: [
                pw.Expanded(flex: 3, child: pw.Text('PRODUCTO', style: styleBold)),
                pw.Expanded(flex: 1, child: pw.Text('CANT', style: styleBold, textAlign: pw.TextAlign.center)),
                if (template.showUnitPrice)
                  pw.Expanded(flex: 1, child: pw.Text('PRECIO', style: styleBold, textAlign: pw.TextAlign.right)),
                pw.Expanded(flex: 1, child: pw.Text('TOTAL', style: styleBold, textAlign: pw.TextAlign.right)),
              ]),
              pw.SizedBox(height: 4),

              // Items
              ...sale.items.map((item) {
                // ✅ Usamos el unitPrice inteligente
                final unitPrice = item.unitPrice;
                final subtotal = item.subtotal;

                return pw.Container(
                  margin: const pw.EdgeInsets.only(bottom: 2),
                  child: pw.Row(
                    crossAxisAlignment: pw.CrossAxisAlignment.start,
                    children: [
                      // Nombre y promo
                      pw.Expanded(
                        flex: 3, 
                        child: pw.Column(
                          crossAxisAlignment: pw.CrossAxisAlignment.start,
                          children: [
                            pw.Text(item.product.name, style: styleReg),
                            if (item.promoName != null)
                              pw.Text(item.promoName!, style: styleSmall.copyWith(fontSize: 6)),
                          ]
                        )
                      ),
                      
                      pw.Expanded(flex: 1, child: pw.Text('${_fmtQty(item.quantity)}', style: styleReg, textAlign: pw.TextAlign.center)),
                      
                      if (template.showUnitPrice)
                        pw.Expanded(flex: 1, child: pw.Text(_money(unitPrice), style: styleReg, textAlign: pw.TextAlign.right)),
                      
                      pw.Expanded(flex: 1, child: pw.Text(_money(subtotal), style: styleReg, textAlign: pw.TextAlign.right)),
                    ],
                  ),
                );
              }),

              pw.SizedBox(height: 4),
              _dashedLinePdf(),

              // Arts
              pw.Row(mainAxisAlignment: pw.MainAxisAlignment.end, children: [
                pw.Text('Arts: $totalItems', style: styleSmall),
              ]),

              // Total
              pw.Row(mainAxisAlignment: pw.MainAxisAlignment.spaceBetween, children: [
                pw.Text('TOTAL', style: styleBold.copyWith(fontSize: 14)),
                pw.Text(_money(sale.total), style: styleBold.copyWith(fontSize: 14)),
              ]),

              // ✅ AHORRO GRANDE (Solo si > 0)
              if (savings > 0.01) ...[
                pw.SizedBox(height: 6),
                pw.Center(
                  child: pw.Text('¡AHORRASTE: ${_money(savings)}!', style: styleSavings),
                ),
                pw.SizedBox(height: 2),
              ],

              pw.SizedBox(height: 6),

              if (template.showPaymentInfo) ...[
                _pdfRow('Forma de pago:', _paymentLabel(payment), styleReg),
                if (payment.method == PosPaymentMethod.cash) ...[
                  _pdfRow('Efectivo:', _money(payment.paidAmount), styleReg),
                  _pdfRow('Cambio:', _money(payment.change), styleBold),
                ],
                if (payment.method == PosPaymentMethod.credit)
                  pw.Text('Cliente: ${payment.creditCustomerName ?? ""}', style: styleReg),
              ],

              pw.SizedBox(height: 8),

              if (cashierDisplayName != null && template.showCashier)
                pw.Text('Le atendió: $cashierDisplayName', textAlign: pw.TextAlign.center, style: styleReg),

              if (template.showThankYou) ...[
                pw.SizedBox(height: 4),
                pw.Text(template.footerText, textAlign: pw.TextAlign.center, style: styleReg),
              ],
              
              // ✅ MARCA DE AGUA ELIMINADA

              pw.SizedBox(height: 8),
              pw.Container(
                height: 35,
                width: double.infinity,
                child: pw.BarcodeWidget(
                  barcode: pw.Barcode.code128(),
                  data: sale.id,
                  drawText: false,
                  height: 35,
                ),
              ),
              pw.Center(child: pw.Text(sale.id, style: styleSmall)),
            ],
          );
        },
      ),
    );
    return doc.save();
  }

  static pw.Widget _dashedLinePdf() {
    return pw.Text('----------------------------------------------------------------', 
      maxLines: 1, 
      style: pw.TextStyle(fontSize: 8, color: PdfColors.grey600),
      overflow: pw.TextOverflow.clip,
    );
  }

  static pw.TextAlign _pdfTextAlign(String align) {
    if (align == 'left') return pw.TextAlign.left;
    if (align == 'right') return pw.TextAlign.right;
    return pw.TextAlign.center;
  }

  static pw.Widget _pdfRow(String label, String value, pw.TextStyle style) {
    return pw.Row(
      mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
      children: [pw.Text(label, style: style), pw.Text(value, style: style)],
    );
  }
}

// =========================
// Widget Visual (PÚBLICO - Pantalla)
// =========================
class PosTicketWidget extends StatelessWidget {
  const PosTicketWidget({
    super.key,
    required this.customerName,
    required this.template,
    required this.sale,
    required this.payment,
    this.logoFile,
    this.cashierName,
  });

  final String customerName;
  final PosPrintTemplate template;
  final Sale sale;
  final PosPaymentResult payment;
  final File? logoFile;
  final String? cashierName;

  @override
  Widget build(BuildContext context) {
    final scale = template.fontScale;
    final styleReg = TextStyle(fontFamily: 'RobotoMono', fontSize: 12 * scale, color: Colors.black);
    final styleBold = TextStyle(fontFamily: 'RobotoMono', fontSize: 12 * scale, fontWeight: FontWeight.bold, color: Colors.black);
    final styleSmall = TextStyle(fontFamily: 'RobotoMono', fontSize: 10 * scale, color: Colors.grey[700]);
    
    // ✅ AHORRO GRANDE PANTALLA (letra 20)
    final styleLargeSavings = TextStyle(fontFamily: 'RobotoMono', fontSize: 20 * scale, fontWeight: FontWeight.w900, color: Colors.black);

    final double savings = sale.rawTotal - sale.total;
    final int totalItems = sale.items.fold(0, (sum, i) => sum + i.quantity.ceil());

    TextAlign align;
    CrossAxisAlignment crossAlign;
    switch (template.headerAlign) {
      case 'left': align = TextAlign.left; crossAlign = CrossAxisAlignment.start; break;
      case 'right': align = TextAlign.right; crossAlign = CrossAxisAlignment.end; break;
      default: align = TextAlign.center; crossAlign = CrossAxisAlignment.center; break;
    }

    return Card(
      elevation: 4,
      margin: EdgeInsets.zero,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.zero),
      child: Container(
        width: 320, 
        color: Colors.white,
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          mainAxisSize: MainAxisSize.min,
          children: [
            // Header
            Column(
              crossAxisAlignment: crossAlign,
              children: [
                if (logoFile != null && template.showLogo) ...[
                  Image.file(logoFile!, height: 60, fit: BoxFit.contain),
                  const SizedBox(height: 8),
                ],
                Text(customerName.toUpperCase(), style: styleBold.copyWith(fontSize: 14 * scale), textAlign: align),
                
                if (template.showBusinessAddress && (template.headerLine1?.isNotEmpty ?? false))
                  Text(template.headerLine1!, style: styleReg, textAlign: align),
                if (template.showBusinessPhone && (template.headerLine2?.isNotEmpty ?? false))
                  Text(template.headerLine2!, style: styleReg, textAlign: align),
              ],
            ),
            
            const SizedBox(height: 8),
            _dashedLine(),

            if (template.showSaleMeta) ...[
              if (template.showFolio) _row('FOLIO:', sale.id, styleReg),
              if (template.showDatetime) _row('FECHA:', _fmtDate(sale.createdAt), styleReg),
            ],
            
            const SizedBox(height: 4),
            _dashedLine(),

            Row(children: [
              Expanded(flex: 3, child: Text('PRODUCTO', style: styleBold)),
              Expanded(flex: 1, child: Text('CANT', style: styleBold, textAlign: TextAlign.center)),
              if (template.showUnitPrice)
                Expanded(flex: 2, child: Text('PRECIO', style: styleBold, textAlign: TextAlign.right)),
              Expanded(flex: 2, child: Text('TOTAL', style: styleBold, textAlign: TextAlign.right)),
            ]),
            const SizedBox(height: 6),

            ...sale.items.map((item) {
              // ✅ Usamos el unitPrice inteligente
              final unitPrice = item.unitPrice;
              final subtotal = item.subtotal;

              return Padding(
                padding: const EdgeInsets.only(bottom: 4),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(
                      flex: 3, 
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(item.product.name, style: styleReg),
                          if (item.promoName != null)
                             Text(item.promoName!, style: styleSmall.copyWith(fontSize: 9 * scale, fontStyle: FontStyle.italic)),
                        ]
                      )
                    ),
                    Expanded(flex: 1, child: Text('${_fmtQty(item.quantity)}', style: styleReg, textAlign: TextAlign.center)),
                    if (template.showUnitPrice)
                      Expanded(flex: 2, child: Text(_money(unitPrice), style: styleReg, textAlign: TextAlign.right)),
                    Expanded(flex: 2, child: Text(_money(subtotal), style: styleReg, textAlign: TextAlign.right)),
                  ],
                ),
              );
            }),
            
            _dashedLine(),

            Align(
              alignment: Alignment.centerRight,
              child: Text('Arts: $totalItems', style: styleSmall),
            ),

            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text('TOTAL', style: styleBold.copyWith(fontSize: 18 * scale)),
                Text(_money(sale.total), style: styleBold.copyWith(fontSize: 18 * scale)),
              ],
            ),

            // ✅ AHORRO GRANDE (Solo si > 0)
            if (savings > 0.01) ...[
              const SizedBox(height: 12),
              Text('¡AHORRASTE: ${_money(savings)}!', 
                style: styleLargeSavings, textAlign: TextAlign.center),
              const SizedBox(height: 4),
            ],

            const SizedBox(height: 12),

            if (template.showPaymentInfo) ...[
              _row('Forma de pago:', _paymentLabel(payment), styleReg),
              if (payment.method == PosPaymentMethod.cash) ...[
                _row('Efectivo:', _money(payment.paidAmount), styleReg),
                _row('Cambio:', _money(payment.change), styleBold),
              ],
            ],
            const SizedBox(height: 16),

            if (cashierName != null && template.showCashier)
              Text('Le atendió: $cashierName', style: styleReg, textAlign: TextAlign.center),
            
            if (template.showThankYou) ...[
              const SizedBox(height: 8),
              Text(template.footerText, style: styleReg, textAlign: TextAlign.center),
            ],

            // ✅ MARCA DE AGUA ELIMINADA

            const SizedBox(height: 8),
            Container(
              height: 40,
              alignment: Alignment.center,
              child: Column(
                children: [
                  Row(mainAxisAlignment: MainAxisAlignment.center, children: List.generate(40, (i) => Container(width: i%3==0?2:1, height: 25, color: Colors.black, margin: const EdgeInsets.symmetric(horizontal: 1)))),
                  Text(sale.id, style: styleSmall),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _dashedLine() {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Text(
        '------------------------------------------------------------',
        maxLines: 1,
        overflow: TextOverflow.clip,
        style: TextStyle(color: Colors.grey[400], letterSpacing: 2),
      ),
    );
  }

  Widget _row(String label, String val, TextStyle style) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [Text(label, style: style), Text(val, style: style)],
    );
  }
}

String _money(double v) => '\$${v.toStringAsFixed(2)}';
String _fmtDate(DateTime d) => DateFormat('dd/MM/yyyy HH:mm').format(d);
String _fmtQty(double q) => (q % 1 == 0) ? q.toInt().toString() : q.toStringAsFixed(3);

String _paymentLabel(PosPaymentResult p) {
  switch (p.method) {
    case PosPaymentMethod.cash: return 'Efectivo';
    case PosPaymentMethod.card: return 'Tarjeta';
    case PosPaymentMethod.transfer: return 'Transferencia';
    case PosPaymentMethod.credit: return 'Crédito';
  }
}