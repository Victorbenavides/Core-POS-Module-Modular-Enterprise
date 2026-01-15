// lib/modules/pos_unicaja/promotions/pos_promotion.dart
class PosPromotion {
  final String id;

  final String name;

  // Relación a producto (snapshot para mostrar aunque el producto cambie)
  final String productId;
  final String productName;
  final String productBarcode;

  // Rango
  final double minQty;
  final double? maxQty; // null = sin límite

  // Precio unitario promocional
  final double promoUnitPrice;

  // Estado
  final bool enabled;

  // Vigencia opcional
  final DateTime? startsAt;
  final DateTime? endsAt;

  final DateTime createdAt;

  const PosPromotion({
    required this.id,
    required this.name,
    required this.productId,
    required this.productName,
    required this.productBarcode,
    required this.minQty,
    required this.maxQty,
    required this.promoUnitPrice,
    required this.enabled,
    required this.startsAt,
    required this.endsAt,
    required this.createdAt,
  });

  bool isActiveAt(DateTime now) {
    if (!enabled) return false;
    if (startsAt != null && now.isBefore(startsAt!)) return false;
    if (endsAt != null && now.isAfter(endsAt!)) return false;
    return true;
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'name': name,
        'productId': productId,
        'productName': productName,
        'productBarcode': productBarcode,
        'minQty': minQty,
        'maxQty': maxQty,
        'promoUnitPrice': promoUnitPrice,
        'enabled': enabled,
        'startsAt': startsAt?.toIso8601String(),
        'endsAt': endsAt?.toIso8601String(),
        'createdAt': createdAt.toIso8601String(),
      };

  factory PosPromotion.fromJson(Map<String, dynamic> json) {
    DateTime? _dt(String? s) => (s == null || s.isEmpty) ? null : DateTime.tryParse(s);

    return PosPromotion(
      id: (json['id'] ?? '').toString(),
      name: (json['name'] ?? '').toString(),
      productId: (json['productId'] ?? '').toString(),
      productName: (json['productName'] ?? '').toString(),
      productBarcode: (json['productBarcode'] ?? '').toString(),
      minQty: (json['minQty'] is num) ? (json['minQty'] as num).toDouble() : double.tryParse('${json['minQty']}') ?? 1.0,
      maxQty: (json['maxQty'] == null)
          ? null
          : ((json['maxQty'] is num)
              ? (json['maxQty'] as num).toDouble()
              : double.tryParse('${json['maxQty']}')),
      promoUnitPrice: (json['promoUnitPrice'] is num)
          ? (json['promoUnitPrice'] as num).toDouble()
          : double.tryParse('${json['promoUnitPrice']}') ?? 0.0,
      enabled: json['enabled'] == true,
      startsAt: _dt(json['startsAt']?.toString()),
      endsAt: _dt(json['endsAt']?.toString()),
      createdAt: DateTime.tryParse((json['createdAt'] ?? '').toString()) ?? DateTime.now(),
    );
  }

  PosPromotion copyWith({
    String? id,
    String? name,
    String? productId,
    String? productName,
    String? productBarcode,
    double? minQty,
    double? maxQty,
    double? promoUnitPrice,
    bool? enabled,
    DateTime? startsAt,
    DateTime? endsAt,
    DateTime? createdAt,
  }) {
    return PosPromotion(
      id: id ?? this.id,
      name: name ?? this.name,
      productId: productId ?? this.productId,
      productName: productName ?? this.productName,
      productBarcode: productBarcode ?? this.productBarcode,
      minQty: minQty ?? this.minQty,
      maxQty: maxQty ?? this.maxQty,
      promoUnitPrice: promoUnitPrice ?? this.promoUnitPrice,
      enabled: enabled ?? this.enabled,
      startsAt: startsAt ?? this.startsAt,
      endsAt: endsAt ?? this.endsAt,
      createdAt: createdAt ?? this.createdAt,
    );
  }
}
