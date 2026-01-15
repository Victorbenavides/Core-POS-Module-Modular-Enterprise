import 'dart:typed_data';

import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;

import 'package:framework_as/modules/pos_unicaja/models/sale.dart';
import 'package:framework_as/modules/pos_unicaja/models/sale_item.dart';

Future<Uint8List> buildPosReceiptPdf({
  required PdfPageFormat format,
  required String businessName,
  required Sale sale,
  Uint8List? logoBytes,
  double? cashReceived,
  double? change,
  String? transferAccount,
  String? transferFromName,
}) async {
  final doc = pw.Document();

  String fmtDate(DateTime d) {
    String two(int n) => n.toString().padLeft(2, '0');
    return '${two(d.day)}/${two(d.month)}/${d.year} ${two(d.hour)}:${two(d.minute)}';
  }

  String payLabel(String method) {
    switch (method) {
      case 'cash':
        return 'Efectivo';
      case 'card':
        return 'Tarjeta';
      case 'transfer':
        return 'Transferencia';
      default:
        return method;
    }
  }

  pw.Widget lineItem(SaleItem it) {
    final name = it.product.name;
    final qty = it.quantity;
    final price = it.product.salePrice;
    final sub = it.subtotal;

    return pw.Padding(
      padding: const pw.EdgeInsets.symmetric(vertical: 2),
      child: pw.Row(
        crossAxisAlignment: pw.CrossAxisAlignment.start,
        children: [
          pw.Expanded(
            child: pw.Text(name, style: const pw.TextStyle(fontSize: 9)),
          ),
          pw.SizedBox(width: 6),
          pw.Text(qty.toStringAsFixed(2), style: const pw.TextStyle(fontSize: 9)),
          pw.SizedBox(width: 6),
          pw.Text('\$${price.toStringAsFixed(2)}', style: const pw.TextStyle(fontSize: 9)),
          pw.SizedBox(width: 6),
          pw.Text('\$${sub.toStringAsFixed(2)}', style: const pw.TextStyle(fontSize: 9)),
        ],
      ),
    );
  }

  doc.addPage(
    pw.Page(
      pageFormat: format,
      margin: const pw.EdgeInsets.all(10),
      build: (_) {
        return pw.Column(
          crossAxisAlignment: pw.CrossAxisAlignment.stretch,
          children: [
            // =========================
            // LOGO (SI EXISTE)
            // =========================
            if (logoBytes != null)
              pw.Center(
                child: pw.Image(
                  pw.MemoryImage(logoBytes),
                  height: 34,
                  fit: pw.BoxFit.contain,
                ),
              ),

            if (logoBytes != null) pw.SizedBox(height: 6),

            // =========================
            // NOMBRE NEGOCIO
            // =========================
            pw.Center(
              child: pw.Text(
                businessName.toUpperCase(),
                style: pw.TextStyle(
                  fontSize: 12,
                  fontWeight: pw.FontWeight.bold,
                ),
              ),
            ),

            pw.SizedBox(height: 4),
            pw.Center(
              child: pw.Text(
                'Ticket #${sale.id}',
                style: const pw.TextStyle(fontSize: 9),
              ),
            ),

            pw.Text(
              'Fecha: ${fmtDate(sale.createdAt)}',
              style: const pw.TextStyle(fontSize: 9),
            ),
            pw.Text(
              'Pago: ${payLabel(sale.paymentMethod)}',
              style: const pw.TextStyle(fontSize: 9),
            ),

            pw.Divider(),

            // =========================
            // ENCABEZADO TABLA
            // =========================
            pw.Row(
              children: [
                pw.Expanded(
                  child: pw.Text(
                    'Producto',
                    style: pw.TextStyle(fontSize: 9, fontWeight: pw.FontWeight.bold),
                  ),
                ),
                pw.SizedBox(width: 6),
                pw.Text(
                  'Cant',
                  style: pw.TextStyle(fontSize: 9, fontWeight: pw.FontWeight.bold),
                ),
                pw.SizedBox(width: 6),
                pw.Text(
                  'P/U',
                  style: pw.TextStyle(fontSize: 9, fontWeight: pw.FontWeight.bold),
                ),
                pw.SizedBox(width: 6),
                pw.Text(
                  'Imp',
                  style: pw.TextStyle(fontSize: 9, fontWeight: pw.FontWeight.bold),
                ),
              ],
            ),

            pw.SizedBox(height: 4),

            // =========================
            // ITEMS
            // =========================
            ...sale.items.map(lineItem),

            pw.Divider(),

            // =========================
            // TOTAL
            // =========================
            pw.Row(
              mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
              children: [
                pw.Text(
                  'TOTAL',
                  style: pw.TextStyle(fontSize: 11, fontWeight: pw.FontWeight.bold),
                ),
                pw.Text(
                  '\$${sale.total.toStringAsFixed(2)}',
                  style: pw.TextStyle(fontSize: 11, fontWeight: pw.FontWeight.bold),
                ),
              ],
            ),

            // =========================
            // EFECTIVO
            // =========================
            if (sale.paymentMethod == 'cash' && cashReceived != null) ...[
              pw.SizedBox(height: 6),
              pw.Row(
                mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                children: [
                  pw.Text('PAGÓ CON', style: const pw.TextStyle(fontSize: 9)),
                  pw.Text('\$${cashReceived.toStringAsFixed(2)}', style: const pw.TextStyle(fontSize: 9)),
                ],
              ),
              pw.Row(
                mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                children: [
                  pw.Text('CAMBIO', style: const pw.TextStyle(fontSize: 9)),
                  pw.Text('\$${(change ?? 0).toStringAsFixed(2)}', style: const pw.TextStyle(fontSize: 9)),
                ],
              ),
            ],

            // =========================
            // TRANSFERENCIA
            // =========================
            if (sale.paymentMethod == 'transfer') ...[
              pw.SizedBox(height: 6),
              if (transferAccount != null)
                pw.Text('Cuenta: $transferAccount', style: const pw.TextStyle(fontSize: 9)),
              if ((transferFromName ?? '').trim().isNotEmpty)
                pw.Text('Transfiere: $transferFromName', style: const pw.TextStyle(fontSize: 9)),
            ],

            pw.SizedBox(height: 10),
            pw.Center(
              child: pw.Text(
                '¡Gracias por tu compra!',
                style: const pw.TextStyle(fontSize: 9),
              ),
            ),
          ],
        );
      },
    ),
  );

  return doc.save();
}
