import 'package:celtas_mobile/features/auth/application/auth_providers.dart';
import 'package:celtas_mobile/features/auth/data/auth_repository.dart';
import 'package:celtas_mobile/features/auth/data/models/auth_tokens.dart';
import 'package:celtas_mobile/features/auth/data/models/user.dart';
import 'package:celtas_mobile/features/coupons/application/coupon_providers.dart';
import 'package:celtas_mobile/features/coupons/data/coupon_repository.dart';
import 'package:celtas_mobile/features/coupons/data/models/coupon_status.dart';
import 'package:celtas_mobile/features/coupons/data/models/user_coupon.dart';
import 'package:celtas_mobile/features/coupons/data/models/validated_coupon.dart'
    show CouponDiscountType;
import 'package:celtas_mobile/features/notifications/application/notification_providers.dart';
import 'package:celtas_mobile/features/notifications/data/notification_repository.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

class MockCouponRepository extends Mock implements CouponRepository {}

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

UserCoupon _coupon(String id, String code) => UserCoupon(
      id: id,
      code: code,
      discountType: CouponDiscountType.percentage,
      discountValue: 10,
      status: CouponStatus.active,
      expiresAt: DateTime(2026, 12, 31),
    );

/// Mismo bug de clase que `profileProvider` (ver
/// `profile_stale_user_repro_test.dart`): `userCouponListProvider` es
/// keep-alive y nadie lo invalidaba en logout/login de otra cuenta.
/// Corregido con el mismo patrón (`ref.listen` del `id` del user autenticado
/// dentro del propio provider, ver doc en `coupon_providers.dart`).
void main() {
  test(
    'userCouponListProvider ya NO queda con los cupones del user anterior '
    'tras logout + login de otra cuenta',
    () async {
      final couponsA = [_coupon('c-a1', 'VIKINGOA')];
      final couponsB = [_coupon('c-b1', 'VIKINGOB')];

      final couponRepo = MockCouponRepository();
      final calls = <int>[];
      when(() => couponRepo.getMyCoupons()).thenAnswer((_) async {
        calls.add(calls.length);
        return calls.length == 1 ? couponsA : couponsB;
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
          couponRepositoryProvider.overrideWithValue(couponRepo),
          authRepositoryProvider.overrideWithValue(authRepo),
          notificationRepositoryProvider.overrideWithValue(notifRepo),
        ],
      );
      addTearDown(container.dispose);

      container.read(authControllerProvider.notifier);
      final first = await container.read(userCouponListProvider.future);
      expect(first.single.code, 'VIKINGOA');

      await container.read(authControllerProvider.notifier).logout();
      await container
          .read(authControllerProvider.notifier)
          .login(email: 'bob@email.com', password: 'x');

      final second = await container.read(userCouponListProvider.future);
      expect(
        second.single.code,
        'VIKINGOB',
        reason:
            'userCouponListProvider sigue cacheando los cupones del user A; '
            'nadie lo invalida en logout/login',
      );
      expect(calls.length, 2);
    },
  );
}
