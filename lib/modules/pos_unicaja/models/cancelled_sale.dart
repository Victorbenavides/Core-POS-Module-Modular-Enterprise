// lib/modules/pos_unicaja/models/cancelled_sale.dart
class CancelledSale {
  final String saleId;
  final DateTime cancelledAt;
  final String reason;

  CancelledSale({
    required this.saleId,
    required this.cancelledAt,
    required this.reason,
  });
}
