import 'package:celtas_mobile/features/auth/application/auth_providers.dart';
import 'package:celtas_mobile/features/auth/data/auth_repository.dart';
import 'package:celtas_mobile/features/auth/data/models/auth_tokens.dart';
import 'package:celtas_mobile/features/auth/data/models/user.dart';
import 'package:celtas_mobile/features/notifications/application/notification_providers.dart';
import 'package:celtas_mobile/features/notifications/data/notification_repository.dart';
import 'package:celtas_mobile/features/profile/application/profile_providers.dart';
import 'package:celtas_mobile/features/profile/data/profile_repository.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

class MockProfileRepository extends Mock implements ProfileRepository {}

class MockAuthRepository extends Mock implements AuthRepository {}

class MockNotificationRepository extends Mock
    implements NotificationRepository {}

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

// CORREGIDO (sesion de mantenimiento posterior a 2026-09-02): `profileProvider`
// es un `AsyncNotifierProvider` keep-alive (no autoDispose); ahora se invalida
// solo (`ref.listen(authControllerProvider.select((s) => s.user?.id), ...)`
// dentro de su propio `build()`, ver doc en `profile_providers.dart`) cada vez
// que cambia el `id` del user autenticado — cubre tanto logout como login de
// otra cuenta sin reiniciar la app. Se eligio esta capa (no
// `AuthController.logout()`) para no invertir la dependencia auth->profile.
void main() {
  setUpAll(
    () => dotenv.loadFromString(
      envString: 'API_BASE_URL=https://example.invalid',
    ),
  );
  test(
    'profileProvider ya NO queda con el user anterior tras logout + login de '
    'otra cuenta',
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
      when(
        () => authRepo.saveRefreshToken(
          any(),
          isCurrent: any(named: 'isCurrent'),
        ),
      ).thenAnswer((_) async {});
      when(() => authRepo.clearRefreshToken()).thenAnswer((_) async {});
      when(() => authRepo.signOutFromGoogle()).thenAnswer((_) async {});
      when(
        () => authRepo.login(
          email: any(named: 'email'),
          password: any(named: 'password'),
        ),
      ).thenAnswer(
        (_) async =>
            AuthTokens(accessToken: 'at-b', refreshToken: 'rt-b', user: userB),
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

      // La invalidación (`ref.invalidateSelf()`) es lazy: recién dispara el
      // re-fetch cuando algo vuelve a leer el provider — igual que una
      // pantalla real que espera el nuevo valor vía `ref.watch`/`.future`,
      // no un peek síncrono inmediatamente después del login.
      final second = await container.read(profileProvider.future);
      expect(
        second.fullName,
        'Bob B',
        reason:
            'profileProvider sigue cacheando al user A; nadie lo invalida en '
            'logout/login',
      );
      expect(
        calls.length,
        2,
        reason: 'getProfile() debe re-consultarse tras el login de otra cuenta',
      );
    },
  );
}
