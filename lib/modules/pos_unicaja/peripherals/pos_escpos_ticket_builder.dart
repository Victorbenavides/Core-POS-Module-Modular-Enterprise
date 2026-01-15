// lib/modules/pos_unicaja/peripherals/pos_escpos_ticket_builder.dart
import 'dart:convert';
import 'dart:typed_data';

import 'package:framework_as/modules/pos_unicaja/models/pos_print_template.dart';
import 'package:framework_as/modules/pos_unicaja/models/sale.dart';
import 'package:framework_as/modules/pos_unicaja/models/sale_item.dart';
import 'package:framework_as/modules/pos_unicaja/widgets/pos_payment_dialog.dart';

class PosEscPosTicketBuilder {
  static Uint8List drawerKick() {
    // ESC p m t1 t2
    // m=0, t1=25, t2=250 (valores típicos)
    return Uint8List.fromList([0x1B, 0x70, 0x00, 0x19, 0xFA]);
  }

  static Uint8List buildTicket({
    required String customerName,
    required PosPrintTemplate template,
    required Sale sale,
    required PosPaymentResult payment,
  }) {
    final bytes = <int>[];

    void add(List<int> b) => bytes.addAll(b);
    void textLine(String s) {
      // Para impresoras típicas, latin1 suele funcionar mejor que utf8 en raw.
      add(latin1.encode(s));
      add([0x0A]); // \n
    }

    // Init
    add([0x1B, 0x40]);

    // Align
    int align;
    switch (template.headerAlign) {
      case 'left':
        align = 0;
        break;
      case 'right':
        align = 2;
        break;
      default:
        align = 1;
    }
    add([0x1B, 0x61, align]);

    // Bold ON
    add([0x1B, 0x45, 0x01]);
    textLine(customerName);
    // Bold OFF
    add([0x1B, 0x45, 0x00]);

    textLine('Ticket');
    textLine('------------------------------');

    // Items
    for (final SaleItem item in sale.items) {
      _itemLine(template, item, textLine);
      textLine('');
    }

    textLine('------------------------------');

    // Total
    add([0x1B, 0x45, 0x01]);
    textLine('TOTAL: \$${sale.total.toStringAsFixed(2)}');
    add([0x1B, 0x45, 0x00]);

    textLine('Metodo: ${_paymentLabel(payment)}');

    if (payment.method == PosPaymentMethod.cash) {
      textLine('Pago con: \$${payment.paidAmount.toStringAsFixed(2)}');
      textLine('Cambio:  \$${payment.change.toStringAsFixed(2)}');
    }

    // Extra útil para crédito (opcional, pero ayuda)
    if (payment.method == PosPaymentMethod.credit) {
      final name = payment.creditCustomerName?.trim() ?? '';
      if (name.isNotEmpty) {
        textLine('Cliente: $name');
      }
    }

    textLine('');
    final footer =
        template.footerText.trim().isEmpty ? ' ' : template.footerText.trim();
    textLine(footer);
    textLine('');

    // Cut (GS V 0)
    add([0x1D, 0x56, 0x00]);

    return Uint8List.fromList(bytes);
  }

  static void _itemLine(
    PosPrintTemplate template,
    SaleItem item,
    void Function(String) textLine,
  ) {
    final name = item.product.name;
    final qty = item.quantity.toStringAsFixed(2);
    final unit = item.product.unit;
    final unitPrice = item.product.salePrice.toStringAsFixed(2);
    final subtotal = item.subtotal.toStringAsFixed(2);

    if (template.groupProductData) {
      final u = template.showUnit ? ' $unit' : '';
      final up = template.showUnitPrice ? ' x \$$unitPrice' : '';
      textLine('$name');
      textLine('  $qty$u$up  =>  \$$subtotal');
      return;
    }

    textLine(name);
    final u = template.showUnit ? ' $unit' : '';
    final up = template.showUnitPrice ? '  •  \$$unitPrice' : '';
    textLine('Cant: $qty$u$up');
    textLine('Subtotal: \$$subtotal');
  }

  static String _paymentLabel(PosPaymentResult p) {
    switch (p.method) {
      case PosPaymentMethod.cash:
        return 'Efectivo';
      case PosPaymentMethod.card:
        return 'Tarjeta';
      case PosPaymentMethod.transfer:
        return 'Transferencia';
      case PosPaymentMethod.credit:
        return 'Crédito';
    }
  }
}
