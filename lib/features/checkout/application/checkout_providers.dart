import 'package:celtas_mobile/core/network/api_client.dart';
import 'package:celtas_mobile/features/checkout/data/models/delivery_estimate.dart';
import 'package:celtas_mobile/features/checkout/data/order_repository.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Repositorio de pedidos contra el backend real.
final orderRepositoryProvider = Provider<OrderRepository>(
  (ref) => OrderRepository(ApiClient.instance.dio),
);

/// Preview por addressId. Conserva loading y errores; no se persiste.
/// Solo una AsyncData covered habilita confirmar en checkout.
final deliveryFeeEstimateProvider = FutureProvider.autoDispose
    .family<DeliveryEstimate, String>((ref, addressId) {
      return ref.watch(orderRepositoryProvider).estimateDeliveryFee(addressId);
    });
