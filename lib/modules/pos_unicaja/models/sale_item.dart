// lib/modules/pos_unicaja/models/sale_item.dart
import 'product.dart';

class SaleItem {
  final Product product;
  final double quantity;

  /// 👉 Si el artículo fue cancelado
  final bool cancelled;

  /// ✅ cuándo se canceló
  final DateTime? cancelledAt;

  /// ✅ quién lo canceló (id del cajero)
  final String cancelledByCashierId;

  // ✅ NUEVO: Precio real aplicado (ya con promo/descuento/mayoreo)
  // Si es null, el sistema asume que se vendió al precio normal.
  final double? finalUnitPrice;

  // ✅ NUEVO: Nombre de la promo aplicada (ej: "2x1", "Desc 10%")
  final String? promoName;

  const SaleItem({
    required this.product,
    required this.quantity,
    this.cancelled = false,
    this.cancelledAt,
    this.cancelledByCashierId = '',
    this.finalUnitPrice,
    this.promoName,
  });

  // ✅ El subtotal ahora respeta el precio final si existe
  double get subtotal => quantity * (finalUnitPrice ?? product.salePrice);

  // ✅ Helper para obtener el precio unitario efectivo fácilmente
  double get unitPrice => finalUnitPrice ?? product.salePrice;

  SaleItem copyWith({
    Product? product,
    double? quantity,
    bool? cancelled,
    DateTime? cancelledAt,
    String? cancelledByCashierId,
    double? finalUnitPrice,
    String? promoName,
  }) {
    return SaleItem(
      product: product ?? this.product,
      quantity: quantity ?? this.quantity,
      cancelled: cancelled ?? this.cancelled,
      cancelledAt: cancelledAt ?? this.cancelledAt,
      cancelledByCashierId: cancelledByCashierId ?? this.cancelledByCashierId,
      finalUnitPrice: finalUnitPrice ?? this.finalUnitPrice,
      promoName: promoName ?? this.promoName,
    );
  }

  static bool _asBool(dynamic v) {
    if (v is bool) return v;
    if (v is num) return v != 0;
    final s = v?.toString().trim().toLowerCase();
    return s == 'true' || s == '1' || s == 'yes' || s == 'y';
  }

  static double _asDouble(dynamic v) {
    if (v == null) return 0.0;
    if (v is num) return v.toDouble();
    return double.tryParse(v.toString().replaceAll(',', '.')) ?? 0.0;
  }

  factory SaleItem.fromJson(Map<String, dynamic> json) {
    final cancelledAtRaw = json['cancelledAt']?.toString();

    return SaleItem(
      product: Product.fromJson((json['product'] as Map?)?.cast<String, dynamic>() ?? const {}),
      quantity: _asDouble(json['quantity']),
      cancelled: _asBool(json['cancelled']),
      cancelledAt: (cancelledAtRaw == null || cancelledAtRaw.isEmpty)
          ? null
          : DateTime.tryParse(cancelledAtRaw),
      cancelledByCashierId: json['cancelledByCashierId']?.toString() ?? '',
      finalUnitPrice: json['finalUnitPrice'] != null ? _asDouble(json['finalUnitPrice']) : null,
      promoName: json['promoName']?.toString(),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'product': product.toJson(),
      'quantity': quantity,
      'cancelled': cancelled,
      'cancelledAt': cancelledAt?.toIso8601String(),
      'cancelledByCashierId': cancelledByCashierId,
      'finalUnitPrice': finalUnitPrice,
      'promoName': promoName,
    };
  }
}