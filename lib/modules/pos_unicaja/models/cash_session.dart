// lib/modules/pos_unicaja/models/cash_session.dart
class CashSession {
  final String id;
  final String cashierId;
  final DateTime openedAt;
  DateTime? closedAt;

  final double openingAmount;
  double salesTotal;
  double cancelledTotal;
  double cashInTotal;
  double cashOutTotal;

  bool isOpen;

  CashSession({
    required this.id,
    required this.cashierId,
    required this.openedAt,
    required this.openingAmount,
    this.closedAt,
    this.salesTotal = 0.0,
    this.cancelledTotal = 0.0,
    this.isOpen = true,
    this.cashInTotal = 0.0,
    this.cashOutTotal = 0.0,
  });

  double get netSales => salesTotal - cancelledTotal;
  double get expectedCashInDrawer => openingAmount + netSales + cashInTotal - cashOutTotal;

    CashSession copyWith({
    String? id,
    String? cashierId,
    DateTime? openedAt,
    DateTime? closedAt,
    double? openingAmount,
    double? salesTotal,
    double? cancelledTotal,

    // ✅ NUEVO
    double? cashInTotal,
    double? cashOutTotal,

    bool? isOpen,
  }) {
    return CashSession(
      id: id ?? this.id,
      cashierId: cashierId ?? this.cashierId,
      openedAt: openedAt ?? this.openedAt,
      openingAmount: openingAmount ?? this.openingAmount,
      closedAt: closedAt ?? this.closedAt,
      salesTotal: salesTotal ?? this.salesTotal,
      cancelledTotal: cancelledTotal ?? this.cancelledTotal,

      // ✅ NUEVO
      cashInTotal: cashInTotal ?? this.cashInTotal,
      cashOutTotal: cashOutTotal ?? this.cashOutTotal,

      isOpen: isOpen ?? this.isOpen,
    );
  }


  static double _d(dynamic v) {
    if (v == null) return 0.0;
    if (v is num) return v.toDouble();
    return double.tryParse(v.toString().replaceAll(',', '.')) ?? 0.0;
  }

  static DateTime _dt(dynamic v) {
    if (v == null) return DateTime.now();
    if (v is int) return DateTime.fromMillisecondsSinceEpoch(v);

    final s = v.toString().trim();
    if (s.isEmpty) return DateTime.now();

    // ✅ si viene como "1734567890000"
    final asInt = int.tryParse(s);
    if (asInt != null) return DateTime.fromMillisecondsSinceEpoch(asInt);

    // ✅ ISO
    return DateTime.tryParse(s) ?? DateTime.now();
  }

    Map<String, dynamic> toJson() {
    return {
      'id': id,
      'cashierId': cashierId,
      'openedAt': openedAt.toIso8601String(),
      'closedAt': closedAt?.toIso8601String(),
      'openedAtMs': openedAt.millisecondsSinceEpoch,
      'closedAtMs': closedAt?.millisecondsSinceEpoch,
      'openingAmount': openingAmount,
      'salesTotal': salesTotal,
      'cancelledTotal': cancelledTotal,

      // ✅ NUEVO
      'cashInTotal': cashInTotal,
      'cashOutTotal': cashOutTotal,

      'isOpen': isOpen,
    };
  }

  factory CashSession.fromJson(Map<String, dynamic> json) {
    return CashSession(
      id: (json['id'] ?? '').toString(),
      cashierId: (json['cashierId'] ?? '').toString(),
      openedAt: _dt(json['openedAt'] ?? json['openedAtMs']),
      closedAt: (json['closedAt'] == null && json['closedAtMs'] == null)
          ? null
          : _dt(json['closedAt'] ?? json['closedAtMs']),
      openingAmount: _d(json['openingAmount']),
      salesTotal: _d(json['salesTotal']),
      cancelledTotal: _d(json['cancelledTotal']),

      // ✅ NUEVO (compat: si no existe en DB vieja, queda 0)
      cashInTotal: _d(json['cashInTotal']),
      cashOutTotal: _d(json['cashOutTotal']),

      isOpen: json['isOpen'] == true || json['isOpen'] == 1,
    );
  }

}

