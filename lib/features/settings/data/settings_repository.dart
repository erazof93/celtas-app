import 'package:celtas_mobile/core/network/api_client.dart';
import 'package:celtas_mobile/features/settings/data/models/business_hours.dart';
import 'package:dio/dio.dart';

/// Repositorio de settings públicas contra el backend real.
///
/// `GET /settings/business-hours` (público, sin auth): fuente única de
/// verdad de si el local está abierto ahora mismo (interruptor manual con
/// prioridad sobre el horario programado), pensada para que la UI muestre un
/// aviso — no bloquea nada por sí misma, el bloqueo real ocurre en
/// `POST /orders`.
class SettingsRepository {
  SettingsRepository(this._dio);

  final Dio _dio;

  Future<BusinessHours> getBusinessHours() async {
    try {
      final response = await _dio.get<Map<String, dynamic>>(
        '/settings/business-hours',
      );
      return BusinessHours.fromJson(response.data ?? const {});
    } on DioException catch (e) {
      throw apiExceptionFromDio(e);
    }
  }
}
