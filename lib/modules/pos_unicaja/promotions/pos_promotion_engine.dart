// lib/modules/pos_unicaja/promotions/pos_promotion_engine.dart
import 'pos_promotion.dart';
import 'pos_discount.dart';

class PosLinePricing {
  final double qty;
  final double baseUnitPrice;
  final double baseTotal;

  final PosPromotion? promo;

  // ✅ Descuento (si ganó contra promo/normal)
  final PosDiscount? discountRule;
  final double discountPercent;

  /// subtotal final (ya con promo aplicada si conviene)
  final double subtotal;

  /// cuánto se aplicó a precio promo (si aplica)
  final double promoQty;
  final double promoTotal;

  /// cuánto quedó a precio normal (si aplica)
  final double normalQty;
  final double normalTotal;

  /// en modo "paquete" (min==max)
  final bool isBundle;
  final int bundleGroups;
  final double bundleSize;
  final double bundlePrice;

  double get discountAmount => baseTotal - subtotal;

  const PosLinePricing._({
    required this.qty,
    required this.baseUnitPrice,
    required this.baseTotal,
    required this.promo,
    required this.discountRule,
    required this.discountPercent,
    required this.subtotal,
    required this.promoQty,
    required this.promoTotal,
    required this.normalQty,
    required this.normalTotal,
    required this.isBundle,
    required this.bundleGroups,
    required this.bundleSize,
    required this.bundlePrice,
  });

  factory PosLinePricing.none({
    required double qty,
    required double baseUnitPrice,
  }) {
    final baseTotal = baseUnitPrice * qty;
    return PosLinePricing._(
      qty: qty,
      baseUnitPrice: baseUnitPrice,
      baseTotal: baseTotal,
      promo: null,
      discountRule: null,
      discountPercent: 0,
      subtotal: baseTotal,
      promoQty: 0,
      promoTotal: 0,
      normalQty: qty,
      normalTotal: baseTotal,
      isBundle: false,
      bundleGroups: 0,
      bundleSize: 0,
      bundlePrice: 0,
    );
  }

  PosLinePricing copyWith({
    PosPromotion? promo,
    PosDiscount? discount,
    double? discountPercent,
    double? subtotal,
    double? promoQty,
    double? promoTotal,
    double? normalQty,
    double? normalTotal,
    bool? isBundle,
    int? bundleGroups,
    double? bundleSize,
    double? bundlePrice,
  }) {
    return PosLinePricing._(
      qty: qty,
      baseUnitPrice: baseUnitPrice,
      baseTotal: baseTotal,
      promo: promo ?? this.promo,
      discountRule: discount ?? this.discountRule,
      discountPercent: discountPercent ?? this.discountPercent,
      subtotal: subtotal ?? this.subtotal,
      promoQty: promoQty ?? this.promoQty,
      promoTotal: promoTotal ?? this.promoTotal,
      normalQty: normalQty ?? this.normalQty,
      normalTotal: normalTotal ?? this.normalTotal,
      isBundle: isBundle ?? this.isBundle,
      bundleGroups: bundleGroups ?? this.bundleGroups,
      bundleSize: bundleSize ?? this.bundleSize,
      bundlePrice: bundlePrice ?? this.bundlePrice,
    );
  }
}

class PosPromotionEngine {
  static const double _eps = 0.0000001;

  static bool _isBundle(PosPromotion p) {
    if (p.maxQty == null) return false;
    return (p.maxQty! - p.minQty).abs() <= _eps;
  }

  static bool _qtyFitsRange(PosPromotion p, double qty) {
    final minOk = qty + _eps >= p.minQty;
    final maxOk = (p.maxQty == null) ? true : qty <= (p.maxQty! + _eps);
    return minOk && maxOk;
  }

  /// Mejor precio para una línea completa (soporta "paquetes" cuando min==max).
  ///
  /// Reglas:
  /// - Promos normales (min..max) aplican SOLO si qty cae dentro del rango.
  /// - Promos "paquete" (min==max) aplican por bloques: floor(qty/min) paquetes
  ///   y el resto a precio normal.
  /// - Descuentos (%) aplican por producto o por departamento.
  /// - NO se apilan (se elige lo más barato entre: normal, promo, descuento).
  static PosLinePricing bestLinePricing({
    required List<PosPromotion> promotions,
    required List<PosDiscount> discounts,
    required String productId,
    required String department,
    required double qty,
    required double baseUnitPrice,
    required DateTime now,
  }) {
    var best = PosLinePricing.none(qty: qty, baseUnitPrice: baseUnitPrice);

    // ======================
    // Promociones (producto)
    // ======================
    final list = promotions.where((p) {
      if (p.productId != productId) return false;
      if (!p.isActiveAt(now)) return false;

      // para "paquete": basta con qty >= minQty
      if (_isBundle(p)) return qty + _eps >= p.minQty;

      // para normal: qty debe caer dentro del rango
      return _qtyFitsRange(p, qty);
    }).toList();

    for (final p in list) {
      final pricing = _pricingForPromo(
        promo: p,
        qty: qty,
        baseUnitPrice: baseUnitPrice,
      );

      // Si no mejora, no conviene
      if (pricing.subtotal + _eps < best.subtotal) {
        best = pricing;
      }
    }

    // ==========================================
    // Descuentos (%) producto o departamento
    // (NO stack con promo)
    // ==========================================
    PosDiscount? bestDiscount;

    // buscar descuento activo por producto (prioridad)
    for (final d in discounts) {
      if (!d.isActiveAt(now)) continue;

      if (d.productId.trim().isNotEmpty && d.productId == productId) {
        bestDiscount = d;
        break;
      }
    }

    // si no hay por producto, buscar por departamento
    if (bestDiscount == null) {
      final dep = department.trim().toUpperCase();
      for (final d in discounts) {
        if (!d.isActiveAt(now)) continue;
        if (d.department.trim().isEmpty) continue;

        if (d.department.trim().toUpperCase() == dep) {
          bestDiscount = d;
          break;
        }
      }
    }

    if (bestDiscount != null) {
      final percent = bestDiscount.percent.clamp(0.0, 99.999);
      final discountedUnit = baseUnitPrice * (1.0 - (percent / 100.0));
      final discountedTotal = discountedUnit * qty;

      // solo tomar descuento si es más barato que lo mejor actual
      if (discountedTotal + _eps < best.subtotal) {
        best = best.copyWith(
          promo: null, // exclusión: si descuento gana, no mostramos promo
          discount: bestDiscount,
          discountPercent: percent,
          subtotal: discountedTotal,
          promoQty: 0,
          promoTotal: 0,
          normalQty: qty,
          normalTotal: discountedTotal,
          isBundle: false,
          bundleGroups: 0,
          bundleSize: 0,
          bundlePrice: 0,
        );
      }
    }

    return best;
  }

  static PosLinePricing _pricingForPromo({
    required PosPromotion promo,
    required double qty,
    required double baseUnitPrice,
  }) {
    final baseTotal = baseUnitPrice * qty;

    // Modo paquete (min==max): promoUnitPrice se interpreta como PRECIO DEL PAQUETE
    if (_isBundle(promo)) {
      final bundleSize = promo.minQty;
      if (bundleSize <= 0) {
        return PosLinePricing.none(qty: qty, baseUnitPrice: baseUnitPrice);
      }

      final groups = ((qty + _eps) / bundleSize).floor();
      if (groups <= 0) {
        return PosLinePricing.none(qty: qty, baseUnitPrice: baseUnitPrice);
      }

      final promoQty = groups * bundleSize;
      final normalQty = (qty - promoQty).abs() <= _eps ? 0.0 : (qty - promoQty);

      final promoTotal = groups * promo.promoUnitPrice;
      final normalTotal = normalQty * baseUnitPrice;

      final subtotal = promoTotal + normalTotal;

      return PosLinePricing._(
        qty: qty,
        baseUnitPrice: baseUnitPrice,
        baseTotal: baseTotal,
        promo: promo,
        discountRule: null,
        discountPercent: 0,
        subtotal: subtotal,
        promoQty: promoQty,
        promoTotal: promoTotal,
        normalQty: normalQty,
        normalTotal: normalTotal,
        isBundle: true,
        bundleGroups: groups,
        bundleSize: bundleSize,
        bundlePrice: promo.promoUnitPrice,
      );
    }

    // Modo normal: precio unitario promo para TODA la qty
    final subtotal = promo.promoUnitPrice * qty;

    return PosLinePricing._(
      qty: qty,
      baseUnitPrice: baseUnitPrice,
      baseTotal: baseTotal,
      promo: promo,
      discountRule: null,
      discountPercent: 0,
      subtotal: subtotal,
      promoQty: qty,
      promoTotal: subtotal,
      normalQty: 0,
      normalTotal: 0,
      isBundle: false,
      bundleGroups: 0,
      bundleSize: 0,
      bundlePrice: 0,
    );
  }
}
