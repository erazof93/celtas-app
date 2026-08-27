import 'package:celtas_mobile/core/network/api_client.dart';
import 'package:dio/dio.dart';

/// Repositorio de notificaciones push contra el backend real.
///
/// Contrato verificado contra `celtas-backend/src/modules/users/
/// users.controller.ts` + `users.service.ts` + `dto/update-fcm-token.dto.ts`:
///   - `PATCH /users/me/fcm-token` con `{ fcmToken }` → 200. Sobrescribe el
///     token anterior (single-device por ahora, según el propio docstring del
///     endpoint).
///   - `DELETE /users/me/fcm-token` sin body → 200. Des-registra el token del
///     dispositivo (lo pone en `null` en la cuenta). Lo llama `logout()` para
///     que, en un celular compartido, la cuenta que se va deje de recibir
///     notificaciones de pedidos antes de que la siguiente cuenta inicie
///     sesión y sobrescriba el token.
class NotificationRepository {
  NotificationRepository(this._dio);

  final Dio _dio;

  Future<void> updateFcmToken(String fcmToken) async {
    try {
      await _dio.patch<void>(
        '/users/me/fcm-token',
        data: {'fcmToken': fcmToken},
      );
    } on DioException catch (e) {
      throw apiExceptionFromDio(e);
    }
  }

  Future<void> clearFcmToken() async {
    try {
      await _dio.delete<void>('/users/me/fcm-token');
    } on DioException catch (e) {
      throw apiExceptionFromDio(e);
    }
  }
}
