import 'package:celtas_mobile/core/network/api_client.dart';
import 'package:celtas_mobile/features/checkout/data/order_repository.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Repositorio de pedidos contra el backend real.
final orderRepositoryProvider = Provider<OrderRepository>(
  (ref) => OrderRepository(ApiClient.instance.dio),
);

/// Preview del costo de envío (`POST /orders/estimate-delivery-fee`) para la
/// dirección seleccionada en el checkout. Puramente informativo — best-effort
/// como `businessHoursProvider`: cualquier error se traga acá (devuelve
/// `null`) para que la UI simplemente no muestre la fila de envío en vez de
/// bloquear el checkout o mostrar un error feo. `autoDispose` porque está
/// keyeado por `addressId`: sin esto, cada dirección que el usuario prueba
/// durante la sesión quedaría cacheada para siempre.
final deliveryFeeEstimateProvider =
    FutureProvider.autoDispose.family<double?, String>((ref, addressId) async {
  try {
    return await ref.read(orderRepositoryProvider).estimateDeliveryFee(
          addressId,
        );
  } catch (_) {
    return null;
  }
});
