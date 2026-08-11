import 'package:celtas_mobile/core/network/api_client.dart';
import 'package:celtas_mobile/features/checkout/data/order_repository.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Repositorio de pedidos contra el backend real.
final orderRepositoryProvider = Provider<OrderRepository>(
  (ref) => OrderRepository(ApiClient.instance.dio),
);
