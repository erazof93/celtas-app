import 'package:celtas_mobile/core/network/api_client.dart';
import 'package:celtas_mobile/features/coupons/data/models/validated_coupon.dart';
import 'package:dio/dio.dart';

/// Repositorio de cupones contra el backend real.
///
/// Endpoint (contrato verificado contra `celtas-backend/src/modules/coupons/
/// coupons.controller.ts` y `coupons.service.ts`):
///   - `POST /coupons/validate` con `{ code }` (requiere sesión) → 201 con
///     `{ valid, id, code, discountType, discountValue, description,
///     expiresAt }`. NO marca el cupón como usado.
///   - 400 con `{ message }` cuando el cupón no existe, pertenece a otro
///     usuario, ya fue usado o expiró — el mensaje real del backend se
///     propaga tal cual a la UI.
class CouponRepository {
  CouponRepository(this._dio);

  final Dio _dio;

  /// Valida un cupón sin canjearlo. Lanza `ApiException` con el mensaje real
  /// del backend si el cupón es inválido.
  Future<ValidatedCoupon> validateCoupon(String code) async {
    try {
      final response = await _dio.post<Map<String, dynamic>>(
        '/coupons/validate',
        data: {'code': code},
      );
      return ValidatedCoupon.fromJson(response.data ?? const {});
    } on DioException catch (e) {
      throw apiExceptionFromDio(e);
    }
  }
}