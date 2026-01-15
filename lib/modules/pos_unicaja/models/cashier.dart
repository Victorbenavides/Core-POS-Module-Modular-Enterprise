// lib/modules/pos_unicaja/models/cashier.dart
import 'dart:convert';

class Cashier {
  final String id;
  final String name;
  final String pin;

  // ====== Admin / legacy ======
  final bool isAdmin;
  final bool canManageInventory; // legacy (compat)
  final bool canViewReports; // legacy (compat)
  final bool canCancelSales; // legacy (compat)

  // ====== Caja / venta ======
  final bool canOpenCash;
  final bool canCloseCash;
  final bool canCharge;
  final bool canEditSale;

  // ====== Inventario / catálogo ======
  final bool canViewInventory;
  final bool canEditInventory;
  final bool canAdjustStock;

  // ====== Promos ======
  final bool canManagePromotions;

  // ====== Clientes / créditos ======
  final bool canManageCustomers;
  final bool canUseCredits;
  final bool canManageCredits;

  // ====== Reportes / cortes ======
  final bool canDailyClose;
  final bool canSalesReport;
  final bool canSalesSummary;

  // ====== Admin / configuración ======
  final bool canManageCashiers;
  final bool canManagePeripherals;
  final bool canManagePrintTemplate;
  final bool canManageSettings;

  const Cashier({
    required this.id,
    required this.name,
    required this.pin,

    // legacy
    this.isAdmin = false,
    this.canManageInventory = false,
    this.canViewReports = false,
    this.canCancelSales = false,

    // caja / venta
    this.canOpenCash = false,
    this.canCloseCash = false,
    this.canCharge = false,
    this.canEditSale = false,

    // inventario
    this.canViewInventory = false,
    this.canEditInventory = false,
    this.canAdjustStock = false,

    // promos
    this.canManagePromotions = false,

    // clientes / créditos
    this.canManageCustomers = false,
    this.canUseCredits = false,
    this.canManageCredits = false,

    // reportes / cortes
    this.canDailyClose = false,
    this.canSalesReport = false,
    this.canSalesSummary = false,

    // admin / config
    this.canManageCashiers = false,
    this.canManagePeripherals = false,
    this.canManagePrintTemplate = false,
    this.canManageSettings = false,
  });

  // ==========================================================
  // ✅ Permisos "effective" (ADMIN override + fallback legacy)
  // ==========================================================

  bool get canOpenCashEffective => isAdmin || canOpenCash;
  bool get canCloseCashEffective => isAdmin || canCloseCash;

  bool get canChargeEffective => isAdmin || canCharge;
  bool get canCancelSalesEffective => isAdmin || canCancelSales || canEditSale;
  bool get canEditSaleEffective => isAdmin || canEditSale || canCancelSales;

  bool get canViewInventoryEffective =>
      isAdmin || canViewInventory || canManageInventory;

  bool get canEditInventoryEffective =>
      isAdmin || canEditInventory || canManageInventory;

  bool get canAdjustStockEffective =>
      isAdmin || canAdjustStock || canManageInventory;

  bool get canManagePromotionsEffective =>
      isAdmin || canManagePromotions || canManageInventory;

  bool get canManageCustomersEffective =>
      isAdmin || canManageCustomers || canManageInventory;

  bool get canUseCreditsEffective =>
      isAdmin || canUseCredits || canManageCredits;

  bool get canManageCreditsEffective =>
      isAdmin || canManageCredits || canManageInventory;

  bool get canDailyCloseEffective => isAdmin || canDailyClose || canViewReports;

  bool get canSalesReportEffective =>
      isAdmin || canSalesReport || canViewReports || canCancelSales;

  bool get canSalesSummaryEffective =>
      isAdmin || canSalesSummary || canViewReports;

  bool get canManageCashiersEffective => isAdmin || canManageCashiers;
  bool get canManagePeripheralsEffective => isAdmin || canManagePeripherals;
  bool get canManagePrintTemplateEffective => isAdmin || canManagePrintTemplate;
  bool get canManageSettingsEffective => isAdmin || canManageSettings;

  Cashier copyWith({
    String? id,
    String? name,
    String? pin,

    bool? isAdmin,
    bool? canManageInventory,
    bool? canViewReports,
    bool? canCancelSales,

    bool? canOpenCash,
    bool? canCloseCash,
    bool? canCharge,
    bool? canEditSale,

    bool? canViewInventory,
    bool? canEditInventory,
    bool? canAdjustStock,

    bool? canManagePromotions,

    bool? canManageCustomers,
    bool? canUseCredits,
    bool? canManageCredits,

    bool? canDailyClose,
    bool? canSalesReport,
    bool? canSalesSummary,

    bool? canManageCashiers,
    bool? canManagePeripherals,
    bool? canManagePrintTemplate,
    bool? canManageSettings,
  }) {
    return Cashier(
      id: id ?? this.id,
      name: name ?? this.name,
      pin: pin ?? this.pin,

      isAdmin: isAdmin ?? this.isAdmin,
      canManageInventory: canManageInventory ?? this.canManageInventory,
      canViewReports: canViewReports ?? this.canViewReports,
      canCancelSales: canCancelSales ?? this.canCancelSales,

      canOpenCash: canOpenCash ?? this.canOpenCash,
      canCloseCash: canCloseCash ?? this.canCloseCash,
      canCharge: canCharge ?? this.canCharge,
      canEditSale: canEditSale ?? this.canEditSale,

      canViewInventory: canViewInventory ?? this.canViewInventory,
      canEditInventory: canEditInventory ?? this.canEditInventory,
      canAdjustStock: canAdjustStock ?? this.canAdjustStock,

      canManagePromotions: canManagePromotions ?? this.canManagePromotions,

      canManageCustomers: canManageCustomers ?? this.canManageCustomers,
      canUseCredits: canUseCredits ?? this.canUseCredits,
      canManageCredits: canManageCredits ?? this.canManageCredits,

      canDailyClose: canDailyClose ?? this.canDailyClose,
      canSalesReport: canSalesReport ?? this.canSalesReport,
      canSalesSummary: canSalesSummary ?? this.canSalesSummary,

      canManageCashiers: canManageCashiers ?? this.canManageCashiers,
      canManagePeripherals: canManagePeripherals ?? this.canManagePeripherals,
      canManagePrintTemplate:
          canManagePrintTemplate ?? this.canManagePrintTemplate,
      canManageSettings: canManageSettings ?? this.canManageSettings,
    );
  }

  static bool _b(dynamic v) {
    if (v is bool) return v;
    if (v is num) return v != 0;
    final s = v?.toString().trim().toLowerCase();
    return s == 'true' || s == '1' || s == 'yes' || s == 'y';
  }

  factory Cashier.fromJson(Map<String, dynamic> json) {
    return Cashier(
      id: json['id']?.toString() ?? '',
      name: json['name']?.toString() ?? '',
      pin: json['pin']?.toString() ?? '',

      isAdmin: _b(json['isAdmin']),
      canManageInventory: _b(json['canManageInventory']),
      canViewReports: _b(json['canViewReports']),
      canCancelSales: _b(json['canCancelSales']),

      canOpenCash: _b(json['canOpenCash']),
      canCloseCash: _b(json['canCloseCash']),
      canCharge: _b(json['canCharge']),
      canEditSale: _b(json['canEditSale']),

      canViewInventory: _b(json['canViewInventory']),
      canEditInventory: _b(json['canEditInventory']),
      canAdjustStock: _b(json['canAdjustStock']),

      canManagePromotions: _b(json['canManagePromotions']),

      canManageCustomers: _b(json['canManageCustomers']),
      canUseCredits: _b(json['canUseCredits']),
      canManageCredits: _b(json['canManageCredits']),

      canDailyClose: _b(json['canDailyClose']),
      canSalesReport: _b(json['canSalesReport']),
      canSalesSummary: _b(json['canSalesSummary']),

      canManageCashiers: _b(json['canManageCashiers']),
      canManagePeripherals: _b(json['canManagePeripherals']),
      canManagePrintTemplate: _b(json['canManagePrintTemplate']),
      canManageSettings: _b(json['canManageSettings']),
    );
  }

  factory Cashier.fromDbMap(Map<String, Object?> row) {
    return Cashier(
      id: (row['id'] ?? '').toString(),
      name: (row['name'] ?? '').toString(),
      pin: (row['pin'] ?? '').toString(),

      isAdmin: _b(row['isAdmin']),
      canManageInventory: _b(row['canManageInventory']),
      canViewReports: _b(row['canViewReports']),
      canCancelSales: _b(row['canCancelSales']),

      canOpenCash: _b(row['canOpenCash']),
      canCloseCash: _b(row['canCloseCash']),
      canCharge: _b(row['canCharge']),
      canEditSale: _b(row['canEditSale']),

      canViewInventory: _b(row['canViewInventory']),
      canEditInventory: _b(row['canEditInventory']),
      canAdjustStock: _b(row['canAdjustStock']),

      canManagePromotions: _b(row['canManagePromotions']),

      canManageCustomers: _b(row['canManageCustomers']),
      canUseCredits: _b(row['canUseCredits']),
      canManageCredits: _b(row['canManageCredits']),

      canDailyClose: _b(row['canDailyClose']),
      canSalesReport: _b(row['canSalesReport']),
      canSalesSummary: _b(row['canSalesSummary']),

      canManageCashiers: _b(row['canManageCashiers']),
      canManagePeripherals: _b(row['canManagePeripherals']),
      canManagePrintTemplate: _b(row['canManagePrintTemplate']),
      canManageSettings: _b(row['canManageSettings']),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'name': name,
      'pin': pin,

      'isAdmin': isAdmin,
      'canManageInventory': canManageInventory,
      'canViewReports': canViewReports,
      'canCancelSales': canCancelSales,

      'canOpenCash': canOpenCash,
      'canCloseCash': canCloseCash,
      'canCharge': canCharge,
      'canEditSale': canEditSale,

      'canViewInventory': canViewInventory,
      'canEditInventory': canEditInventory,
      'canAdjustStock': canAdjustStock,

      'canManagePromotions': canManagePromotions,

      'canManageCustomers': canManageCustomers,
      'canUseCredits': canUseCredits,
      'canManageCredits': canManageCredits,

      'canDailyClose': canDailyClose,
      'canSalesReport': canSalesReport,
      'canSalesSummary': canSalesSummary,

      'canManageCashiers': canManageCashiers,
      'canManagePeripherals': canManagePeripherals,
      'canManagePrintTemplate': canManagePrintTemplate,
      'canManageSettings': canManageSettings,
    };
  }

  Map<String, Object?> toDbMap() {
    return {
      'id': id,
      'name': name,
      'pin': pin,

      'isAdmin': isAdmin ? 1 : 0,
      'canManageInventory': canManageInventory ? 1 : 0,
      'canViewReports': canViewReports ? 1 : 0,
      'canCancelSales': canCancelSales ? 1 : 0,

      'canOpenCash': canOpenCash ? 1 : 0,
      'canCloseCash': canCloseCash ? 1 : 0,
      'canCharge': canCharge ? 1 : 0,
      'canEditSale': canEditSale ? 1 : 0,

      'canViewInventory': canViewInventory ? 1 : 0,
      'canEditInventory': canEditInventory ? 1 : 0,
      'canAdjustStock': canAdjustStock ? 1 : 0,

      'canManagePromotions': canManagePromotions ? 1 : 0,

      'canManageCustomers': canManageCustomers ? 1 : 0,
      'canUseCredits': canUseCredits ? 1 : 0,
      'canManageCredits': canManageCredits ? 1 : 0,

      'canDailyClose': canDailyClose ? 1 : 0,
      'canSalesReport': canSalesReport ? 1 : 0,
      'canSalesSummary': canSalesSummary ? 1 : 0,

      'canManageCashiers': canManageCashiers ? 1 : 0,
      'canManagePeripherals': canManagePeripherals ? 1 : 0,
      'canManagePrintTemplate': canManagePrintTemplate ? 1 : 0,
      'canManageSettings': canManageSettings ? 1 : 0,
    };
  }

  static List<Cashier> listFromJsonString(String raw) {
    if (raw.trim().isEmpty) return [];
    final list = jsonDecode(raw);
    if (list is! List) return [];
    return list
        .map((e) => Cashier.fromJson((e as Map).cast<String, dynamic>()))
        .toList();
  }

  static String listToJsonString(List<Cashier> items) {
    return jsonEncode(items.map((e) => e.toJson()).toList());
  }
}
