// lib/modules/pos_unicaja/models/pos_print_template.dart
class PosPrintTemplate {
  // ===== Estilo base =====
  final String style; // "modern" | "classic"
  final String headerAlign; // "left" | "center" | "right"

  // ===== Layout / densidad =====
  final bool denseMode;
  final double fontScale; // 0.80 - 1.30 aprox

  // ===== Encabezado negocio =====
  final bool showLogo;
  final bool showBusinessAddress;
  final bool showBusinessPhone;
  final bool showBusinessRfc;
  final String? headerLine1;
  final String? headerLine2;

  // ===== Meta venta =====
  final bool showSaleMeta;
  final bool showCashier;
  final bool showFolio;
  final bool showDatetime;

  // ===== Items =====
  final bool showItemsTable; // tabla (moderna) vs lista (clásica)
  final bool showUnitPrice;
  final bool showUnit;
  final bool groupProductData;

  // ===== Totales =====
  final bool showTotalsBreakdown;
  final bool showDiscountLine;
  final bool showTaxLine;
  final bool showPaymentInfo;

  // ===== Pie =====
  final bool showThankYou;
  final String footerText;

  // ===== Flujo cobro =====
  final bool showPreviewOnPrint; // ✅ si false: imprime directo

  // ===== Formato impresión =====
  final int paperWidthMm; // 57 o 80
  final double marginLeftMm;
  final double marginRightMm;

  const PosPrintTemplate({
    required this.style,
    required this.headerAlign,
    required this.denseMode,
    required this.fontScale,
    required this.showLogo,
    required this.showBusinessAddress,
    required this.showBusinessPhone,
    required this.showBusinessRfc,
    required this.headerLine1,
    required this.headerLine2,
    required this.showSaleMeta,
    required this.showCashier,
    required this.showFolio,
    required this.showDatetime,
    required this.showItemsTable,
    required this.showUnitPrice,
    required this.showUnit,
    required this.groupProductData,
    required this.showTotalsBreakdown,
    required this.showDiscountLine,
    required this.showTaxLine,
    required this.showPaymentInfo,
    required this.showThankYou,
    required this.footerText,
    required this.showPreviewOnPrint,
    required this.paperWidthMm,
    required this.marginLeftMm,
    required this.marginRightMm,
  });

  // ✅ Defaults recomendados (moderno tipo Square/Shopify)
  factory PosPrintTemplate.defaults() => const PosPrintTemplate(
        style: 'modern',
        headerAlign: 'center',
        denseMode: true,
        fontScale: 1.00,

        showLogo: true,
        showBusinessAddress: true,
        showBusinessPhone: true,
        showBusinessRfc: false,
        headerLine1: '',
        headerLine2: '',

        showSaleMeta: true,
        showCashier: true,
        showFolio: true,
        showDatetime: true,

        showItemsTable: true,
        showUnitPrice: true,
        showUnit: true,
        groupProductData: true,

        showTotalsBreakdown: true,
        showDiscountLine: true,
        showTaxLine: false,
        showPaymentInfo: true,

        showThankYou: true,
        footerText: '¡Gracias por tu compra!',

        showPreviewOnPrint: true,

        paperWidthMm: 57,
        marginLeftMm: 3,
        marginRightMm: 3,
      );

  PosPrintTemplate copyWith({
    String? style,
    String? headerAlign,
    bool? denseMode,
    double? fontScale,
    bool? showLogo,
    bool? showBusinessAddress,
    bool? showBusinessPhone,
    bool? showBusinessRfc,
    String? headerLine1,
    String? headerLine2,
    bool? showSaleMeta,
    bool? showCashier,
    bool? showFolio,
    bool? showDatetime,
    bool? showItemsTable,
    bool? showUnitPrice,
    bool? showUnit,
    bool? groupProductData,
    bool? showTotalsBreakdown,
    bool? showDiscountLine,
    bool? showTaxLine,
    bool? showPaymentInfo,
    bool? showThankYou,
    String? footerText,
    bool? showPreviewOnPrint,
    int? paperWidthMm,
    double? marginLeftMm,
    double? marginRightMm,
  }) {
    return PosPrintTemplate(
      style: style ?? this.style,
      headerAlign: headerAlign ?? this.headerAlign,
      denseMode: denseMode ?? this.denseMode,
      fontScale: fontScale ?? this.fontScale,
      showLogo: showLogo ?? this.showLogo,
      showBusinessAddress: showBusinessAddress ?? this.showBusinessAddress,
      showBusinessPhone: showBusinessPhone ?? this.showBusinessPhone,
      showBusinessRfc: showBusinessRfc ?? this.showBusinessRfc,
      headerLine1: headerLine1 ?? this.headerLine1,
      headerLine2: headerLine2 ?? this.headerLine2,
      showSaleMeta: showSaleMeta ?? this.showSaleMeta,
      showCashier: showCashier ?? this.showCashier,
      showFolio: showFolio ?? this.showFolio,
      showDatetime: showDatetime ?? this.showDatetime,
      showItemsTable: showItemsTable ?? this.showItemsTable,
      showUnitPrice: showUnitPrice ?? this.showUnitPrice,
      showUnit: showUnit ?? this.showUnit,
      groupProductData: groupProductData ?? this.groupProductData,
      showTotalsBreakdown: showTotalsBreakdown ?? this.showTotalsBreakdown,
      showDiscountLine: showDiscountLine ?? this.showDiscountLine,
      showTaxLine: showTaxLine ?? this.showTaxLine,
      showPaymentInfo: showPaymentInfo ?? this.showPaymentInfo,
      showThankYou: showThankYou ?? this.showThankYou,
      footerText: footerText ?? this.footerText,
      showPreviewOnPrint: showPreviewOnPrint ?? this.showPreviewOnPrint,
      paperWidthMm: paperWidthMm ?? this.paperWidthMm,
      marginLeftMm: marginLeftMm ?? this.marginLeftMm,
      marginRightMm: marginRightMm ?? this.marginRightMm,
    );
  }

  static bool _b(dynamic v, bool fallback) => (v is bool) ? v : fallback;

  static double _d(dynamic v, double fallback) {
    if (v is num) return v.toDouble();
    if (v is String) return double.tryParse(v.replaceAll(',', '.')) ?? fallback;
    return fallback;
  }

  static int _i(dynamic v, int fallback) {
    if (v is int) return v;
    if (v is num) return v.toInt();
    if (v is String) return int.tryParse(v) ?? fallback;
    return fallback;
  }

  factory PosPrintTemplate.fromJson(Map<String, dynamic> json) {
    // ✅ Backward compatible: si tu JSON viejo no trae llaves nuevas, usamos defaults.
    final def = PosPrintTemplate.defaults();

    return PosPrintTemplate(
      style: (json['style'] ?? def.style).toString(),
      headerAlign: (json['headerAlign'] ?? def.headerAlign).toString(),

      denseMode: _b(json['denseMode'], def.denseMode),
      fontScale: _d(json['fontScale'], def.fontScale),

      showLogo: _b(json['showLogo'], def.showLogo),
      showBusinessAddress: _b(json['showBusinessAddress'], def.showBusinessAddress),
      showBusinessPhone: _b(json['showBusinessPhone'], def.showBusinessPhone),
      showBusinessRfc: _b(json['showBusinessRfc'], def.showBusinessRfc),
      headerLine1: (json['headerLine1'] ?? def.headerLine1)?.toString(),
      headerLine2: (json['headerLine2'] ?? def.headerLine2)?.toString(),

      showSaleMeta: _b(json['showSaleMeta'], def.showSaleMeta),
      showCashier: _b(json['showCashier'], def.showCashier),
      showFolio: _b(json['showFolio'], def.showFolio),
      showDatetime: _b(json['showDatetime'], def.showDatetime),

      showItemsTable: _b(json['showItemsTable'], def.showItemsTable),
      showUnitPrice: _b(json['showUnitPrice'], def.showUnitPrice),
      showUnit: _b(json['showUnit'], def.showUnit),
      groupProductData: _b(json['groupProductData'], def.groupProductData),

      showTotalsBreakdown: _b(json['showTotalsBreakdown'], def.showTotalsBreakdown),
      showDiscountLine: _b(json['showDiscountLine'], def.showDiscountLine),
      showTaxLine: _b(json['showTaxLine'], def.showTaxLine),
      showPaymentInfo: _b(json['showPaymentInfo'], def.showPaymentInfo),

      showThankYou: _b(json['showThankYou'], def.showThankYou),
      footerText: (json['footerText'] ?? def.footerText).toString(),

      showPreviewOnPrint: _b(json['showPreviewOnPrint'], def.showPreviewOnPrint),

      paperWidthMm: _i(json['paperWidthMm'], def.paperWidthMm),
      marginLeftMm: _d(json['marginLeftMm'], def.marginLeftMm),
      marginRightMm: _d(json['marginRightMm'], def.marginRightMm),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'style': style,
      'headerAlign': headerAlign,

      'denseMode': denseMode,
      'fontScale': fontScale,

      'showLogo': showLogo,
      'showBusinessAddress': showBusinessAddress,
      'showBusinessPhone': showBusinessPhone,
      'showBusinessRfc': showBusinessRfc,
      'headerLine1': headerLine1,
      'headerLine2': headerLine2,

      'showSaleMeta': showSaleMeta,
      'showCashier': showCashier,
      'showFolio': showFolio,
      'showDatetime': showDatetime,

      'showItemsTable': showItemsTable,
      'showUnitPrice': showUnitPrice,
      'showUnit': showUnit,
      'groupProductData': groupProductData,

      'showTotalsBreakdown': showTotalsBreakdown,
      'showDiscountLine': showDiscountLine,
      'showTaxLine': showTaxLine,
      'showPaymentInfo': showPaymentInfo,

      'showThankYou': showThankYou,
      'footerText': footerText,

      'showPreviewOnPrint': showPreviewOnPrint,

      'paperWidthMm': paperWidthMm,
      'marginLeftMm': marginLeftMm,
      'marginRightMm': marginRightMm,
    };
  }
}
