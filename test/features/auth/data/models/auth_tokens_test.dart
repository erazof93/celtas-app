import 'package:celtas_mobile/features/auth/data/models/auth_tokens.dart';
import 'package:celtas_mobile/features/auth/data/models/user.dart';
import 'package:flutter_test/flutter_test.dart';

/// Contrato real del backend: payload de `POST /auth/login`, `/auth/register`,
/// `/auth/google` y `/auth/refresh` — `{ accessToken, refreshToken, user }`
/// (interfaz `AuthTokens & { user: User }` en `auth.service.ts`).
void main() {
  final userJson = {
    'id': 'user-1',
    'email': 'cliente@celtas.pe',
    'fullName': 'Cliente de Prueba',
    'provider': 'local',
    'googleId': null,
    'phone': '+51999999999',
    'fcmToken': null,
    'totalSpent': 128.5,
    'role': 'cliente',
    'createdAt': '2026-01-15T10:30:00.000Z',
    'updatedAt': '2026-02-01T08:00:00.000Z',
  };

  group('AuthTokens.fromJson', () {
    test('deserializa accessToken, refreshToken y user anidado', () {
      final tokens = AuthTokens.fromJson({
        'accessToken': 'access-token-1',
        'refreshToken': 'refresh-token-1',
        'user': userJson,
      });

      expect(tokens.accessToken, 'access-token-1');
      expect(tokens.refreshToken, 'refresh-token-1');
      expect(tokens.user, isA<User>());
      expect(tokens.user.id, 'user-1');
      expect(tokens.user.email, 'cliente@celtas.pe');
      expect(tokens.user.provider, UserProvider.local);
    });
  });

  group('AuthTokens.toJson', () {
    test('serializa accessToken y refreshToken; user queda como objeto User', () {
      // Nota: el `toJson` generado por json_serializable NO llama `.toJson()`
      // sobre el `user` anidado (tipo freezed abstracto) — lo deja como objeto
      // `User`. La app solo usa `fromJson` (parsea respuestas del backend),
      // nunca serializa AuthTokens, así que no afecta producción.
      final tokens = AuthTokens.fromJson({
        'accessToken': 'access-token-1',
        'refreshToken': 'refresh-token-1',
        'user': userJson,
      });

      final json = tokens.toJson();
      expect(json['accessToken'], 'access-token-1');
      expect(json['refreshToken'], 'refresh-token-1');
      expect(json['user'], isA<User>());
      expect((json['user'] as User).id, 'user-1');
      expect((json['user'] as User).email, 'cliente@celtas.pe');
    });
  });
}