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

  /// Lee el refresh token persistido en `flutter_secure_storage`.
  Future<String?> readRefreshToken();

  /// Persiste el refresh token (rotación: el backend emite uno nuevo en cada
  /// refresh).
  Future<void> saveRefreshToken(String refreshToken);

  /// Aplica los tokens recién emitidos por el refresh al estado en memoria
  /// (accessToken + user actualizado).
  Future<void> applyRefreshedTokens(AuthTokens tokens);

  /// Limpia la sesión completa: refresh token persistido + estado en memoria.
  Future<void> clearSession();
}