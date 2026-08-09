import 'package:celtas_mobile/core/network/api_client.dart';
import 'package:celtas_mobile/core/network/auth_session_bridge.dart';
import 'package:celtas_mobile/features/auth/application/auth_providers.dart';
import 'package:celtas_mobile/features/auth/application/auth_state.dart';
import 'package:celtas_mobile/features/auth/data/auth_repository.dart';
import 'package:celtas_mobile/features/auth/data/models/auth_tokens.dart';
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

  Future<void> logout() async {
    await _repository.clearRefreshToken();
    state = const AuthState.unauthenticated();
  }
}