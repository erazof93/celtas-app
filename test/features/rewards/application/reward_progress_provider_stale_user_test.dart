import 'package:celtas_mobile/features/auth/application/auth_providers.dart';
import 'package:celtas_mobile/features/auth/data/auth_repository.dart';
import 'package:celtas_mobile/features/auth/data/models/auth_tokens.dart';
import 'package:celtas_mobile/features/auth/data/models/user.dart';
import 'package:celtas_mobile/features/notifications/application/notification_providers.dart';
import 'package:celtas_mobile/features/notifications/data/notification_repository.dart';
import 'package:celtas_mobile/features/rewards/application/reward_providers.dart';
import 'package:celtas_mobile/features/rewards/data/models/reward_progress.dart';
import 'package:celtas_mobile/features/rewards/data/reward_repository.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

class MockRewardRepository extends Mock implements RewardRepository {}

class MockAuthRepository extends Mock implements AuthRepository {}

class MockNotificationRepository extends Mock implements NotificationRepository {}

User _mk(String id) => User(
      id: id,
      email: '$id@email.com',
      fullName: id,
      provider: UserProvider.local,
      phone: '+51 1',
      totalSpent: 0,
      role: UserRole.cliente,
      createdAt: DateTime.utc(2026),
      updatedAt: DateTime.utc(2026),
    );

/// Mismo bug de clase que `profileProvider` (ver
/// `profile_stale_user_repro_test.dart`): `rewardProgressProvider` es
/// keep-alive y nadie lo invalidaba en logout/login de otra cuenta.
/// Corregido con el mismo patrón (`ref.listen` del `id` del user autenticado
/// dentro del propio provider, ver doc en `reward_providers.dart`).
void main() {
  test(
    'rewardProgressProvider ya NO queda con el progreso del user anterior '
    'tras logout + login de otra cuenta',
    () async {
      final rewardRepo = MockRewardRepository();
      final calls = <int>[];
      when(() => rewardRepo.getProgress()).thenAnswer((_) async {
        calls.add(calls.length);
        return RewardProgress(
          estrellasDelMes: calls.length == 1 ? 3 : 7,
          hitos: const [],
          premiosDisponibles: const [],
        );
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
          user: _mk('user-b'),
        ),
      );

      final notifRepo = MockNotificationRepository();
      when(() => notifRepo.clearFcmToken()).thenAnswer((_) async {});

      final container = ProviderContainer(
        overrides: [
          rewardRepositoryProvider.overrideWithValue(rewardRepo),
          authRepositoryProvider.overrideWithValue(authRepo),
          notificationRepositoryProvider.overrideWithValue(notifRepo),
        ],
      );
      addTearDown(container.dispose);

      container.read(authControllerProvider.notifier);
      final first = await container.read(rewardProgressProvider.future);
      expect(first.estrellasDelMes, 3);

      await container.read(authControllerProvider.notifier).logout();
      await container
          .read(authControllerProvider.notifier)
          .login(email: 'bob@email.com', password: 'x');

      final second = await container.read(rewardProgressProvider.future);
      expect(
        second.estrellasDelMes,
        7,
        reason:
            'rewardProgressProvider sigue cacheando el progreso del user A; '
            'nadie lo invalida en logout/login',
      );
      expect(calls.length, 2);
    },
  );
}
