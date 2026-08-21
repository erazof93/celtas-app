import 'dart:convert';

import 'package:celtas_mobile/core/network/api_client.dart';
import 'package:celtas_mobile/features/cart/data/models/cart_item.dart';
import 'package:celtas_mobile/features/checkout/data/models/order_result.dart';
import 'package:dio/dio.dart';

/// Snapshot de dirección para un pedido sin dirección guardada (el usuario
/// llena el formulario inline del checkout en vez de elegir una existente).
class AddressSnapshotInput {
  const AddressSnapshotInput({
    required this.alias,
    required this.fullAddress,
    this.reference,
    required this.district,
  });

  final String alias;
  final String fullAddress;
  final String? reference;
  final String district;

  /// El DTO del backend (`CreateOrderDto.addressSnapshot`) espera un JSON
  /// string, no un objeto — igual al shape que ya arma `resolveAddressSnapshot`
  /// en el backend a partir de una `Address` guardada.
  String toJsonString() => jsonEncode({
        'alias': alias,
        'fullAddress': fullAddress,
        'reference': reference,
        'district': district,
      });
}

/// Repositorio de pedidos contra el backend real.
///
/// `POST /orders` (contrato verificado contra `celtas-backend/src/modules/
/// orders/dto/create-order.dto.ts` + `orders.service.ts`):
///   - `items`: `[{ menuItemId, quantity, sauceIds?, comment? }]`,
///     obligatorio, al menos 1. `sauceIds` es tri-state real
///     (`resolveSelectedSauces` en el backend distingue los tres casos, no
///     colapsa `undefined` y `[]`): la llave se OMITE por completo si el
///     ítem no tiene catálogo de salsas o el cliente nunca eligió
///     (`CartItem.selectedSauces` vacío y `explicitlyNoSauces == false`) →
///     el backend guarda `selectedSauces: null` ("no aplica"); se manda
///     `sauceIds: []` EXPLÍCITO si el cliente tocó "Sin salsas" a propósito
///     (`explicitlyNoSauces == true`) → el backend guarda
///     `selectedSauces: []` y esto se muestra literal como "Sin salsas" en
///     WhatsApp/admin; con salsas elegidas, se mandan sus ids. El backend
///     valida cada id contra las salsas que ese producto realmente ofrece y
///     guarda los NOMBRES como snapshot en `OrderItem.selectedSauces` — el
///     pedido no se ve afectado si la salsa se borra del catálogo después.
///     `comment` (texto libre, opcional, `MaxLength(140)` en el backend) se
///     manda SOLO si queda contenido real después de `trim()` — mismo
///     criterio que `sauceIds`/`addressSnapshot`/`couponCode`: nunca se
///     manda una llave irrelevante. El backend también trimea y trata
///     vacío/solo-espacios como ausente (`resolveComment`), así que este
///     `trim()` del lado del cliente es una garantía extra, no la única.
///   - `addressId` O `addressSnapshot` (JSON string) — nunca ambos, nunca
///     ninguno (el backend responde 400).
///   - `couponCode` opcional: se valida y canjea en la MISMA transacción del
///     pedido; si ya no es válido (usado/expirado entre la vista previa del
///     carrito y la confirmación), el pedido no se crea y el 400 trae el
///     mensaje real.
///   - El total NUNCA lo envía el cliente: lo calcula el backend a partir de
///     `items`.
class OrderRepository {
  OrderRepository(this._dio);

  final Dio _dio;

  Future<OrderResult> createOrder({
    required List<CartItem> items,
    String? addressId,
    AddressSnapshotInput? addressSnapshot,
    String? couponCode,
  }) async {
    assert(
      (addressId == null) != (addressSnapshot == null),
      'Debe venir addressId O addressSnapshot, nunca ambos ni ninguno',
    );
    try {
      final response = await _dio.post<Map<String, dynamic>>(
        '/orders',
        data: {
          'items': [
            for (final item in items)
              {
                'menuItemId': item.menuItemId,
                'quantity': item.quantity,
                if (item.selectedSauces.isNotEmpty)
                  'sauceIds': [
                    for (final sauce in item.selectedSauces) sauce.id,
                  ]
                else if (item.explicitlyNoSauces)
                  'sauceIds': const <String>[],
                if (item.comment != null && item.comment!.trim().isNotEmpty)
                  'comment': item.comment!.trim(),
              },
          ],
          'addressId': ?addressId,
          if (addressSnapshot != null)
            'addressSnapshot': addressSnapshot.toJsonString(),
          if (couponCode != null && couponCode.isNotEmpty)
            'couponCode': couponCode,
        },
      );
      return OrderResult.fromJson(response.data ?? const {});
    } on DioException catch (e) {
      throw apiExceptionFromDio(e);
    }
  }

  /// `POST /orders/estimate-delivery-fee` — solo de lectura, nunca crea un
  /// pedido. Contrato ya confirmado: body `{ addressId }`, response
  /// `{ deliveryFee, isFarOrder, distanceMeters }`. Esta capa usa
  /// EXCLUSIVAMENTE `deliveryFee` — el cliente nunca debe enterarse de
  /// `isFarOrder`/`distanceMeters` (decisión de producto: no desalentar
  /// pedidos que el negocio en la práctica sí puede cubrir), así que ni
  /// siquiera se parsean.
  Future<double> estimateDeliveryFee(String addressId) async {
    try {
      final response = await _dio.post<Map<String, dynamic>>(
        '/orders/estimate-delivery-fee',
        data: {'addressId': addressId},
      );
      final data = response.data ?? const {};
      return (data['deliveryFee'] as num).toDouble();
    } on DioException catch (e) {
      throw apiExceptionFromDio(e);
    }
  }
}
