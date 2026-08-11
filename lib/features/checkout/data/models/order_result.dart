import 'package:freezed_annotation/freezed_annotation.dart';

part 'order_result.freezed.dart';
part 'order_result.g.dart';

/// Respuesta de `POST /orders` (contrato verificado contra
/// `celtas-backend/src/modules/orders/entities/order.entity.ts`).
///
/// El backend devuelve el pedido completo (items, addressSnapshot, status,
/// etc.) pero el checkout solo necesita `id` (para el mensaje de éxito) y
/// `whatsappUrl` (para abrir con `url_launcher`) — el resto queda para el
/// módulo 7 (historial de pedidos), que sí modela el pedido completo.
@freezed
abstract class OrderResult with _$OrderResult {
  const factory OrderResult({
    required String id,
    required double total,
    required String whatsappUrl,
  }) = _OrderResult;

  factory OrderResult.fromJson(Map<String, dynamic> json) =>
      _$OrderResultFromJson(json);
}
