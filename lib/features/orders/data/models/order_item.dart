import 'package:freezed_annotation/freezed_annotation.dart';

part 'order_item.freezed.dart';
part 'order_item.g.dart';

/// Ítem de un pedido (contrato real: `OrderItem` en
/// `celtas-backend/src/modules/orders/entities/order-item.entity.ts`).
///
/// `name` y `unitPrice` son el SNAPSHOT copiado al crear el pedido, no el
/// producto actual del menú — si el producto cambió de precio o se borró
/// después, este ítem sigue mostrando lo que el cliente realmente pagó.
@freezed
abstract class OrderItem with _$OrderItem {
  const factory OrderItem({
    required String id,
    String? menuItemId,
    required String name,
    required double unitPrice,
    required int quantity,
    required double subtotal,
  }) = _OrderItem;

  factory OrderItem.fromJson(Map<String, dynamic> json) =>
      _$OrderItemFromJson(json);
}
