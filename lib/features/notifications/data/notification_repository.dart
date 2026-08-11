import 'package:celtas_mobile/core/network/api_client.dart';
import 'package:dio/dio.dart';

/// Repositorio de notificaciones push contra el backend real.
///
/// Contrato verificado contra `celtas-backend/src/modules/users/
/// users.controller.ts` + `dto/update-fcm-token.dto.ts`:
///   - `PATCH /users/me/fcm-token` con `{ fcmToken }` → 200. Sobrescribe el
///     token anterior (single-device por ahora, según el propio docstring del
///     endpoint). No existe un endpoint de "des-registro": al cerrar sesión,
///     el token simplemente queda hasta que el próximo login en ese
///     dispositivo lo sobrescriba.
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
}
