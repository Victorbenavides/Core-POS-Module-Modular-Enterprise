class CashMovement {
  final String id;
  final DateTime createdAt;
  final String cashierId;
  final String cashSessionId;

  /// + entrada / - salida (o usa bool isIn)
  final bool isIn;
  final double amount; // siempre positivo
  final String note;

  CashMovement({
    required this.id,
    required this.createdAt,
    required this.cashierId,
    required this.cashSessionId,
    required this.isIn,
    required this.amount,
    required this.note,
  });

  double get signedAmount => isIn ? amount : -amount;
}
