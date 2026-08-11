import 'package:freezed_annotation/freezed_annotation.dart';

part 'validated_coupon.freezed.dart';
part 'validated_coupon.g.dart';

/// Tipo de descuento del cupón (contrato real del backend:
/// `CouponDiscountType` en `coupons/entities/coupon.entity.ts`).
enum CouponDiscountType {
  /// Porcentaje del subtotal (`discountValue` = %).
  @JsonValue('percentage')
  percentage,

  /// Monto fijo en soles (`discountValue` = S/).
  @JsonValue('fixed_amount')
  fixedAmount,
}

/// Respuesta de `POST /coupons/validate` (contrato verificado contra
/// `celtas-backend/src/modules/coupons/coupons.service.ts`, interfaz
/// `ValidatedCoupon`):
///
/// ```ts
/// { valid, id, code, discountType, discountValue, description, expiresAt }
/// ```
///
/// El endpoint NO marca el cupón como usado — el canje ocurre recién al crear
/// el pedido (`POST /orders`). La app solo lo muestra como descuento a aplicar.
@freezed
abstract class ValidatedCoupon with _$ValidatedCoupon {
  const factory ValidatedCoupon({
    required bool valid,
    required String id,
    required String code,
    required CouponDiscountType discountType,
    required double discountValue,
    required String description,
    DateTime? expiresAt,
  }) = _ValidatedCoupon;

  factory ValidatedCoupon.fromJson(Map<String, dynamic> json) =>
      _$ValidatedCouponFromJson(json);
}