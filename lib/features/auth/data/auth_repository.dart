import 'package:celtas_mobile/core/config/env.dart';
import 'package:celtas_mobile/core/network/api_client.dart';
import 'package:celtas_mobile/features/auth/data/models/auth_tokens.dart';
import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:google_sign_in/google_sign_in.dart';

/// El usuario cerró el picker de Google sin completar el login.
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
class AuthRepository {
  AuthRepository(this._dio, this._secureStorage);

  final Dio _dio;
  final FlutterSecureStorage _secureStorage;

  static const _refreshTokenKey = 'celtas_refresh_token';

  /// La SDK de Google exige `initialize()` UNA sola vez por proceso (llamarlo
  /// más de una vez es "undefined behavior" según su documentación). La app
  /// tiene un único `AuthRepository` (provider singleton), así que un flag de
  /// instancia alcanza; si `initialize()` falla, el flag queda en false y el
  /// próximo intento reintenta.
  bool _googleInitialized = false;

  /// Flag que indica si hubo un error "reauth failed" en un intento previo.
  /// Cuando ocurre, el próximo intento llama a disconnect() antes de
  /// authenticate() para limpiar el estado corrupto de la SDK de Google.
  bool _hadReauthFailure = false;

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
  /// Patrón de `google_sign_in` 7.x: `initialize()` (UNA sola vez, con el
  /// Client ID "Web application" del backend) + `authenticate()` (picker
  /// interactivo).
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

    final signIn = GoogleSignIn.instance;
    try {
      // ── initialize() solo la primera vez ──
      if (!_googleInitialized) {
        log('PASO 2: Llamando signIn.initialize(serverClientId)...');
        await signIn.initialize(serverClientId: serverId);
        _googleInitialized = true;
        log('PASO 2b: initialize() completado OK');
      } else {
        log('PASO 2: initialize() ya ejecutado (skip)');
      }

      // ── Pre-cleanup solo si hubo error previo ──
      if (_hadReauthFailure) {
        log('PASO 3: Llamando disconnect() (post-reauth previo)...');
        try {
          await signIn.disconnect();
          log('PASO 3b: disconnect() completado OK');
        } catch (e) {
          log('PASO 3b: disconnect() falló: $e');
        }
      } else {
        log('PASO 3: Sin error previo — skip disconnect()');
      }

      // ── Abrir selector de cuentas ──
      log('PASO 4: Llamando signIn.authenticate() — abriendo picker...');
      final account = await signIn.authenticate();
      log('PASO 4b: authenticate() completado — email: ${account.email}');

      // ── Extraer idToken ──
      log('PASO 5: Extrayendo idToken de account.authentication...');
      final idToken = account.authentication.idToken;
      if (idToken == null || idToken.isEmpty) {
        log('PASO 5b: FATAL — idToken es NULL o vacío');
        throw const ApiException(
          'Google no devolvió un token válido. Inténtalo de nuevo.',
        );
      }
      final preview = idToken.length > 30
          ? '${idToken.substring(0, 20)}...${idToken.substring(idToken.length - 10)}'
          : '(muy corto)';
      log('PASO 5b: idToken OK (${idToken.length} chars): $preview');

      // ── Enviar al backend ──
      log('PASO 6: Enviando POST /auth/google...');
      try {
        final response = await _dio.post<Map<String, dynamic>>(
          '/auth/google',
          data: {'idToken': idToken},
        );
        log('PASO 6b: Backend respondió OK — parseando AuthTokens');
        final tokens = AuthTokens.fromJson(response.data!);
        log('PASO 7: Login exitoso — usuario: ${tokens.user.email}');
        return tokens;
      } on DioException catch (e) {
        log('PASO 6b: ERROR backend — status: ${e.response?.statusCode}, '
            'message: ${e.message}, type: ${e.type}');
        throw apiExceptionFromDio(e);
      }
    } on GoogleSignInException catch (e) {
      log('EXCEPCIÓN GoogleSignInException: '
          'code=${e.code}, desc=${e.description}, details=${e.details}');

      if (e.code == GoogleSignInExceptionCode.canceled ||
          e.code == GoogleSignInExceptionCode.interrupted ||
          e.code == GoogleSignInExceptionCode.uiUnavailable) {
        final desc = e.description ?? '';
        if (desc.contains('reauth failed') || desc.contains('[16]')) {
          log('→ Detectado reauth failed — flag _hadReauthFailure = true');
          _hadReauthFailure = true;
          throw const ApiException(
            'La sesión de Google expiró. Ve a Ajustes del dispositivo > '
            'Cuentas > Google y verifica que la cuenta esté activa, '
            'luego intenta de nuevo.',
          );
        }
        throw const GoogleSignInCanceledException();
      }
      throw const ApiException(
        'No se pudo conectar con Google. Revisa tu conexión e inténtalo de nuevo.',
      );
    } on ApiException {
      rethrow;
    } catch (e, stack) {
      log('EXCEPCIÓN inesperada: ${e.runtimeType}: $e');
      log('Stack: $stack');
      throw const ApiException(
        'Error inesperado al conectar con Google.',
      );
    }
  }

  /// Cierra la sesión de Google en la SDK (best-effort): evita que el próximo
  /// login auto-seleccione la cuenta anterior en dispositivos compartidos.
  Future<void> signOutFromGoogle() async {
    try {
      await GoogleSignIn.instance.signOut();
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