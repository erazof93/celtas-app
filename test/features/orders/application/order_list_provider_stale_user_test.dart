import 'package:celtas_mobile/features/auth/application/auth_providers.dart';
import 'package:celtas_mobile/features/auth/data/auth_repository.dart';
import 'package:celtas_mobile/features/auth/data/models/auth_tokens.dart';
import 'package:celtas_mobile/features/auth/data/models/user.dart';
import 'package:celtas_mobile/features/notifications/application/notification_providers.dart';
import 'package:celtas_mobile/features/notifications/data/notification_repository.dart';
import 'package:celtas_mobile/features/orders/application/order_history_providers.dart';
import 'package:celtas_mobile/features/orders/data/models/order.dart';
import 'package:celtas_mobile/features/orders/data/models/order_item.dart';
import 'package:celtas_mobile/features/orders/data/models/order_status.dart';
import 'package:celtas_mobile/features/orders/data/order_history_repository.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

class MockOrderHistoryRepository extends Mock implements OrderHistoryRepository {}

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

Order _order(String id) => Order(
      id: id,
      status: OrderStatus.pendiente,
      addressSnapshot: '{}',
      total: 10,
      whatsappUrl: 'https://wa.me/51999999999',
      items: const [
        OrderItem(
          id: 'item-1',
          menuItemId: 'menu-1',
          name: 'Item',
          unitPrice: 10,
          quantity: 1,
          subtotal: 10,
        ),
      ],
      createdAt: DateTime(2026, 8, 6),
    );

/// Mismo bug de clase que `profileProvider` (ver
/// `profile_stale_user_repro_test.dart`): `orderListProvider` es keep-alive
/// y nadie lo invalidaba en logout/login de otra cuenta. Corregido con el
/// mismo patrón (`ref.listen` del `id` del user autenticado dentro del propio
/// provider, ver doc en `order_history_providers.dart`).
void main() {
  test(
    'orderListProvider ya NO queda con los pedidos del user anterior tras '
    'logout + login de otra cuenta',
    () async {
      final ordersA = [_order('order-a1')];
      final ordersB = [_order('order-b1')];

      final orderRepo = MockOrderHistoryRepository();
      final calls = <int>[];
      when(() => orderRepo.getMyOrders()).thenAnswer((_) async {
        calls.add(calls.length);
        return calls.length == 1 ? ordersA : ordersB;
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
          orderHistoryRepositoryProvider.overrideWithValue(orderRepo),
          authRepositoryProvider.overrideWithValue(authRepo),
          notificationRepositoryProvider.overrideWithValue(notifRepo),
        ],
      );
      addTearDown(container.dispose);

      container.read(authControllerProvider.notifier);
      final first = await container.read(orderListProvider.future);
      expect(first.single.id, 'order-a1');

      await container.read(authControllerProvider.notifier).logout();
      await container
          .read(authControllerProvider.notifier)
          .login(email: 'bob@email.com', password: 'x');

      final second = await container.read(orderListProvider.future);
      expect(
        second.single.id,
        'order-b1',
        reason:
            'orderListProvider sigue cacheando los pedidos del user A; nadie '
            'lo invalida en logout/login',
      );
      expect(calls.length, 2);
    },
  );
}
