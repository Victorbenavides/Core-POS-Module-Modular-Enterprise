class PosCreditLineSnapshot {
  final String productId;
  final String name;
  final String unit;

  final double qtyOriginal;
  final double qtyRemaining;

  // Snapshot de precios/promoción al momento de la venta
  final double baseUnitPrice;
  final bool hasPromo;
  final String promoName;

  final bool isBundle;
  final double bundleSize; // ej 2
  final double bundlePrice; // ej 15.00 (precio del paquete)
  final double promoUnitPrice; // si no es bundle, el precio unitario promo

  final double originalSubtotal;
  final double remainingSubtotal;

  const PosCreditLineSnapshot({
    required this.productId,
    required this.name,
    required this.unit,
    required this.qtyOriginal,
    required this.qtyRemaining,
    required this.baseUnitPrice,
    required this.hasPromo,
    required this.promoName,
    required this.isBundle,
    required this.bundleSize,
    required this.bundlePrice,
    required this.promoUnitPrice,
    required this.originalSubtotal,
    required this.remainingSubtotal,
  });

  double subtotalForQty(double qty) {
    if (qty <= 0) return 0.0;

    if (!hasPromo) {
      return qty * baseUnitPrice;
    }

    if (isBundle && bundleSize > 0.000001) {
      final groups = (qty / bundleSize).floor();
      final rem = qty - (groups * bundleSize);
      return (groups * bundlePrice) + (rem * baseUnitPrice);
    }

    // no bundle: promo unit price
    return qty * promoUnitPrice;
  }

  PosCreditLineSnapshot copyWith({
    double? qtyOriginal,
    double? qtyRemaining,
    double? remainingSubtotal,
  }) {
    return PosCreditLineSnapshot(
      productId: productId,
      name: name,
      unit: unit,
      qtyOriginal: qtyOriginal ?? this.qtyOriginal,
      qtyRemaining: qtyRemaining ?? this.qtyRemaining,
      baseUnitPrice: baseUnitPrice,
      hasPromo: hasPromo,
      promoName: promoName,
      isBundle: isBundle,
      bundleSize: bundleSize,
      bundlePrice: bundlePrice,
      promoUnitPrice: promoUnitPrice,
      originalSubtotal: originalSubtotal,
      remainingSubtotal: remainingSubtotal ?? this.remainingSubtotal,
    );
  }

  Map<String, dynamic> toJson() => {
        'productId': productId,
        'name': name,
        'unit': unit,
        'qtyOriginal': qtyOriginal,
        'qtyRemaining': qtyRemaining,
        'baseUnitPrice': baseUnitPrice,
        'hasPromo': hasPromo,
        'promoName': promoName,
        'isBundle': isBundle,
        'bundleSize': bundleSize,
        'bundlePrice': bundlePrice,
        'promoUnitPrice': promoUnitPrice,
        'originalSubtotal': originalSubtotal,
        'remainingSubtotal': remainingSubtotal,
      };

  factory PosCreditLineSnapshot.fromJson(Map<String, dynamic> json) {
    double _num(dynamic v) {
      if (v is num) return v.toDouble();
      return double.tryParse('$v') ?? 0.0;
    }

    return PosCreditLineSnapshot(
      productId: (json['productId'] ?? '').toString(),
      name: (json['name'] ?? '').toString(),
      unit: (json['unit'] ?? '').toString(),
      qtyOriginal: _num(json['qtyOriginal']),
      qtyRemaining: _num(json['qtyRemaining']),
      baseUnitPrice: _num(json['baseUnitPrice']),
      hasPromo: json['hasPromo'] == true,
      promoName: (json['promoName'] ?? '').toString(),
      isBundle: json['isBundle'] == true,
      bundleSize: _num(json['bundleSize']),
      bundlePrice: _num(json['bundlePrice']),
      promoUnitPrice: _num(json['promoUnitPrice']),
      originalSubtotal: _num(json['originalSubtotal']),
      remainingSubtotal: _num(json['remainingSubtotal']),
    );
  }
}

class PosCreditEntry {
  final String id;
  final String customerId;
  final String saleId;

  final String createdCashierId;
  final DateTime createdAt;

  final String status; // 'open' | 'paid' | 'cancelled'

  final DateTime? settledAt;
  final String? settledCashierId;
  final String? settledMethod; // 'cash'|'card'|'transfer' (al cobrar deuda)

  final List<PosCreditLineSnapshot> lines;

  const PosCreditEntry({
    required this.id,
    required this.customerId,
    required this.saleId,
    required this.createdCashierId,
    required this.createdAt,
    required this.status,
    required this.lines,
    this.settledAt,
    this.settledCashierId,
    this.settledMethod,
  });

  double get originalAmount =>
      lines.fold(0.0, (sum, l) => sum + l.originalSubtotal);

  double get remainingAmount =>
      lines.fold(0.0, (sum, l) => sum + l.remainingSubtotal);

  Map<String, dynamic> toJson() => {
        'id': id,
        'customerId': customerId,
        'saleId': saleId,
        'createdCashierId': createdCashierId,
        'createdAt': createdAt.toIso8601String(),
        'status': status,
        'settledAt': settledAt?.toIso8601String(),
        'settledCashierId': settledCashierId,
        'settledMethod': settledMethod,
        'lines': lines.map((e) => e.toJson()).toList(),
      };

  factory PosCreditEntry.fromJson(Map<String, dynamic> json) {
    DateTime _dt(String? s) =>
        (s == null || s.isEmpty) ? DateTime.now() : (DateTime.tryParse(s) ?? DateTime.now());

    return PosCreditEntry(
      id: (json['id'] ?? '').toString(),
      customerId: (json['customerId'] ?? '').toString(),
      saleId: (json['saleId'] ?? '').toString(),
      createdCashierId: (json['createdCashierId'] ?? '').toString(),
      createdAt: _dt(json['createdAt']?.toString()),
      status: (json['status'] ?? 'open').toString(),
      settledAt: (json['settledAt'] == null) ? null : _dt(json['settledAt']?.toString()),
      settledCashierId: json['settledCashierId']?.toString(),
      settledMethod: json['settledMethod']?.toString(),
      lines: ((json['lines'] as List?) ?? [])
          .whereType<Map>()
          .map((m) => PosCreditLineSnapshot.fromJson(Map<String, dynamic>.from(m)))
          .toList(),
    );
  }

  PosCreditEntry copyWith({
    String? status,
    DateTime? settledAt,
    String? settledCashierId,
    String? settledMethod,
    List<PosCreditLineSnapshot>? lines,
  }) {
    return PosCreditEntry(
      id: id,
      customerId: customerId,
      saleId: saleId,
      createdCashierId: createdCashierId,
      createdAt: createdAt,
      status: status ?? this.status,
      settledAt: settledAt ?? this.settledAt,
      settledCashierId: settledCashierId ?? this.settledCashierId,
      settledMethod: settledMethod ?? this.settledMethod,
      lines: lines ?? this.lines,
    );
  }
}

class PosCreditPayment {
  final String id;
  final String entryId;
  final String customerId;
  final String cashierId;
  final DateTime createdAt;
  final double amount;
  final String method; // 'cash'|'card'|'transfer'

  const PosCreditPayment({
    required this.id,
    required this.entryId,
    required this.customerId,
    required this.cashierId,
    required this.createdAt,
    required this.amount,
    required this.method,
  });

  Map<String, dynamic> toJson() => {
        'id': id,
        'entryId': entryId,
        'customerId': customerId,
        'cashierId': cashierId,
        'createdAt': createdAt.toIso8601String(),
        'amount': amount,
        'method': method,
      };

  factory PosCreditPayment.fromJson(Map<String, dynamic> json) {
    double _num(dynamic v) {
      if (v is num) return v.toDouble();
      return double.tryParse('$v') ?? 0.0;
    }

    DateTime _dt(String? s) =>
        (s == null || s.isEmpty) ? DateTime.now() : (DateTime.tryParse(s) ?? DateTime.now());

    return PosCreditPayment(
      id: (json['id'] ?? '').toString(),
      entryId: (json['entryId'] ?? '').toString(),
      customerId: (json['customerId'] ?? '').toString(),
      cashierId: (json['cashierId'] ?? '').toString(),
      createdAt: _dt(json['createdAt']?.toString()),
      amount: _num(json['amount']),
      method: (json['method'] ?? 'cash').toString(),
    );
  }
}
