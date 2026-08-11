import 'package:freezed_annotation/freezed_annotation.dart';

/// Estado del pedido (contrato real: `OrderStatus` en
/// `celtas-backend/src/modules/orders/entities/order.entity.ts`).
///
/// Transiciones válidas (las aplica el backend, la app solo lee el estado):
/// `pendiente` → `confirmado` → `en_camino` → `entregado`; `cancelado` solo
/// desde `pendiente`/`confirmado`.
enum OrderStatus {
  @JsonValue('pendiente')
  pendiente,

  @JsonValue('confirmado')
  confirmado,

  @JsonValue('en_camino')
  enCamino,

  @JsonValue('entregado')
  entregado,

  @JsonValue('cancelado')
  cancelado,
}
