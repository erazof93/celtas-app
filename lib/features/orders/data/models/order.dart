import 'dart:convert';

import 'package:celtas_mobile/features/orders/data/models/order_address_snapshot.dart';
import 'package:celtas_mobile/features/orders/data/models/order_item.dart';
import 'package:celtas_mobile/features/orders/data/models/order_status.dart';
import 'package:freezed_annotation/freezed_annotation.dart';

part 'order.freezed.dart';
part 'order.g.dart';

/// Pedido (contrato real: `Order` en
/// `celtas-backend/src/modules/orders/entities/order.entity.ts`).
///
/// Fuente de `GET /orders/me` (lista, sin paginar — el backend no pagina ni
/// filtra ese endpoint para el cliente, solo el `GET /orders` de admin) y
/// `GET /orders/:id` (detalle, mismo shape con `items`).
@freezed
abstract class Order with _$Order {
  const factory Order({
    required String id,
    required OrderStatus status,
    required String addressSnapshot,
    required double total,
    required String whatsappUrl,
    DateTime? deliveredAt,
    required List<OrderItem> items,
    required DateTime createdAt,
  }) = _Order;

  const Order._();

  factory Order.fromJson(Map<String, dynamic> json) => _$OrderFromJson(json);

  /// Dirección de entrega decodificada del JSON string crudo que devuelve el
  /// backend en `addressSnapshot`.
  OrderAddressSnapshot get address => OrderAddressSnapshot.fromJson(
        jsonDecode(addressSnapshot) as Map<String, dynamic>,
      );

  int get itemsCount =>
      items.fold(0, (sum, item) => sum + item.quantity);

  /// Id corto para mostrar en UI (primeros 8 caracteres del UUID en
  /// mayúsculas) — mismo criterio que ya usa `celtas-admin` en
  /// `OrdersPage.tsx`/`OrderDetailDialog.tsx` (`order.id.slice(0, 8)`).
  String get shortId => id.substring(0, 8).toUpperCase();
}
