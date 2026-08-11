import 'package:freezed_annotation/freezed_annotation.dart';

part 'order_address_snapshot.freezed.dart';
part 'order_address_snapshot.g.dart';

/// Copia de la dirección de entrega AL MOMENTO del pedido.
///
/// El backend guarda `Order.addressSnapshot` como un JSON string crudo (ver
/// `resolveAddressSnapshot` en `orders.service.ts`) y lo devuelve tal cual —
/// no lo parsea. Este modelo decodifica ese string; ver
/// `Order.address` (`lib/features/orders/data/models/order.dart`).
@freezed
abstract class OrderAddressSnapshot with _$OrderAddressSnapshot {
  const factory OrderAddressSnapshot({
    required String alias,
    required String fullAddress,
    String? reference,
    required String district,
  }) = _OrderAddressSnapshot;

  factory OrderAddressSnapshot.fromJson(Map<String, dynamic> json) =>
      _$OrderAddressSnapshotFromJson(json);
}
