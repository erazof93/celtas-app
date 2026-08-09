import 'package:celtas_mobile/features/auth/data/models/auth_tokens.dart';
import 'package:dio/dio.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

/// Repositorio de auth contra el backend real.
///
/// Endpoints (contrato verificado contra `celtas-backend/src/modules/auth/
/// auth.controller.ts` y el interceptor global `TransformInterceptor`):
///   - `POST /auth/login`    → `{ success, data: AuthTokens }`
///   - `POST /auth/register` → `{ success, data: AuthTokens }`
///   - `POST /auth/google`   → `{ success, data: AuthTokens }` (body: idToken)
///   - `POST /auth/refresh`  → `{ success, data: AuthTokens }` (rotación)
///
/// El `accessToken` NUNCA se persiste acá: vive solo en memoria (estado de
/// Riverpod). El `refreshToken` sí, en `flutter_secure_storage`.
class AuthRepository {
  AuthRepository(this._dio, this._secureStorage);

  final Dio _dio;
  final FlutterSecureStorage _secureStorage;

  static const _refreshTokenKey = 'celtas_refresh_token';

  /// Login tradicional (email + password).
  Future<AuthTokens> login({
    required String email,
    required String password,
  }) async {
    final response = await _dio.post<Map<String, dynamic>>(
      '/auth/login',
      data: {'email': email, 'password': password},
    );
    return AuthTokens.fromJson(response.data!);
  }

  /// Registro tradicional (email + password + fullName, phone opcional).
  Future<AuthTokens> register({
    required String fullName,
    required String email,
    String? phone,
    required String password,
  }) async {
    final response = await _dio.post<Map<String, dynamic>>(
      '/auth/register',
      data: {
        'fullName': fullName,
        'email': email,
        'phone': phone,
        'password': password,
      },
    );
    return AuthTokens.fromJson(response.data!);
  }

  /// Login/registro con Google: obtiene el `idToken` real de la SDK de Google
  /// y lo envía al backend. NUNCA envía `password` en este flujo.
  ///
  /// PARTE 2 (pendiente): la integración con `google_sign_in` está aislada
  /// acá. El botón de la UI está deshabilitado hasta que se configure el
  /// Client ID de Google (prerrequisito del módulo 1 del ROADMAP).
  Future<AuthTokens> loginWithGoogle() async {
    // TODO(parte 2): GoogleSignIn().signIn() → idToken → POST /auth/google.
    throw UnimplementedError(
      'Login con Google: pendiente de configurar (Client ID de Google).',
    );
  }

  /// Renueva el access token con el refresh token (rotación: devuelve un
  /// refresh token nuevo que hay que persistir).
  Future<AuthTokens> refresh(String refreshToken) async {
    final response = await _dio.post<Map<String, dynamic>>(
      '/auth/refresh',
      data: {'refreshToken': refreshToken},
    );
    return AuthTokens.fromJson(response.data!);
  }

  // --- Persistencia del refresh token (flutter_secure_storage). ---

  Future<void> saveRefreshToken(String refreshToken) =>
      _secureStorage.write(key: _refreshTokenKey, value: refreshToken);

  Future<String?> readRefreshToken() =>
      _secureStorage.read(key: _refreshTokenKey);

  Future<void> clearRefreshToken() =>
      _secureStorage.delete(key: _refreshTokenKey);
}