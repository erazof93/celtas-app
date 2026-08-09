import 'package:celtas_mobile/features/auth/data/models/user.dart';
import 'package:flutter/foundation.dart';

/// Ciclo de vida de la sesión.
enum AuthStatus {
  /// Arrancando: el Splash está haciendo bootstrap de la sesión (refresh).
  unknown,

  /// Sesión válida: hay accessToken en memoria + user.
  authenticated,

  /// Sin sesión: no hay refresh token persistido (o fue invalidado).
  unauthenticated,

  /// El bootstrap falló por un error transitorio (red, 5xx, cold start de
  /// Render). El refresh token se conserva y el Splash ofrece reintentar.
  error,
}

/// Estado de la sesión de auth.
///
/// El `accessToken` vive SOLO acá, en memoria — nunca se persiste (decisión de
/// seguridad del proyecto). El `refreshToken` vive en `flutter_secure_storage`
/// y se recupera con el refresh al reabrir la app.
@immutable
class AuthState {
  const AuthState._({required this.status, this.user, this.accessToken});

  const AuthState.unknown() : this._(status: AuthStatus.unknown);

  const AuthState.authenticated({
    required User user,
    required String accessToken,
  }) : this._(
          status: AuthStatus.authenticated,
          user: user,
          accessToken: accessToken,
        );

  const AuthState.unauthenticated() : this._(status: AuthStatus.unauthenticated);

  const AuthState.error() : this._(status: AuthStatus.error);

  final AuthStatus status;
  final User? user;
  final String? accessToken;
}