import 'package:celtas_mobile/core/config/env.dart';
import 'package:dio/dio.dart';

/// Cliente HTTP único de la app basado en `dio`.
///
/// Módulo 0: solo infraestructura. El interceptor que adjunta el `accessToken`
/// en memoria y el de refresh en 401 se completan en el módulo 1 (Auth), con el
/// mismo patrón verificado en `celtas-admin/src/lib/api-client.ts`.
///
/// Rutas excluidas del ciclo de retry (se definen aquí para que el módulo 1 las
/// reutilice):
///   - `POST /auth/login`
///   - `POST /auth/refresh`
class ApiClient {
  ApiClient._internal()
      : dio = Dio(
          BaseOptions(
            baseUrl: AppConfig.apiBaseUrl,
            connectTimeout: const Duration(seconds: 15),
            receiveTimeout: const Duration(seconds: 15),
            headers: {'Accept': 'application/json'},
          ),
        ) {
    dio.interceptors.add(InterceptorsWrapper(
      onRequest: _onRequest,
      onError: _onError,
    ));
  }

  /// Instancia única del cliente.
  static final ApiClient instance = ApiClient._internal();

  /// Instancia de `dio` configurada, lista para uso directo por repositorios.
  final Dio dio;

  Future<void> _onRequest(
    RequestOptions options,
    RequestInterceptorHandler handler,
  ) async {
    // TODO(módulo 1): adjuntar `Bearer <accessToken>` (en memoria, sin persistir).
    handler.next(options);
  }

  Future<void> _onError(
    DioException error,
    ErrorInterceptorHandler handler,
  ) async {
    // TODO(módulo 1): manejar 401 con refresh-once y cola de requests pendientes.
    handler.next(error);
  }
}