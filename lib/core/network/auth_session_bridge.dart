import 'package:celtas_mobile/features/auth/data/models/auth_tokens.dart';

/// Puente entre el cliente HTTP (`ApiClient`) y la sesión de auth.
///
/// Lo implementa `AuthController` (módulo auth) y lo registra `ApiClient`
/// para evitar una dependencia circular: `api_client.dart` necesita leer el
/// `accessToken` en memoria y persistir/rotar el `refreshToken`, pero no debe
/// conocer la implementación concreta del estado de Riverpod.
///
/// Es el equivalente Flutter de lo que en `celtas-admin` hace el import directo
/// de `useAuthStore` dentro de `api-client.ts`.
abstract class AuthSessionBridge {
  /// Access token actual, SOLO en memoria (se pierde al cerrar la app a
  /// propósito; se recupera con el refresh al reabrir).
  String? get accessToken;

  /// Changes on restore/login/logout, so old HTTP responses cannot commit
  /// credentials or replay requests in a different account.
  int get revision;

  /// Permite renovar la sesión autenticada, incluido el desregistro FCM
  /// durante logout; nunca inicia otro refresh durante el bootstrap.
  bool get canRefresh;

  /// Lee el refresh token persistido en `flutter_secure_storage`.
  Future<String?> readRefreshToken();

  /// Persiste y publica tokens solo si pertenecen a la sesión esperada.
  /// Devuelve false cuando el resultado ya es obsoleto.
  /// `isCurrent` also guards queued persistence when a global budget expires.
  Future<bool> commitRefreshedTokens(
    AuthTokens tokens, {
    required int expectedRevision,
    bool Function()? isCurrent,
  });

  /// Limpia la sesión completa: refresh token persistido + estado en memoria.
  Future<void> clearSession({int? expectedRevision});
}
