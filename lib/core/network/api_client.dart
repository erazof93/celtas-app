import 'dart:async';

import 'package:celtas_mobile/core/config/env.dart';
import 'package:celtas_mobile/core/network/auth_session_bridge.dart';
import 'package:celtas_mobile/features/auth/data/models/auth_tokens.dart';
import 'package:dio/dio.dart';

/// Evidence from Dio/HTTP; a connection failure does not prove Internet loss.
enum ApiErrorKind { connection, timeout, server, other }

/// Excepción de dominio con el mensaje ya extraído del envelope de error del
/// backend (`{ success: false, message, statusCode }`).
class ApiException implements Exception {
  // Public named argument stays `kind`; the backing field enables HTTP fallback.
  const ApiException(this.message, {this.statusCode, ApiErrorKind? kind})
    // ignore: prefer_initializing_formals
    : _kind = kind;

  final String message;
  final int? statusCode;
  final ApiErrorKind? _kind;

  ApiErrorKind get kind =>
      _kind ??
      (statusCode != null && statusCode! >= 500 && statusCode! < 600
          ? ApiErrorKind.server
          : ApiErrorKind.other);

  @override
  String toString() => message;
}

/// Convierte un `DioException` en un `ApiException` legible para la UI:
/// extrae `message` del envelope de error del backend cuando existe, y usa un
/// mensaje genérico de conexión para errores de red/timeout.
ApiException apiExceptionFromDio(DioException error) {
  final status = error.response?.statusCode;
  final kind = status != null && status >= 500 && status < 600
      ? ApiErrorKind.server
      : switch (error.type) {
          DioExceptionType.connectionTimeout ||
          DioExceptionType.sendTimeout ||
          DioExceptionType.receiveTimeout ||
          DioExceptionType.transformTimeout => ApiErrorKind.timeout,
          DioExceptionType.connectionError ||
          DioExceptionType.badCertificate => ApiErrorKind.connection,
          _ => ApiErrorKind.other,
        };
  final data = error.response?.data;
  if (data is Map<String, dynamic> && data['message'] is String) {
    return ApiException(
      data['message'] as String,
      statusCode: status,
      kind: kind,
    );
  }
  switch (error.type) {
    case DioExceptionType.connectionTimeout:
    case DioExceptionType.sendTimeout:
    case DioExceptionType.receiveTimeout:
    case DioExceptionType.transformTimeout:
      return ApiException(
        'El servidor tardó demasiado en responder. Inténtalo de nuevo.',
        statusCode: status,
        kind: kind,
      );
    case DioExceptionType.connectionError:
    case DioExceptionType.badCertificate:
      return ApiException(
        'No se pudo conectar con el servidor. Revisa tu conexión e inténtalo de nuevo.',
        statusCode: status,
        kind: kind,
      );
    default:
      return ApiException(
        'Ocurrió un error inesperado. Inténtalo de nuevo.',
        statusCode: status,
        kind: kind,
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
    dio.interceptors.add(
      InterceptorsWrapper(
        onRequest: _onRequest,
        onResponse: _onResponse,
        onError: _onError,
      ),
    );
  }

  /// Instancia única del cliente.
  static final ApiClient instance = ApiClient._internal();

  /// Instancia de `dio` configurada, lista para uso directo por repositorios.
  final Dio dio;

  /// Puente a la sesión de auth, registrado por `AuthController` al arrancar.
  AuthSessionBridge? _session;
  AuthSessionBridge? get session => _session;
  set session(AuthSessionBridge? value) {
    if (identical(_session, value)) return;
    final pending = _refresh;
    if (pending != null) _finishRefresh(pending, _obsolete(pending));
    _session = value;
  }

  /// Hook opcional que se dispara tras CADA refresh silencioso exitoso de la
  /// sesión (401 → `POST /auth/refresh` OK → tokens rotados), justo después de
  /// aplicar los tokens nuevos. Lo registra la capa de notificaciones
  /// (`NotificationService.init`) para re-sincronizar el `fcmToken`: cierra la
  /// ventana en la que Firebase rota el token del dispositivo mientras la
  /// sesión está vencida y ese aviso se perdería hasta el próximo login
  /// explícito. Mismo patrón que `session` — un hook que otra capa registra.
  /// Best-effort: si el callback lanza, no rompe el reintento de la request
  /// original.
  void Function()? onSessionRefreshed;

  /// Synchronous account boundary; notification work stops before logout I/O.
  void Function(AuthSessionBridge)? onSessionActivityChanged;

  void sessionActivityChanged(AuthSessionBridge owner) {
    final pending = _refresh;
    if (pending != null &&
        identical(pending.owner, owner) &&
        !_currentRefresh(pending)) {
      _finishRefresh(pending, _obsolete(pending));
    }
    try {
      onSessionActivityChanged?.call(owner);
    } catch (_) {
      // An optional consumer must not prevent a local account transition.
    }
  }

  /// Endpoints de auth que nunca entran al ciclo de refresh (evita loops).
  static const _authEndpoints = {
    '/auth/login',
    '/auth/refresh',
    '/auth/register',
    '/auth/google',
  };

  _SilentRefresh? _refresh;
  _CredentialRead? _credentialRead;

  // --- Interceptor de request: adjunta el access token en memoria. ---

  Future<void> _onRequest(
    RequestOptions options,
    RequestInterceptorHandler handler,
  ) async {
    final activeSession = session;
    if (options.extra['_retry'] == true &&
        (options.extra['_sessionRevision'] != activeSession?.revision ||
            !identical(options.extra['_sessionOwner'], activeSession))) {
      handler.reject(
        DioException(
          requestOptions: options,
          type: DioExceptionType.cancel,
          message: 'Session changed before retry',
        ),
      );
      return;
    }
    final token = activeSession?.accessToken;
    options.extra['_sessionRevision'] = activeSession?.revision;
    options.extra['_sessionOwner'] = activeSession;
    if (token != null && token.isNotEmpty) {
      options.headers['Authorization'] = 'Bearer $token';
    }
    handler.next(options);
  }

  // --- Interceptor de response: desenvuelve el envelope estándar. ---

  void _onResponse(
    Response<dynamic> response,
    ResponseInterceptorHandler handler,
  ) {
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
    final owner = session;
    final revision = owner?.revision;
    bool current() =>
        owner != null &&
        identical(session, owner) &&
        owner.revision == revision &&
        owner.canRefresh;
    if (error.response?.statusCode != 401 ||
        _authEndpoints.contains(original.path) ||
        original.extra['_retry'] == true ||
        !current() ||
        original.extra['_sessionRevision'] != revision ||
        !identical(original.extra['_sessionOwner'], owner)) {
      handler.next(error);
      return;
    }
    // A delayed 401 may belong to a request sent before another refresh
    // published its token. Replay once with that token instead of rotating again.
    final publishedToken = owner!.accessToken;
    if (publishedToken != null &&
        publishedToken.isNotEmpty &&
        original.headers['Authorization'] != 'Bearer $publishedToken') {
      await _replay(original, publishedToken, error, handler);
      return;
    }
    // Join before reading storage: the entire restore, not only HTTP, is shared.
    var attempt = _refresh;
    if (attempt != null &&
        (!identical(attempt.owner, owner) || attempt.revision != revision)) {
      _finishRefresh(attempt, _obsolete(attempt));
      attempt = null;
    }
    if (attempt == null) {
      attempt = _SilentRefresh(owner, revision!, error);
      _refresh = attempt;
      final started = attempt;
      started.deadline = Timer(const Duration(seconds: 20), () {
        _finishRefresh(
          started,
          _RefreshOutcome.error(
            DioException(
              requestOptions: original,
              type: DioExceptionType.receiveTimeout,
              error: TimeoutException('Silent refresh exceeded 20 seconds'),
            ),
          ),
        );
      });
      unawaited(_runRefresh(started));
    }
    final outcome = await attempt.done.future;
    if (outcome.error != null) {
      handler.next(outcome.error!);
      return;
    }
    if (!current() || outcome.token == null) {
      handler.next(error);
      return;
    }
    await _replay(original, outcome.token!, error, handler);
  }

  Future<void> _replay(
    RequestOptions original,
    String token,
    DioException error,
    ErrorInterceptorHandler handler,
  ) async {
    original.extra['_retry'] = true;
    original.headers['Authorization'] = 'Bearer $token';
    try {
      final response = await dio.fetch(original);
      handler.resolve(response);
    } catch (retryError) {
      handler.next(retryError is DioException ? retryError : error);
    }
  }

  bool _currentRefresh(_SilentRefresh attempt) =>
      attempt.active &&
      identical(session, attempt.owner) &&
      attempt.owner.revision == attempt.revision &&
      attempt.owner.canRefresh;

  _RefreshOutcome _obsolete(_SilentRefresh attempt) => _RefreshOutcome.error(
    DioException(
      requestOptions: attempt.original.requestOptions,
      type: DioExceptionType.cancel,
      message: 'Session changed during refresh',
    ),
  );

  Future<String?> _readCredentials(_SilentRefresh attempt) {
    final pending = _credentialRead;
    if (pending != null &&
        identical(pending.owner, attempt.owner) &&
        pending.revision == attempt.revision) {
      return pending.future;
    }
    final read = _CredentialRead(
      attempt.owner,
      attempt.revision,
      Future<String?>.sync(attempt.owner.readRefreshToken),
    );
    _credentialRead = read;
    read.future.then<void>(
      (_) {
        if (identical(_credentialRead, read)) _credentialRead = null;
      },
      onError: (Object error, StackTrace stack) {
        if (identical(_credentialRead, read)) _credentialRead = null;
      },
    );
    return read.future;
  }

  Future<void> _runRefresh(_SilentRefresh attempt) async {
    var http = false;
    try {
      final refreshToken = await _readCredentials(attempt);
      if (!_currentRefresh(attempt)) {
        _finishRefresh(attempt, _obsolete(attempt));
        return;
      }
      if (refreshToken == null || refreshToken.isEmpty) {
        _finishRefresh(attempt, _RefreshOutcome.error(attempt.original));
        await attempt.owner.clearSession(expectedRevision: attempt.revision);
        return;
      }
      http = true;
      final response = await dio.post<Map<String, dynamic>>(
        '/auth/refresh',
        data: {'refreshToken': refreshToken},
        cancelToken: attempt.cancelToken,
      );
      if (!_currentRefresh(attempt)) {
        _finishRefresh(attempt, _obsolete(attempt));
        return;
      }
      http =
          false; // A storage exception carrying 401 is not an HTTP rejection.
      final data = response.data;
      if (data is! Map<String, dynamic>) {
        throw StateError('Invalid refresh response');
      }
      final tokens = AuthTokens.fromJson(data);
      final committed = await attempt.owner.commitRefreshedTokens(
        tokens,
        expectedRevision: attempt.revision,
        isCurrent: () => _currentRefresh(attempt),
      );
      if (!_currentRefresh(attempt)) {
        _finishRefresh(attempt, _obsolete(attempt));
        return;
      }
      if (!committed) {
        _finishRefresh(attempt, _obsolete(attempt));
        return;
      }
      try {
        onSessionRefreshed?.call();
      } catch (_) {}
      _finishRefresh(attempt, _RefreshOutcome.success(tokens.accessToken));
    } catch (error) {
      if (!attempt.active) return;
      if (!_currentRefresh(attempt)) {
        _finishRefresh(attempt, _obsolete(attempt));
        return;
      }
      if (http && error is DioException && error.response?.statusCode == 401) {
        // Publish the confirmed rejection without waiting indefinitely for a
        // native deletion. Auth queues it before any subsequent account write.
        _finishRefresh(attempt, _RefreshOutcome.error(error));
        try {
          await attempt.owner.clearSession(expectedRevision: attempt.revision);
        } catch (_) {}
      } else {
        // Storage/model failures do not inherit the original response's 401.
        final failure = http && error is DioException
            ? error
            : DioException(
                requestOptions: attempt.original.requestOptions,
                error: error,
              );
        _finishRefresh(attempt, _RefreshOutcome.error(failure));
      }
    }
  }

  void _finishRefresh(_SilentRefresh attempt, _RefreshOutcome outcome) {
    if (!attempt.active) return;
    attempt.active = false;
    attempt.deadline?.cancel();
    attempt.cancelToken.cancel('Silent refresh ended');
    if (identical(_refresh, attempt)) _refresh = null;
    attempt.done.complete(outcome);
  }
}

class _SilentRefresh {
  _SilentRefresh(this.owner, this.revision, this.original);
  final AuthSessionBridge owner;
  final int revision;
  final DioException original;
  final done = Completer<_RefreshOutcome>();
  final cancelToken = CancelToken();
  Timer? deadline;
  bool active = true;
}

class _RefreshOutcome {
  const _RefreshOutcome.success(this.token) : error = null;
  const _RefreshOutcome.error(this.error) : token = null;
  final String? token;
  final DioException? error;
}

class _CredentialRead {
  _CredentialRead(this.owner, this.revision, this.future);
  final AuthSessionBridge owner;
  final int revision;
  final Future<String?> future;
}
