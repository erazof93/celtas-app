import 'package:celtas_mobile/core/config/env.dart';
import 'package:celtas_mobile/core/network/api_client.dart';
import 'package:celtas_mobile/features/auth/data/models/auth_tokens.dart';
import 'package:dio/dio.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:google_sign_in/google_sign_in.dart';

/// El usuario cerró el selector de Google sin completar el login.
///
/// No es un error: la UI lo captura y no muestra ningún mensaje.
class GoogleSignInCanceledException implements Exception {
  const GoogleSignInCanceledException();
}

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
///
/// ## Google Sign-In (API 6.x — legacy)
///
/// Usamos `google_sign_in` 6.x en vez de 7.x porque la versión 7.x usa
/// Credential Manager de Android (`androidx.credentials`), que tiene bugs
/// conocidos en ciertos dispositivos (error `[16] Account reauth failed`
/// incluso con cuentas nuevas y SHA-1 correctos). La API 6.x usa el
/// `GoogleSignInClient` legacy que funciona de forma confiable.
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
    try {
      final response = await _dio.post<Map<String, dynamic>>(
        '/auth/login',
        data: {'email': email, 'password': password},
      );
      return AuthTokens.fromJson(response.data!);
    } on DioException catch (e) {
      throw apiExceptionFromDio(e);
    }
  }

  /// Registro tradicional (email + password + fullName, phone opcional).
  Future<AuthTokens> register({
    required String fullName,
    required String email,
    String? phone,
    required String password,
  }) async {
    try {
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
    } on DioException catch (e) {
      throw apiExceptionFromDio(e);
    }
  }

  /// Login/registro con Google: obtiene el `idToken` real de la SDK de Google
  /// y lo envía al backend. NUNCA envía `password` en este flujo.
  ///
  /// Patrón de `google_sign_in` 6.x (legacy): se crea una instancia con el
  /// `serverClientId` (Web application client del backend) y se llama
  /// `signIn()` que abre el selector de cuentas nativo de Google.
  ///
  /// Errores:
  ///   - El usuario cierra el picker → `GoogleSignInCanceledException` (la UI
  ///     lo ignora silenciosamente, no es un error).
  ///   - Fallo de red/plataforma de Google → `ApiException` con mensaje claro.
  ///   - El backend responde 409 (email ya existe como cuenta local) →
  ///     `ApiException` con el mensaje del backend.
  Future<AuthTokens> loginWithGoogle() async {
    final sw = Stopwatch()..start();
    void log(String msg) {
      final t = sw.elapsedMilliseconds;
      // ignore: avoid_print
      print('[AUTH-GOOGLE] [${t}ms] $msg');
    }

    log('PASO 1: Iniciando loginWithGoogle()');

    // ── Validación defensiva del serverClientId ──
    final serverId = AppConfig.googleServerClientId;
    if (serverId == null || serverId.isEmpty) {
      log('PASO 1a: FATAL — serverClientId es null o vacío');
      throw const ApiException(
        'Google Sign-In no está configurado. Contacta al soporte.',
      );
    }
    log('PASO 1b: serverClientId OK (${serverId.length} chars): '
        '${serverId.substring(0, 30)}...');

    // ── Crear instancia de GoogleSignIn (API 6.x) ──
    // Se crea cada vez para evitar estados residuales entre intentos.
    final signIn = GoogleSignIn(
      scopes: ['email', 'profile', 'openid'],
      serverClientId: serverId,
    );

    try {
      // ── Abrir selector de cuentas ──
      log('PASO 2: Llamando signIn.signIn() — abriendo picker...');
      final account = await signIn.signIn();
      log('PASO 2b: signIn() completado');

      // ── Verificar que el usuario no canceló ──
      if (account == null) {
        log('PASO 2c: account es null — usuario canceló');
        throw const GoogleSignInCanceledException();
      }
      log('PASO 2d: email: ${account.email}');

      // ── Extraer idToken ──
      log('PASO 3: Extrayendo authentication de account...');
      final authentication = await account.authentication;
      final idToken = authentication.idToken;
      if (idToken == null || idToken.isEmpty) {
        log('PASO 3b: FATAL — idToken es NULL o vacío');
        throw const ApiException(
          'Google no devolvió un token válido. Inténtalo de nuevo.',
        );
      }
      final preview = idToken.length > 30
          ? '${idToken.substring(0, 20)}...${idToken.substring(idToken.length - 10)}'
          : '(muy corto)';
      log('PASO 3b: idToken OK (${idToken.length} chars): $preview');

      // ── Enviar al backend ──
      log('PASO 4: Enviando POST /auth/google...');
      try {
        final response = await _dio.post<Map<String, dynamic>>(
          '/auth/google',
          data: {'idToken': idToken},
        );
        log('PASO 4b: Backend respondió OK — parseando AuthTokens');
        final tokens = AuthTokens.fromJson(response.data!);
        log('PASO 5: Login exitoso — usuario: ${tokens.user.email}');
        return tokens;
      } on DioException catch (e) {
        log('PASO 4b: ERROR backend — status: ${e.response?.statusCode}, '
            'message: ${e.message}, type: ${e.type}');
        throw apiExceptionFromDio(e);
      }
    } on GoogleSignInCanceledException {
      rethrow;
    } on ApiException {
      rethrow;
    } catch (e, stack) {
      log('EXCEPCIÓN inesperada: ${e.runtimeType}: $e');
      log('Stack: $stack');
      throw const ApiException(
        'No se pudo conectar con Google. Revisa tu conexión e inténtalo de nuevo.',
      );
    }
  }

  /// Cierra la sesión de Google en la SDK (best-effort): evita que el próximo
  /// login auto-seleccione la cuenta anterior en dispositivos compartidos.
  Future<void> signOutFromGoogle() async {
    try {
      // Se crea una instancia fresca para cerrar sesión.
      await GoogleSignIn().signOut();
    } catch (_) {
      // Best-effort: si la SDK no está inicializada o falla, no bloquea el
      // logout de la app.
    }
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
