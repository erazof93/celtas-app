import 'package:celtas_mobile/features/auth/data/models/user.dart';
import 'package:flutter_test/flutter_test.dart';

/// Contrato real del backend (verificado contra `user.entity.ts` y
/// `celtas-admin/src/features/auth/types.ts`): el payload de `user` dentro de
/// `data` en login/register/google/refresh.
void main() {
  group('User.fromJson', () {
    test('deserializa un usuario local con todos los campos', () {
      final user = User.fromJson({
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
      });

      expect(user.id, 'user-1');
      expect(user.email, 'cliente@celtas.pe');
      expect(user.fullName, 'Cliente de Prueba');
      expect(user.provider, UserProvider.local);
      expect(user.googleId, isNull);
      expect(user.phone, '+51999999999');
      expect(user.fcmToken, isNull);
      expect(user.totalSpent, 128.5);
      expect(user.role, UserRole.cliente);
      expect(user.createdAt, DateTime.utc(2026, 1, 15, 10, 30));
      expect(user.updatedAt, DateTime.utc(2026, 2, 1, 8));
    });

    test('deserializa un usuario de Google con googleId y rol admin', () {
      final user = User.fromJson({
        'id': 'user-2',
        'email': 'admin@celtas.pe',
        'fullName': 'Admin Celtas',
        'provider': 'google',
        'googleId': 'google-abc-123',
        'phone': null,
        'fcmToken': 'fcm-token-1',
        'totalSpent': 0,
        'role': 'admin',
        'createdAt': '2026-03-01T00:00:00.000Z',
        'updatedAt': '2026-03-01T00:00:00.000Z',
      });

      expect(user.provider, UserProvider.google);
      expect(user.googleId, 'google-abc-123');
      expect(user.phone, isNull);
      expect(user.fcmToken, 'fcm-token-1');
      expect(user.role, UserRole.admin);
      expect(user.totalSpent, 0.0);
    });

    test('totalSpent numérico entero se convierte a double', () {
      final user = User.fromJson({
        'id': 'user-3',
        'email': 'a@b.pe',
        'fullName': 'A',
        'provider': 'local',
        'totalSpent': 42,
        'role': 'cliente',
        'createdAt': '2026-01-01T00:00:00.000Z',
        'updatedAt': '2026-01-01T00:00:00.000Z',
      });

      expect(user.totalSpent, isA<double>());
      expect(user.totalSpent, 42.0);
    });
  });

  group('User.toJson', () {
    test('round-trip: fromJson → toJson conserva el payload', () {
      final json = {
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

      expect(User.fromJson(json).toJson(), json);
    });

    test('round-trip con usuario de Google y campos opcionales presentes', () {
      final json = {
        'id': 'user-2',
        'email': 'admin@celtas.pe',
        'fullName': 'Admin Celtas',
        'provider': 'google',
        'googleId': 'google-abc-123',
        'phone': null,
        'fcmToken': 'fcm-token-1',
        'totalSpent': 0,
        'role': 'admin',
        'createdAt': '2026-03-01T00:00:00.000Z',
        'updatedAt': '2026-03-01T00:00:00.000Z',
      };

      expect(User.fromJson(json).toJson(), json);
    });
  });
}