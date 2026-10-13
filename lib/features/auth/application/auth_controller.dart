import 'dart:async';

import 'package:celtas_mobile/core/network/api_client.dart';
import 'package:celtas_mobile/core/network/auth_session_bridge.dart';
import 'package:celtas_mobile/features/addresses/data/address_selection_storage.dart';
import 'package:celtas_mobile/features/auth/application/auth_providers.dart';
import 'package:celtas_mobile/features/auth/application/auth_state.dart';
import 'package:celtas_mobile/features/auth/data/auth_repository.dart';
import 'package:celtas_mobile/features/auth/data/models/auth_tokens.dart';
import 'package:celtas_mobile/features/auth/data/models/user.dart';
import 'package:celtas_mobile/features/notifications/application/notification_providers.dart';
import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Controlador de la sesión de auth.
///
/// Implementa `AuthSessionBridge` para que `ApiClient` pueda leer el
/// `accessToken` en memoria y rotar el `refreshToken` sin conocer el estado de
/// Riverpod (mismo rol que `useAuthStore` en `celtas-admin`).
class AuthController extends Notifier<AuthState> implements AuthSessionBridge {
  int _revision = 0;
  bool _disposed = false;
  int? _accountChangeRevision;
  int? _logoutNetworkRevision;
  _RestoreAttempt? _restore;

  @override
  AuthState build() {
    // Riverpod retains this Notifier when invalidating/rebuilding its provider.
    // Start a new lifetime so old reads, logins and queued writes stay obsolete.
    _disposed = false;
    _revision++;
    _accountChangeRevision = null;
    _logoutNetworkRevision = null;
    // Se registra como puente de sesión del cliente HTTP y arranca el
    // bootstrap de la sesión (persistencia al reabrir la app).
    ApiClient.instance.session = this;
    final initialRevision = _revision;
    Future.microtask(() {
      if (_owns(initialRevision)) return bootstrap();
    });
    ref.onDispose(() {
      _disposed = true;
      _stopRestore();
      ApiClient.instance.sessionActivityChanged(this);
      if (identical(ApiClient.instance.session, this)) {
        ApiClient.instance.session = null;
      }
    });
    return const AuthState.unknown();
  }

  AuthRepository get _repository => ref.read(authRepositoryProvider);

  // --- AuthSessionBridge ---

  @override
  String? get accessToken => state.accessToken;

  @override
  int get revision => _revision;

  @override
  bool get canRefresh =>
      !_disposed &&
      (_accountChangeRevision == null || _logoutNetworkRevision == _revision) &&
      state.status == AuthStatus.authenticated;

  /// Logout may refresh its DELETE, but must never register a push token.
  bool get canRegisterNotifications =>
      !_disposed &&
      _accountChangeRevision == null &&
      state.status == AuthStatus.authenticated;

  bool _owns(int owner) => !_disposed && owner == _revision;

  bool _ownsRestore(_RestoreAttempt attempt) =>
      _owns(attempt.revision) && identical(_restore, attempt);

  void _stopRestore() {
    final attempt = _restore;
    _restore = null;
    if (attempt == null) return;
    attempt.deadline?.cancel();
    attempt.cancelToken.cancel('Session restore ended');
    if (!attempt.done.isCompleted) attempt.done.complete();
  }

  int _beginAccountChange() {
    _stopRestore();
    _revision++;
    _accountChangeRevision = _revision;
    ApiClient.instance.sessionActivityChanged(this);
    if (state.status == AuthStatus.unknown) {
      state = const AuthState.error(
        message: 'No pudimos restaurar tu sesión. Inténtalo nuevamente.',
      );
    }
    return _revision;
  }

  void _endAccountChange(int owner) {
    if (_accountChangeRevision == owner) {
      _accountChangeRevision = null;
      if (!_disposed) ApiClient.instance.sessionActivityChanged(this);
    }
  }

  Future<bool> _commit(
    AuthTokens tokens,
    int owner, {
    bool Function()? isCurrent,
    bool changesAccount = false,
  }) async {
    bool current() => _owns(owner) && (isCurrent?.call() ?? true);
    if (!current()) return false;
    await _repository.saveRefreshToken(tokens.refreshToken, isCurrent: current);
    if (!current()) return false;
    // Requests sent using the previous account while a login was pending
    // must also become obsolete when the new account is published.
    if (changesAccount) _revision++;
    state = AuthState.authenticated(
      user: tokens.user,
      accessToken: tokens.accessToken,
    );
    return true;
  }

  @override
  Future<String?> readRefreshToken() => _repository.readRefreshToken();

  @override
  Future<bool> commitRefreshedTokens(
    AuthTokens tokens, {
    required int expectedRevision,
    bool Function()? isCurrent,
  }) async {
    if (!canRefresh) return false;
    return _commit(
      tokens,
      expectedRevision,
      isCurrent: () => canRefresh && (isCurrent?.call() ?? true),
    );
  }

  @override
  Future<void> clearSession({int? expectedRevision}) async {
    if (expectedRevision != null && !_owns(expectedRevision)) return;
    final duringLogout =
        expectedRevision != null && expectedRevision == _logoutNetworkRevision;
    final owner = duringLogout ? _revision : _beginAccountChange();
    state = const AuthState.unauthenticated();
    try {
      await _repository.clearRefreshToken();
    } finally {
      if (!duringLogout) _endAccountChange(owner);
    }
  }

  // --- Flujo de sesión ---

  /// Restaura la sesión al reabrir la app: si hay refresh token persistido,
  /// pide un access token nuevo. Un 401 definitivo limpia la sesión; un error
  /// transitorio (red, 5xx, backend dormido) la conserva y deja el Splash en
  /// estado de error con reintento.
  Future<void> bootstrap() {
    final pending = _restore;
    if (pending != null) return pending.done.future;
    if (_disposed ||
        _accountChangeRevision != null ||
        state.status == AuthStatus.authenticated) {
      return Future.value();
    }
    final attempt = _RestoreAttempt(++_revision);
    _restore = attempt;
    state = const AuthState.unknown();
    attempt.deadline = Timer(const Duration(seconds: 20), () {
      if (!_ownsRestore(attempt)) return;
      if (!attempt.rejected) {
        state = const AuthState.error(
          message:
              'La restauración está tardando demasiado. Inténtalo nuevamente.',
        );
      }
      _stopRestore();
    });
    unawaited(_runRestore(attempt, _repository));
    return attempt.done.future;
  }

  Future<void> _runRestore(
    _RestoreAttempt attempt,
    AuthRepository repository,
  ) async {
    var storageOperation = true;
    try {
      final refreshToken = await repository.readRefreshToken();
      if (!_ownsRestore(attempt)) return;
      if (refreshToken == null || refreshToken.isEmpty) {
        state = const AuthState.unauthenticated();
        return;
      }
      storageOperation = false;
      final tokens = await repository.refresh(
        refreshToken,
        cancelToken: attempt.cancelToken,
      );
      if (!_ownsRestore(attempt)) return;
      storageOperation = true;
      await _commit(
        tokens,
        attempt.revision,
        isCurrent: () => _ownsRestore(attempt),
      );
    } catch (error) {
      if (!_ownsRestore(attempt)) return;
      if (!storageOperation &&
          error is DioException &&
          error.response?.statusCode == 401) {
        attempt.rejected = true;
        state = const AuthState.unauthenticated();
        try {
          await repository.clearRefreshToken();
        } catch (_) {
          // A confirmed invalid session stays unauthenticated even if local
          // deletion fails. Never let an old deletion overtake another login.
        }
      } else {
        final kind = error is DioException
            ? apiExceptionFromDio(error).kind
            : ApiErrorKind.other;
        state = AuthState.error(
          message: storageOperation
              ? 'No pudimos leer o guardar tu sesión. Inténtalo nuevamente.'
              : switch (kind) {
                  ApiErrorKind.connection =>
                    'No pudimos conectar para restaurar tu sesión. Revisa tu conexión e inténtalo nuevamente.',
                  ApiErrorKind.timeout =>
                    'La restauración está tardando demasiado. Inténtalo nuevamente.',
                  ApiErrorKind.server =>
                    'El servicio está temporalmente no disponible. Inténtalo de nuevo en un momento.',
                  ApiErrorKind.other =>
                    'No pudimos restaurar tu sesión. Inténtalo nuevamente.',
                },
        );
      }
    } finally {
      if (_ownsRestore(attempt)) _stopRestore();
    }
  }

  Future<void> login({required String email, required String password}) async {
    final owner = _beginAccountChange();
    try {
      final tokens = await _repository.login(email: email, password: password);
      await _commit(tokens, owner, changesAccount: true);
    } finally {
      _endAccountChange(owner);
    }
  }

  Future<void> register({
    required String fullName,
    required String email,
    String? phone,
    required String password,
  }) async {
    final owner = _beginAccountChange();
    try {
      final tokens = await _repository.register(
        fullName: fullName,
        email: email,
        phone: phone,
        password: password,
      );
      await _commit(tokens, owner, changesAccount: true);
    } finally {
      _endAccountChange(owner);
    }
  }

  Future<void> loginWithGoogle() async {
    final owner = _beginAccountChange();
    try {
      final tokens = await _repository.loginWithGoogle();
      await _commit(tokens, owner, changesAccount: true);
    } finally {
      _endAccountChange(owner);
    }
  }

  /// Sincroniza el `user` en memoria tras editar el perfil (módulo 6), para
  /// que cualquier pantalla que lea `authControllerProvider` (no solo la de
  /// Perfil) refleje el nombre/teléfono nuevos sin esperar al próximo
  /// refresh de sesión.
  void updateUser(User user) {
    final accessToken = state.accessToken;
    if (state.status != AuthStatus.authenticated || accessToken == null) {
      return;
    }
    state = AuthState.authenticated(user: user, accessToken: accessToken);
  }

  Future<void> logout() async {
    final owner = _beginAccountChange();
    _logoutNetworkRevision = owner;
    try {
      // Best-effort: borra el fcmToken del dispositivo ANTES de limpiar el
      // estado — necesita el accessToken todavía vigente para autenticar el
      // DELETE. Evita que, en un celular compartido, la próxima cuenta que
      // inicie sesión reciba notificaciones de pedidos de esta cuenta. Si
      // falla (backend dormido, sin red), no bloquea el logout local: el
      // token queda hasta que el próximo login en este dispositivo lo
      // sobrescriba (mismo comportamiento que antes de este cambio).
      try {
        await ref.read(notificationRepositoryProvider).clearFcmToken();
      } catch (_) {
        // Ignorado a propósito.
      } finally {
        if (_logoutNetworkRevision == owner) _logoutNetworkRevision = null;
      }
      // Cierra la sesión de Google en la SDK (best-effort) para que el próximo
      // login pida elegir cuenta en vez de auto-seleccionar la anterior.
      if (!_owns(owner)) return;
      await _repository.signOutFromGoogle();
      if (!_owns(owner)) return;
      state = const AuthState.unauthenticated();
      await _repository.clearRefreshToken();
      // La "dirección seleccionada" es un UUID de una dirección de ESTA cuenta —
      // no debe arrastrarse a la siguiente en un celular compartido. (El
      // `resolveActiveAddress` igual se auto-cura si el id no está en la lista,
      // esto es solo prolijidad.)
      if (_owns(owner)) await ref.read(addressSelectionStorageProvider).clear();
    } finally {
      _endAccountChange(owner);
    }
  }
}

class _RestoreAttempt {
  _RestoreAttempt(this.revision);
  final int revision;
  final cancelToken = CancelToken();
  final done = Completer<void>();
  Timer? deadline;
  bool rejected = false;
}
