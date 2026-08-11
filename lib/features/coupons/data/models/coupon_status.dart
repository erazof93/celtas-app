import 'package:freezed_annotation/freezed_annotation.dart';

/// Estado del cupón (contrato real: `CouponStatus` en
/// `celtas-backend/src/modules/coupons/entities/coupon.entity.ts`).
///
/// OJO: el backend solo actualiza `active` → `expired` con un cron diario
/// (`handleDailyMaintenance`, 1am) — un cupón puede seguir marcado `active`
/// hasta 24h después de vencer. El propio backend no confía en este campo a
/// solas (`validateCoupon` también compara `expiresAt` contra la hora
/// actual). La app hace lo mismo: ver `UserCoupon.isEffectivelyExpired`.
enum CouponStatus {
  @JsonValue('active')
  active,

  @JsonValue('used')
  used,

  @JsonValue('expired')
  expired,
}
