import 'package:celtas_mobile/features/auth/application/auth_providers.dart';
import 'package:celtas_mobile/features/auth/data/auth_repository.dart';
import 'package:celtas_mobile/features/auth/data/models/auth_tokens.dart';
import 'package:celtas_mobile/features/auth/data/models/user.dart';
import 'package:celtas_mobile/features/notifications/application/notification_providers.dart';
import 'package:celtas_mobile/features/notifications/data/notification_repository.dart';
import 'package:celtas_mobile/features/profile/application/profile_providers.dart';
import 'package:celtas_mobile/features/profile/data/profile_repository.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

class MockProfileRepository extends Mock implements ProfileRepository {}

class MockAuthRepository extends Mock implements AuthRepository {}

class MockNotificationRepository extends Mock implements NotificationRepository {}

User _mk(String id, String name) => User(
      id: id,
      email: '$id@email.com',
      fullName: name,
      provider: UserProvider.local,
      phone: '+51 1',
      totalSpent: 0,
      role: UserRole.cliente,
      createdAt: DateTime.utc(2026),
      updatedAt: DateTime.utc(2026),
    );

// REGRESION PENDIENTE (hallazgo QA, sesion de mantenimiento 2026-09-02):
// `profileProvider` es un AsyncNotifierProvider keep-alive (no autoDispose) y
// NADIE lo invalida en `AuthController.logout()` ni en `login()`. Resultado:
// tras logout + login de OTRA cuenta sin reiniciar la app, la pantalla de
// Perfil muestra los datos del usuario anterior hasta que algo mas fuerce el
// re-fetch (o se reinicie la app). No es una regresion de esta sesion (el
// codigo de estado de auth/perfil no se toco salvo el enum de notificaciones);
// es un bug latente preexistente. Requiere decidir donde va la invalidacion
// (auth no deberia importar profile -> probablemente en la capa de profile o
// via ref.listen del auth state). Cuando se corrija, quitar el `skip`.
void main() {
  test(
    'profileProvider queda con el user anterior tras logout + login de otra cuenta',
    skip: 'Bug latente documentado: profileProvider no se invalida en '
        'logout/login. Quitar skip al corregir.',
    () async {
      final userA = _mk('user-a', 'Alice A');
      final userB = _mk('user-b', 'Bob B');

      final profileRepo = MockProfileRepository();
      final calls = <int>[];
      when(() => profileRepo.getProfile()).thenAnswer((_) async {
        calls.add(calls.length);
        return calls.length == 1 ? userA : userB;
      });

      final authRepo = MockAuthRepository();
      when(() => authRepo.readRefreshToken()).thenAnswer((_) async => null);
      when(() => authRepo.saveRefreshToken(any())).thenAnswer((_) async {});
      when(() => authRepo.clearRefreshToken()).thenAnswer((_) async {});
      when(() => authRepo.signOutFromGoogle()).thenAnswer((_) async {});
      when(
        () => authRepo.login(
          email: any(named: 'email'),
          password: any(named: 'password'),
        ),
      ).thenAnswer(
        (_) async => AuthTokens(
          accessToken: 'at-b',
          refreshToken: 'rt-b',
          user: userB,
        ),
      );

      final notifRepo = MockNotificationRepository();
      when(() => notifRepo.clearFcmToken()).thenAnswer((_) async {});

      final container = ProviderContainer(
        overrides: [
          profileRepositoryProvider.overrideWithValue(profileRepo),
          authRepositoryProvider.overrideWithValue(authRepo),
          notificationRepositoryProvider.overrideWithValue(notifRepo),
        ],
      );
      addTearDown(container.dispose);

      container.read(authControllerProvider.notifier);
      final first = await container.read(profileProvider.future);
      expect(first.fullName, 'Alice A');

      await container.read(authControllerProvider.notifier).logout();
      await container
          .read(authControllerProvider.notifier)
          .login(email: 'bob@email.com', password: 'x');

      final second = container.read(profileProvider).valueOrNull;
      expect(
        second?.fullName,
        'Bob B',
        reason:
            'profileProvider sigue cacheando al user A; nadie lo invalida en '
            'logout/login',
      );
    },
  );
}
