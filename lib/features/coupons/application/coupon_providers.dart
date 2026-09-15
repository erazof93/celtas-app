import 'package:celtas_mobile/core/network/api_client.dart';
import 'package:celtas_mobile/features/auth/application/auth_providers.dart';
import 'package:celtas_mobile/features/coupons/data/coupon_repository.dart';
import 'package:celtas_mobile/features/coupons/data/models/user_coupon.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Repositorio de cupones contra el backend real.
final couponRepositoryProvider = Provider<CouponRepository>(
  (ref) => CouponRepository(ApiClient.instance.dio),
);

/// Cupones del usuario autenticado (`GET /coupons/me`). Solo lectura, igual
/// que el historial de pedidos: sin `AsyncNotifier` propio, nada en este
/// módulo muta un cupón desde la app.
///
/// Keep-alive (sin autoDispose): se invalida solo cuando cambia el `id` del
/// user autenticado (logout o login de otra cuenta en el mismo dispositivo)
/// — mismo patrón y mismo motivo que `profileProvider` (ver su doc), para no
/// invertir la dependencia auth→coupons desde `AuthController.logout()`.
final userCouponListProvider = FutureProvider<List<UserCoupon>>((ref) {
  ref.listen(authControllerProvider.select((s) => s.user?.id), (_, _) {
    ref.invalidateSelf();
  });
  return ref.read(couponRepositoryProvider).getMyCoupons();
});