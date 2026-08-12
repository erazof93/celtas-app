import 'package:celtas_mobile/core/network/api_client.dart';
import 'package:celtas_mobile/features/coupons/data/models/user_coupon.dart';
import 'package:celtas_mobile/features/coupons/data/models/validated_coupon.dart';
import 'package:dio/dio.dart';

/// Repositorio de cupones contra el backend real.
///
/// Endpoints (contrato verificado contra `celtas-backend/src/modules/coupons/
/// coupons.controller.ts` y `coupons.service.ts`):
///   - `POST /coupons/validate` con `{ code, subtotal? }` (requiere sesión)
///     → 201 con `{ valid, id, code, discountType, discountValue,
///     minPurchaseAmount, description, expiresAt }`. NO marca el cupón como
///     usado. `subtotal` es opcional y debe ser numérico (`ValidateCouponDto`
///     lo rechaza con 400 si llega como string) — si el cupón tiene
///     `minPurchaseAmount` y el subtotal enviado es menor, el backend
///     rechaza con 400 y el mensaje real ("Este cupón requiere un pedido
///     mínimo de S/X.XX"). Sin `subtotal`, el backend no valida el mínimo.
///   - 400 con `{ message }` cuando el cupón no existe, pertenece a otro
///     usuario, ya fue usado, expiró o no alcanza el mínimo — el mensaje
///     real del backend se propaga tal cual a la UI.
///   - `GET /coupons/me` → lista COMPLETA de los cupones del usuario, sin
///     paginar ni filtrar por status (igual que `GET /orders/me`; la
///     paginación es admin-only vía `GET /coupons`).
class CouponRepository {
  CouponRepository(this._dio);

  final Dio _dio;

  /// Valida un cupón sin canjearlo. Pasa `subtotal` (el subtotal actual del
  /// carrito) para que el backend valide el monto mínimo de compra del
  /// cupón, si tiene uno. Lanza `ApiException` con el mensaje real del
  /// backend si el cupón es inválido o no alcanza el mínimo.
  Future<ValidatedCoupon> validateCoupon(String code, {double? subtotal}) async {
    try {
      final response = await _dio.post<Map<String, dynamic>>(
        '/coupons/validate',
        data: {
          'code': code,
          'subtotal': ?subtotal,
        },
      );
      return ValidatedCoupon.fromJson(response.data ?? const {});
    } on DioException catch (e) {
      throw apiExceptionFromDio(e);
    }
  }

  Future<List<UserCoupon>> getMyCoupons() async {
    try {
      final response = await _dio.get<List<dynamic>>('/coupons/me');
      return (response.data ?? const [])
          .cast<Map<String, dynamic>>()
          .map(UserCoupon.fromJson)
          .toList();
    } on DioException catch (e) {
      throw apiExceptionFromDio(e);
    }
  }
}