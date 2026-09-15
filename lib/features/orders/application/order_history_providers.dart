import 'package:celtas_mobile/core/network/api_client.dart';
import 'package:celtas_mobile/features/auth/application/auth_providers.dart';
import 'package:celtas_mobile/features/orders/data/models/order.dart';
import 'package:celtas_mobile/features/orders/data/order_history_repository.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Repositorio del historial de pedidos.
final orderHistoryRepositoryProvider = Provider<OrderHistoryRepository>(
  (ref) => OrderHistoryRepository(ApiClient.instance.dio),
);

/// Pedidos del usuario autenticado (`GET /orders/me`).
///
/// `FutureProvider` simple: a diferencia de direcciones, este módulo no
/// muta pedidos desde la app (no hay edición/borrado de un pedido propio),
/// así que no necesita un `AsyncNotifier` con métodos propios — el checkout
/// invalida este provider tras confirmar un pedido nuevo.
///
/// Keep-alive (sin autoDispose): se invalida solo cuando cambia el `id` del
/// user autenticado (logout o login de otra cuenta en el mismo dispositivo)
/// — mismo patrón y mismo motivo que `profileProvider` (ver su doc), para no
/// invertir la dependencia auth→orders desde `AuthController.logout()`.
final orderListProvider = FutureProvider<List<Order>>((ref) {
  ref.listen(authControllerProvider.select((s) => s.user?.id), (_, _) {
    ref.invalidateSelf();
  });
  return ref.read(orderHistoryRepositoryProvider).getMyOrders();
});

/// Detalle de un pedido puntual (`GET /orders/:id`).
final orderDetailProvider = FutureProvider.family<Order, String>(
  (ref, id) => ref.read(orderHistoryRepositoryProvider).getOrder(id),
);
