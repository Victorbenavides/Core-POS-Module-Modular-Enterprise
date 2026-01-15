// lib/modules/pos_unicaja/models/sale.dart
import 'dart:convert';
import 'sale_item.dart';

class Sale {
  final String id;
  final DateTime createdAt;
  final List<SaleItem> items;
  final double total;
  final String paymentMethod;

  /// quién hizo la venta
  final String cashierId;

  /// ✅ cliente (solo aplica cuando paymentMethod == 'credit')
  final String customerId;

  /// ✅ Total sin redondeo (para ticket/reportes)
  final double rawTotal;

  /// ✅ Ajuste de redondeo: roundedTotal - rawTotal (puede ser negativo)
  final double roundingAdjustment;

  // ✅ NUEVOS CAMPOS: Para que el ticket reimpreso recuerde el pago real
  final double paidAmount;
  final double change;

  const Sale({
    required this.id,
    required this.createdAt,
    required this.items,
    required this.total,
    required this.paymentMethod,
    required this.cashierId,
    this.customerId = '',
    double? rawTotal,
    double? roundingAdjustment,
    this.paidAmount = 0.0, // Por defecto 0 (para ventas viejas)
    this.change = 0.0,     // Por defecto 0
  })  : rawTotal = rawTotal ?? total,
        roundingAdjustment = roundingAdjustment ?? 0.0;

  Sale copyWith({
    String? id,
    DateTime? createdAt,
    List<SaleItem>? items,
    double? total,
    String? paymentMethod,
    String? cashierId,
    String? customerId,
    double? rawTotal,
    double? roundingAdjustment,
    double? paidAmount, // Nuevo
    double? change,     // Nuevo
  }) {
    return Sale(
      id: id ?? this.id,
      createdAt: createdAt ?? this.createdAt,
      items: items ?? this.items,
      total: total ?? this.total,
      paymentMethod: paymentMethod ?? this.paymentMethod,
      cashierId: cashierId ?? this.cashierId,
      customerId: customerId ?? this.customerId,
      rawTotal: rawTotal ?? this.rawTotal,
      roundingAdjustment: roundingAdjustment ?? this.roundingAdjustment,
      paidAmount: paidAmount ?? this.paidAmount,
      change: change ?? this.change,
    );
  }

  // =========================
  // JSON (Aquí es donde se guarda en la DB SQLite)
  // =========================

  factory Sale.fromJson(Map<String, dynamic> json) {
    final total = (json['total'] as num?)?.toDouble() ?? 0.0;
    return Sale(
      id: json['id']?.toString() ?? '',
      createdAt: DateTime.tryParse(json['createdAt']?.toString() ?? '') ?? DateTime.now(),
      items: (json['items'] as List<dynamic>? ?? [])
          .map((e) => SaleItem.fromJson(e as Map<String, dynamic>))
          .toList(),
      total: total,
      paymentMethod: json['paymentMethod']?.toString() ?? 'cash',
      cashierId: json['cashierId']?.toString() ?? '',
      customerId: json['customerId']?.toString() ?? '',
      rawTotal: (json['rawTotal'] as num?)?.toDouble() ?? total,
      roundingAdjustment: (json['roundingAdjustment'] as num?)?.toDouble() ?? 0.0,
      
      // ✅ Recuperamos los datos de pago desde el JSON de SQLite
      paidAmount: (json['paidAmount'] as num?)?.toDouble() ?? 0.0,
      change: (json['change'] as num?)?.toDouble() ?? 0.0,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'createdAt': createdAt.toIso8601String(),
      'items': items.map((e) => e.toJson()).toList(),
      'total': total,
      'paymentMethod': paymentMethod,
      'cashierId': cashierId,
      'customerId': customerId,
      'rawTotal': rawTotal,
      'roundingAdjustment': roundingAdjustment,
      
      // ✅ Guardamos los datos nuevos en el JSON de SQLite
      'paidAmount': paidAmount,
      'change': change,
    };
  }

  static List<Sale> listFromJsonString(String raw) {
    final decoded = jsonDecode(raw);
    if (decoded is! List) return [];
    return decoded.map((e) => Sale.fromJson(e as Map<String, dynamic>)).toList();
  }

  static String listToJsonString(List<Sale> items) {
    return jsonEncode(items.map((e) => e.toJson()).toList());
  }

  // =========================
  // DB mapping (Legacy / Compatibilidad)
  // =========================

  Map<String, Object?> toDb() {
    return {
      'id': id,
      'created_at': createdAt.millisecondsSinceEpoch,
      'total': total,
      'payment_method': paymentMethod,
      'cashier_id': cashierId,
      'customer_id': customerId,
      'items_json': jsonEncode(items.map((e) => e.toJson()).toList()),
    };
  }

  static Sale fromDb(Map<String, Object?> map) {
    int asInt(Object? v) {
      if (v == null) return 0;
      if (v is int) return v;
      if (v is num) return v.toInt();
      return int.tryParse(v.toString()) ?? 0;
    }

    double asDouble(Object? v) {
      if (v == null) return 0.0;
      if (v is double) return v;
      if (v is int) return v.toDouble();
      if (v is num) return v.toDouble();
      return double.tryParse(v.toString()) ?? 0.0;
    }

    List<SaleItem> parseItems(Object? raw) {
      if (raw == null) return const [];
      try {
        final decoded = jsonDecode(raw.toString());
        if (decoded is! List) return const [];
        return decoded.map((e) => SaleItem.fromJson(e as Map<String, dynamic>)).toList();
      } catch (_) {
        return const [];
      }
    }

    final createdMs = asInt(map['created_at']);

    return Sale(
      id: (map['id'] ?? '').toString(),
      createdAt: DateTime.fromMillisecondsSinceEpoch(createdMs),
      total: asDouble(map['total']),
      paymentMethod: (map['payment_method'] ?? 'cash').toString(),
      cashierId: (map['cashier_id'] ?? '').toString(),
      customerId: (map['customer_id'] ?? '').toString(),
      items: parseItems(map['items_json']),
      // Defaults 0.0 si se lee directo de columnas legacy, 
      // pero nuestro DAO usa el JSON completo así que no hay problema.
      paidAmount: 0.0,
      change: 0.0,
    );
  }
}