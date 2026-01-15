// lib/modules/pos_unicaja/models/product.dart
import 'dart:convert';

class Product {
  final String id;
  final String name;
  final String barcode;

  final double costPrice;
  final double gainPercent;
  final double salePrice;
  final double wholesalePrice;

  final bool usesInventory;
  final double stock;
  final double minStock;
  final double maxStock;

  final bool isWeighed;
  final String unit;

  /// Departamento / familia del producto
  final String department;

  const Product({
    required this.id,
    required this.name,
    required this.barcode,
    required this.costPrice,
    required this.gainPercent,
    required this.salePrice,
    required this.wholesalePrice,
    required this.usesInventory,
    required this.stock,
    required this.minStock,
    required this.maxStock,
    required this.isWeighed,
    this.unit = 'PZA',
    this.department = 'GENERAL',
  });

  Product copyWith({
    String? id,
    String? name,
    String? barcode,
    double? costPrice,
    double? gainPercent,
    double? salePrice,
    double? wholesalePrice,
    bool? usesInventory,
    double? stock,
    double? minStock,
    double? maxStock,
    bool? isWeighed,
    String? unit,
    String? department,
  }) {
    return Product(
      id: id ?? this.id,
      name: name ?? this.name,
      barcode: barcode ?? this.barcode,
      costPrice: costPrice ?? this.costPrice,
      gainPercent: gainPercent ?? this.gainPercent,
      salePrice: salePrice ?? this.salePrice,
      wholesalePrice: wholesalePrice ?? this.wholesalePrice,
      usesInventory: usesInventory ?? this.usesInventory,
      stock: stock ?? this.stock,
      minStock: minStock ?? this.minStock,
      maxStock: maxStock ?? this.maxStock,
      isWeighed: isWeighed ?? this.isWeighed,
      unit: unit ?? this.unit,
      department: department ?? this.department,
    );
  }

  static double _d(dynamic v) {
    if (v == null) return 0.0;
    if (v is num) return v.toDouble();
    return double.tryParse(v.toString().replaceAll(',', '.')) ?? 0.0;
  }

  static bool _b(dynamic v) {
    if (v is bool) return v;
    if (v is num) return v != 0;
    final s = v?.toString().trim().toLowerCase();
    return s == 'true' || s == '1' || s == 'yes' || s == 'y';
  }

  factory Product.fromJson(Map<String, dynamic> json) {
    return Product(
      id: json['id']?.toString() ?? '',
      name: json['name']?.toString() ?? '',
      barcode: json['barcode']?.toString() ?? '',
      costPrice: _d(json['costPrice']),
      gainPercent: _d(json['gainPercent']),
      salePrice: _d(json['salePrice']),
      wholesalePrice: _d(json['wholesalePrice']),
      usesInventory: _b(json['usesInventory']),
      stock: _d(json['stock']),
      minStock: _d(json['minStock']),
      maxStock: _d(json['maxStock']),
      isWeighed: _b(json['isWeighed']),
      unit: json['unit']?.toString() ?? 'PZA',
      department: json['department']?.toString() ?? 'GENERAL',
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'name': name,
      'barcode': barcode,
      'costPrice': costPrice,
      'gainPercent': gainPercent,
      'salePrice': salePrice,
      'wholesalePrice': wholesalePrice,
      'usesInventory': usesInventory,
      'stock': stock,
      'minStock': minStock,
      'maxStock': maxStock,
      'isWeighed': isWeighed,
      'unit': unit,
      'department': department,
    };
  }

  static List<Product> listFromJsonString(String raw) {
    if (raw.trim().isEmpty) return [];
    final decoded = jsonDecode(raw);
    if (decoded is! List) return [];
    return decoded.map((e) => Product.fromJson((e as Map).cast<String, dynamic>())).toList();
  }

  static String listToJsonString(List<Product> items) {
    return jsonEncode(items.map((e) => e.toJson()).toList());
  }
}
