class PosCustomer {
  final String id;
  final String name;
  final String phone;
  final String notes;

  // Límite de fiado
  final double creditLimit;

  // Deuda actual (lo que debe)
  final double creditUsed;

  final bool enabled;
  final DateTime createdAt;
  final DateTime updatedAt;

  const PosCustomer({
    required this.id,
    required this.name,
    required this.phone,
    required this.notes,
    required this.creditLimit,
    required this.creditUsed,
    required this.enabled,
    required this.createdAt,
    required this.updatedAt,
  });

  double get creditAvailable {
    final v = creditLimit - creditUsed;
    return v < 0 ? 0 : v;
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'name': name,
        'phone': phone,
        'notes': notes,
        'creditLimit': creditLimit,
        'creditUsed': creditUsed,
        'enabled': enabled,
        'createdAt': createdAt.toIso8601String(),
        'updatedAt': updatedAt.toIso8601String(),
      };

  factory PosCustomer.fromJson(Map<String, dynamic> json) {
    double _num(dynamic v) {
      if (v is num) return v.toDouble();
      return double.tryParse('$v') ?? 0.0;
    }

    DateTime _dt(String? s) =>
        (s == null || s.isEmpty) ? DateTime.now() : (DateTime.tryParse(s) ?? DateTime.now());

    return PosCustomer(
      id: (json['id'] ?? '').toString(),
      name: (json['name'] ?? '').toString(),
      phone: (json['phone'] ?? '').toString(),
      notes: (json['notes'] ?? '').toString(),
      creditLimit: _num(json['creditLimit']),
      creditUsed: _num(json['creditUsed']),
      enabled: json['enabled'] == true,
      createdAt: _dt(json['createdAt']?.toString()),
      updatedAt: _dt(json['updatedAt']?.toString()),
    );
  }

  PosCustomer copyWith({
    String? id,
    String? name,
    String? phone,
    String? notes,
    double? creditLimit,
    double? creditUsed,
    bool? enabled,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) {
    return PosCustomer(
      id: id ?? this.id,
      name: name ?? this.name,
      phone: phone ?? this.phone,
      notes: notes ?? this.notes,
      creditLimit: creditLimit ?? this.creditLimit,
      creditUsed: creditUsed ?? this.creditUsed,
      enabled: enabled ?? this.enabled,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }
}
