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
/// { valid, id, code, discountType, discountValue, minPurchaseAmount,
///   description, expiresAt }
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
    // `0` se trata igual que `null` ("sin mínimo") — mismo criterio que
    // `UserCoupon.hasMinPurchase` y el panel admin. Guardado acá (no solo en
    // `UserCoupon`) para que el carrito pueda re-validar el mínimo si el
    // subtotal baja después de aplicar el cupón (`CartNotifier`).
    double? minPurchaseAmount,
  }) = _ValidatedCoupon;

  const ValidatedCoupon._();

  factory ValidatedCoupon.fromJson(Map<String, dynamic> json) =>
      _$ValidatedCouponFromJson(json);

  bool get hasMinPurchase =>
      minPurchaseAmount != null && minPurchaseAmount! > 0;
}