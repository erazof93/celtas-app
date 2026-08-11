import 'package:celtas_mobile/core/network/api_client.dart';
import 'package:celtas_mobile/features/coupons/data/coupon_repository.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Repositorio de cupones contra el backend real.
final couponRepositoryProvider = Provider<CouponRepository>(
  (ref) => CouponRepository(ApiClient.instance.dio),
);