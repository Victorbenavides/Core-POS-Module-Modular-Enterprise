// lib/modules/pos_unicaja/promotions/pos_discount.dart
class PosDiscount {
  final String id;

  final String name;

  /// target: producto o departamento
  final String productId;     // '' si es por departamento
  final String productName;   // snapshot
  final String department;    // '' si es por producto

  /// porcentaje 0..100
  final double percent;

  final bool enabled;
  final DateTime? startsAt;
  final DateTime? endsAt;

  final DateTime createdAt;

  const PosDiscount({
    required this.id,
    required this.name,
    required this.productId,
    required this.productName,
    required this.department,
    required this.percent,
    required this.enabled,
    required this.startsAt,
    required this.endsAt,
    required this.createdAt,
  });

  bool get isByProduct => productId.trim().isNotEmpty;
  bool get isByDepartment => department.trim().isNotEmpty;

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
        'department': department,
        'percent': percent,
        'enabled': enabled,
        'startsAt': startsAt?.toIso8601String(),
        'endsAt': endsAt?.toIso8601String(),
        'createdAt': createdAt.toIso8601String(),
      };

  factory PosDiscount.fromJson(Map<String, dynamic> json) {
    DateTime? _dt(String? s) =>
        (s == null || s.isEmpty) ? null : DateTime.tryParse(s);

    double _d(dynamic v) {
      if (v == null) return 0.0;
      if (v is num) return v.toDouble();
      return double.tryParse(v.toString().replaceAll(',', '.')) ?? 0.0;
    }

    return PosDiscount(
      id: (json['id'] ?? '').toString(),
      name: (json['name'] ?? '').toString(),
      productId: (json['productId'] ?? '').toString(),
      productName: (json['productName'] ?? '').toString(),
      department: (json['department'] ?? '').toString(),
      percent: _d(json['percent']),
      enabled: json['enabled'] == true,
      startsAt: _dt(json['startsAt']?.toString()),
      endsAt: _dt(json['endsAt']?.toString()),
      createdAt: DateTime.tryParse((json['createdAt'] ?? '').toString()) ??
          DateTime.now(),
    );
  }

  PosDiscount copyWith({
    String? id,
    String? name,
    String? productId,
    String? productName,
    String? department,
    double? percent,
    bool? enabled,
    DateTime? startsAt,
    DateTime? endsAt,
    DateTime? createdAt,
  }) {
    return PosDiscount(
      id: id ?? this.id,
      name: name ?? this.name,
      productId: productId ?? this.productId,
      productName: productName ?? this.productName,
      department: department ?? this.department,
      percent: percent ?? this.percent,
      enabled: enabled ?? this.enabled,
      startsAt: startsAt ?? this.startsAt,
      endsAt: endsAt ?? this.endsAt,
      createdAt: createdAt ?? this.createdAt,
    );
  }
}
