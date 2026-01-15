// lib/modules/pos_unicaja/peripherals/pos_peripheral_actions.dart
import 'dart:typed_data';

import 'package:pdf/widgets.dart' as pw;
import 'package:pdf/pdf.dart';
import 'package:printing/printing.dart';

import 'package:framework_as/modules/pos_unicaja/peripherals/pos_peripherals_store.dart';
import 'package:framework_as/modules/pos_unicaja/peripherals/pos_peripherals_settings.dart';
import 'package:framework_as/modules/pos_unicaja/peripherals/pos_escpos_network_printer.dart';
import 'package:framework_as/modules/pos_unicaja/peripherals/pos_escpos_ticket_builder.dart';

import 'package:framework_as/modules/pos_unicaja/models/pos_print_template.dart';
import 'package:framework_as/modules/pos_unicaja/models/sale.dart';
import 'package:framework_as/modules/pos_unicaja/widgets/pos_payment_dialog.dart';

class PosPeripheralActions {
  /// Abre cajón si:
  /// - openDrawerOnCash = true
  /// - modo = networkEscPos
  /// - networkHost configurado
  ///
  /// (El cajón casi siempre va conectado a la impresora por RJ11/RJ12, y se abre
  /// mandando ESC/POS "kick" a la impresora)
  static Future<void> openCashDrawerIfConfigured() async {
    final s = await PosPeripheralsStore.load();
    if (!s.openDrawerOnCash) return;

    // Solo se soporta confiablemente por RAW ESC/POS (red).
    if (s.printerMode != PosPrinterMode.networkEscPos) return;

    final host = s.networkHost.trim();
    if (host.isEmpty) return;

    await PosEscPosNetworkPrinter.send(
      host,
      s.networkPort,
      PosEscPosTicketBuilder.drawerKick(),
    );
  }

  /// Prueba de cajón (ignora openDrawerOnCash)
  static Future<void> openCashDrawerTest() async {
    final s = await PosPeripheralsStore.load();

    if (s.printerMode != PosPrinterMode.networkEscPos) {
      throw Exception('Para probar el cajón debes usar modo Red (RAW ESC/POS).');
    }

    final host = s.networkHost.trim();
    if (host.isEmpty) {
      throw Exception('Configura IP/Host de impresora (Red) para probar cajón.');
    }

    await PosEscPosNetworkPrinter.send(
      host,
      s.networkPort,
      PosEscPosTicketBuilder.drawerKick(),
    );
  }

  static Future<void> printPdfWithSettings(
    Uint8List pdfBytes, {
    required String jobName,
  }) async {
    final s = await PosPeripheralsStore.load();

    // Solo hacemos "direct print" si el modo es Windows.
    if (s.printerMode != PosPrinterMode.windowsDriver) {
      await Printing.layoutPdf(onLayout: (_) async => pdfBytes, name: jobName);
      return;
    }

    final wanted = s.windowsPrinterName.trim();
    if (wanted.isEmpty) {
      await Printing.layoutPdf(onLayout: (_) async => pdfBytes, name: jobName);
      return;
    }

    final printers = await Printing.listPrinters();
    final match = printers.where((p) => p.name == wanted).toList();

    if (match.isEmpty) {
      await Printing.layoutPdf(onLayout: (_) async => pdfBytes, name: jobName);
      return;
    }

    await Printing.directPrintPdf(
      printer: match.first,
      onLayout: (_) async => pdfBytes,
      name: jobName,
    );
  }

  static Future<void> printEscPosTicket({
    required String customerName,
    required PosPrintTemplate template,
    required Sale sale,
    required PosPaymentResult payment,
  }) async {
    final s = await PosPeripheralsStore.load();

    if (s.printerMode != PosPrinterMode.networkEscPos) {
      throw Exception('Modo de impresión no es Red (RAW ESC/POS).');
    }

    final host = s.networkHost.trim();
    if (host.isEmpty) {
      throw Exception('No hay IP/Host configurada para impresora de red.');
    }

    final bytes = PosEscPosTicketBuilder.buildTicket(
      customerName: customerName,
      template: template,
      sale: sale,
      payment: payment,
    );

    await PosEscPosNetworkPrinter.send(host, s.networkPort, bytes);
  }

  /// Imprime según configuración actual:
  /// - networkEscPos => manda ESC/POS raw por IP
  /// - windowsDriver => imprime PDF directo (si hay impresora elegida)
  static Future<void> printTicketAuto({
    required String customerName,
    required PosPrintTemplate template,
    required Sale sale,
    required PosPaymentResult payment,
    required Uint8List pdfBytes,
    required String jobName,
  }) async {
    final s = await PosPeripheralsStore.load();

    if (s.printerMode == PosPrinterMode.networkEscPos &&
        s.networkHost.trim().isNotEmpty) {
      await printEscPosTicket(
        customerName: customerName,
        template: template,
        sale: sale,
        payment: payment,
      );
      return;
    }

    await printPdfWithSettings(pdfBytes, jobName: jobName);
  }

  /// Prueba de impresión (simple)
  static Future<void> testPrint() async {
    final s = await PosPeripheralsStore.load();

    // RED ESC/POS RAW
    if (s.printerMode == PosPrinterMode.networkEscPos &&
        s.networkHost.trim().isNotEmpty) {
      final bytes = Uint8List.fromList(<int>[
        0x1B, 0x40, // init
        0x1B, 0x61, 0x01, // center
        ...'*** PRUEBA IMPRESION ***\n'.codeUnits,
        0x1B, 0x61, 0x00, // left
        ...'Framework AS POS\n'.codeUnits,
        ...'OK - ESC/POS RAW\n'.codeUnits,
        ...'\n\n\n'.codeUnits,
        0x1D, 0x56, 0x41, 0x00, // cut (partial)
      ]);

      await PosEscPosNetworkPrinter.send(
        s.networkHost.trim(),
        s.networkPort,
        bytes,
      );
      return;
    }

    // WINDOWS DRIVER: PDF mini
    final doc = pw.Document();
    doc.addPage(
      pw.Page(
        pageFormat: PdfPageFormat(58 * PdfPageFormat.mm, 120 * PdfPageFormat.mm),
        build: (_) => pw.Center(
          child: pw.Text(
            'PRUEBA IMPRESION\nFramework AS POS',
            textAlign: pw.TextAlign.center,
          ),
        ),
      ),
    );

    final pdfBytes = await doc.save();
    await printPdfWithSettings(pdfBytes, jobName: 'prueba_ticket.pdf');
  }
}
