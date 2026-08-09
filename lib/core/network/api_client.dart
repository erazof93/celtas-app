import 'dart:async';

import 'package:celtas_mobile/core/config/env.dart';
import 'package:celtas_mobile/core/network/auth_session_bridge.dart';
import 'package:celtas_mobile/features/auth/data/models/auth_tokens.dart';
import 'package:dio/dio.dart';

/// Excepción de dominio con el mensaje ya extraído del envelope de error del
/// backend (`{ success: false, message, statusCode }`).
class ApiException implements Exception {
  const ApiException(this.message, {this.statusCode});

  final String message;
  final int? statusCode;

  @override
  String toString() => message;
}

/// Convierte un `DioException` en un `ApiException` legible para la UI:
/// extrae `message` del envelope de error del backend cuando existe, y usa un
/// mensaje genérico de conexión para errores de red/timeout.
ApiException apiExceptionFromDio(DioException error) {
  final data = error.response?.data;
  if (data is Map<String, dynamic> && data['message'] is String) {
    return ApiException(
      data['message'] as String,
      statusCode: error.response?.statusCode,
    );
  }
  switch (error.type) {
    case DioExceptionType.connectionTimeout:
    case DioExceptionType.sendTimeout:
    case DioExceptionType.receiveTimeout:
      return const ApiException(
        'El servidor tardó demasiado en responder. Inténtalo de nuevo.',
      );
    case DioExceptionType.connectionError:
      return const ApiException(
        'No se pudo conectar con el servidor. Revisa tu conexión e inténtalo de nuevo.',
      );
    default:
      return const ApiException(
        'Ocurrió un error inesperado. Inténtalo de nuevo.',
      );
  }
}

/// Cliente HTTP único de la app basado en `dio`.
///
/// Mismo patrón verificado en `celtas-admin/src/lib/api-client.ts`:
///  1. Interceptor de request: adjunta `Bearer <accessToken>` (en memoria,
///     nunca persistido) a cada request.
///  2. Interceptor de response: desenvuelve el envelope `{ success, data }` →
///     los repositorios reciben el payload directo.
///  3. Interceptor de error: ante un 401 intenta `POST /auth/refresh` UNA sola
///     vez con el refresh token de `flutter_secure_storage`; si funciona,
///     rota los tokens y reintenta la request original. Las requests que llegan
///     mientras se refresca se encolan y se liberan con el token nuevo. Si el
///     refresh falla con 401 definitivo, limpia la sesión. Nunca reintenta en
///     loop. `/auth/login` y `/auth/refresh` quedan excluidos del ciclo.
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
      onResponse: _onResponse,
      onError: _onError,
    ));
  }

  /// Instancia única del cliente.
  static final ApiClient instance = ApiClient._internal();

  /// Instancia de `dio` configurada, lista para uso directo por repositorios.
  final Dio dio;

  /// Puente a la sesión de auth, registrado por `AuthController` al arrancar.
  AuthSessionBridge? session;

  /// Endpoints de auth que nunca entran al ciclo de refresh (evita loops).
  static const _authEndpoints = {
    '/auth/login',
    '/auth/refresh',
    '/auth/register',
  };

  bool _isRefreshing = false;
  final List<void Function(String? token)> _pendingQueue = [];

  // --- Interceptor de request: adjunta el access token en memoria. ---

  Future<void> _onRequest(
    RequestOptions options,
    RequestInterceptorHandler handler,
  ) async {
    final token = session?.accessToken;
    if (token != null && token.isNotEmpty) {
      options.headers['Authorization'] = 'Bearer $token';
    }
    handler.next(options);
  }

  // --- Interceptor de response: desenvuelve el envelope estándar. ---

  void _onResponse(Response<dynamic> response, ResponseInterceptorHandler handler) {
    final body = response.data;
    if (body is Map<String, dynamic> &&
        body['success'] == true &&
        body.containsKey('data')) {
      response.data = body['data'];
    }
    handler.next(response);
  }

  // --- Interceptor de error: 401 → refresh una sola vez → reintenta. ---

  Future<void> _onError(
    DioException error,
    ErrorInterceptorHandler handler,
  ) async {
    final original = error.requestOptions;
    final status = error.response?.statusCode;

    // No es 401, ya fue reintentada, o es el propio login/refresh: no refrescar.
    if (status != 401 ||
        _authEndpoints.contains(original.path) ||
        original.extra['_retry'] == true) {
      handler.next(error);
      return;
    }

    final refreshToken = await session?.readRefreshToken();
    if (refreshToken == null || refreshToken.isEmpty) {
      await session?.clearSession();
      handler.next(error);
      return;
    }

    if (_isRefreshing) {
      // Otra request ya está refrescando: encolar esta y esperar el token nuevo.
      final completer = Completer<String?>();
      _pendingQueue.add(completer.complete);
      final token = await completer.future;
      if (token != null && token.isNotEmpty) {
        original.headers['Authorization'] = 'Bearer $token';
        // Marcar como reintentada ANTES de reintentar: si el token recién
        // rotado vuelve a ser rechazado con 401, el guard de arriba detiene
        // esta request en vez de re-encolarla en un ciclo que ya no se va a
        // flushear (deadlock: la cola esperaría un _flushQueue que nunca llega).
        original.extra['_retry'] = true;
        try {
          final response = await dio.fetch(original);
          handler.resolve(response);
        } catch (retryError) {
          handler.next(retryError is DioException ? retryError : error);
        }
      } else {
        handler.next(error);
      }
      return;
    }

    original.extra['_retry'] = true;
    _isRefreshing = true;

    try {
      final response = await dio.post<Map<String, dynamic>>(
        '/auth/refresh',
        data: {'refreshToken': refreshToken},
      );
      final data = response.data;
      if (data is! Map<String, dynamic>) {
        throw DioException(
          requestOptions: original,
          type: DioExceptionType.badResponse,
          message: 'Respuesta de refresh inválida',
        );
      }
      final tokens = AuthTokens.fromJson(data);
      // Rotación: el backend emite un refreshToken nuevo en cada refresh.
      await session?.saveRefreshToken(tokens.refreshToken);
      await session?.applyRefreshedTokens(tokens);
      _flushQueue(tokens.accessToken);
      original.headers['Authorization'] = 'Bearer ${tokens.accessToken}';
      final retried = await dio.fetch(original);
      handler.resolve(retried);
    } catch (refreshError) {
      _flushQueue(null);
      // Solo un 401 definitivo del refresh significa token inválido → limpiar
      // sesión. Errores transitorios (red, 5xx, cold start de Render)
      // conservan la sesión: la próxima request reintentará el refresh.
      if (refreshError is DioException &&
          refreshError.response?.statusCode == 401) {
        await session?.clearSession();
      }
      handler.next(refreshError is DioException ? refreshError : error);
    } finally {
      _isRefreshing = false;
    }
  }

  void _flushQueue(String? token) {
    final queue = List.of(_pendingQueue);
    _pendingQueue.clear();
    for (final resolve in queue) {
      resolve(token);
    }
  }
}