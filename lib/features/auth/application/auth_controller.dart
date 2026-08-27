import 'package:celtas_mobile/core/network/api_client.dart';
import 'package:celtas_mobile/core/network/auth_session_bridge.dart';
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
  @override
  AuthState build() {
    // Se registra como puente de sesión del cliente HTTP y arranca el
    // bootstrap de la sesión (persistencia al reabrir la app).
    ApiClient.instance.session = this;
    Future.microtask(bootstrap);
    return const AuthState.unknown();
  }

  AuthRepository get _repository => ref.read(authRepositoryProvider);

  // --- AuthSessionBridge ---

  @override
  String? get accessToken => state.accessToken;

  @override
  Future<String?> readRefreshToken() => _repository.readRefreshToken();

  @override
  Future<void> saveRefreshToken(String refreshToken) =>
      _repository.saveRefreshToken(refreshToken);

  @override
  Future<void> applyRefreshedTokens(AuthTokens tokens) {
    state = AuthState.authenticated(
      user: tokens.user,
      accessToken: tokens.accessToken,
    );
    return Future.value();
  }

  @override
  Future<void> clearSession() async {
    await _repository.clearRefreshToken();
    state = const AuthState.unauthenticated();
  }

  // --- Flujo de sesión ---

  /// Restaura la sesión al reabrir la app: si hay refresh token persistido,
  /// pide un access token nuevo. Un 401 definitivo limpia la sesión; un error
  /// transitorio (red, 5xx, backend dormido) la conserva y deja el Splash en
  /// estado de error con reintento.
  Future<void> bootstrap() async {
    final refreshToken = await _repository.readRefreshToken();
    if (refreshToken == null || refreshToken.isEmpty) {
      state = const AuthState.unauthenticated();
      return;
    }
    try {
      final tokens = await _repository.refresh(refreshToken);
      await _repository.saveRefreshToken(tokens.refreshToken);
      state = AuthState.authenticated(
        user: tokens.user,
        accessToken: tokens.accessToken,
      );
    } on DioException catch (e) {
      if (e.response?.statusCode == 401) {
        await _repository.clearRefreshToken();
        state = const AuthState.unauthenticated();
      } else {
        state = const AuthState.error();
      }
    }
  }

  Future<void> login({
    required String email,
    required String password,
  }) async {
    final tokens = await _repository.login(email: email, password: password);
    await _repository.saveRefreshToken(tokens.refreshToken);
    state = AuthState.authenticated(
      user: tokens.user,
      accessToken: tokens.accessToken,
    );
  }

  Future<void> register({
    required String fullName,
    required String email,
    String? phone,
    required String password,
  }) async {
    final tokens = await _repository.register(
      fullName: fullName,
      email: email,
      phone: phone,
      password: password,
    );
    await _repository.saveRefreshToken(tokens.refreshToken);
    state = AuthState.authenticated(
      user: tokens.user,
      accessToken: tokens.accessToken,
    );
  }

  Future<void> loginWithGoogle() async {
    final tokens = await _repository.loginWithGoogle();
    await _repository.saveRefreshToken(tokens.refreshToken);
    state = AuthState.authenticated(
      user: tokens.user,
      accessToken: tokens.accessToken,
    );
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
    }
    // Cierra la sesión de Google en la SDK (best-effort) para que el próximo
    // login pida elegir cuenta en vez de auto-seleccionar la anterior.
    await _repository.signOutFromGoogle();
    await _repository.clearRefreshToken();
    state = const AuthState.unauthenticated();
  }
}