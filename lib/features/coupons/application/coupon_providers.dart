import 'package:celtas_mobile/core/network/api_client.dart';
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
final userCouponListProvider = FutureProvider<List<UserCoupon>>(
  (ref) => ref.read(couponRepositoryProvider).getMyCoupons(),
);