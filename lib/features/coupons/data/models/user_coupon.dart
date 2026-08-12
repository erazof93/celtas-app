import 'package:celtas_mobile/features/coupons/data/models/coupon_status.dart';
import 'package:celtas_mobile/features/coupons/data/models/validated_coupon.dart'
    show CouponDiscountType;
import 'package:freezed_annotation/freezed_annotation.dart';

part 'user_coupon.freezed.dart';
part 'user_coupon.g.dart';

/// Cupón propio (contrato real: `Coupon` en
/// `celtas-backend/src/modules/coupons/entities/coupon.entity.ts`).
///
/// Fuente de `GET /coupons/me` — lista COMPLETA, sin paginar (mismo patrón
/// que `GET /orders/me`: la paginación y el filtro por status solo existen
/// en `GET /coupons`, admin-only).
@freezed
abstract class UserCoupon with _$UserCoupon {
  const factory UserCoupon({
    required String id,
    required String code,
    required CouponDiscountType discountType,
    required double discountValue,
    required CouponStatus status,
    required DateTime expiresAt,
    DateTime? usedAt,
    // Monto mínimo de compra del cupón (`Coupon.minPurchaseAmount` en el
    // backend: decimal nullable). `0` se trata igual que `null` ("sin
    // mínimo") — mismo criterio ya aplicado en el panel admin.
    double? minPurchaseAmount,
  }) = _UserCoupon;

  const UserCoupon._();

  factory UserCoupon.fromJson(Map<String, dynamic> json) =>
      _$UserCouponFromJson(json);

  /// Estado efectivo para la UI: el backend solo pasa `active` → `expired`
  /// una vez al día (ver `CouponStatus`), así que un cupón puede seguir
  /// `active` hasta 24h después de que `expiresAt` ya pasó. Mostrarlo como
  /// usable en ese caso sería engañoso — al intentar canjearlo en el
  /// checkout, el backend lo rechazaría igual (`validateCoupon` hace esta
  /// misma comparación).
  CouponStatus get effectiveStatus {
    if (status == CouponStatus.active && expiresAt.isBefore(DateTime.now())) {
      return CouponStatus.expired;
    }
    return status;
  }

  /// `0` se trata igual que `null`: en la práctica significa "sin mínimo".
  bool get hasMinPurchase =>
      minPurchaseAmount != null && minPurchaseAmount! > 0;
}
