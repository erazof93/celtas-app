import 'package:celtas_mobile/core/network/api_client.dart';
import 'package:celtas_mobile/features/orders/data/models/order.dart';
import 'package:dio/dio.dart';

/// Repositorio del historial de pedidos contra el backend real.
///
/// Endpoints (contrato verificado contra `celtas-backend/src/modules/orders/
/// orders.controller.ts` + `orders.service.ts`):
///   - `GET /orders/me` → lista COMPLETA de los pedidos del usuario, más
///     recientes primero (`createdAt DESC`). NO está paginado ni acepta
///     filtro por `status`: esos parámetros solo existen en `GET /orders`
///     (sin `/me`), que requiere rol admin y no está disponible para el
///     cliente. No hay widget de paginación en este módulo por eso.
///   - `GET /orders/:id` → detalle de un pedido propio (403 si es de otro
///     usuario, 404 si no existe).
class OrderHistoryRepository {
  OrderHistoryRepository(this._dio);

  final Dio _dio;

  Future<List<Order>> getMyOrders() async {
    try {
      final response = await _dio.get<List<dynamic>>('/orders/me');
      return (response.data ?? const [])
          .cast<Map<String, dynamic>>()
          .map(Order.fromJson)
          .toList();
    } on DioException catch (e) {
      throw apiExceptionFromDio(e);
    }
  }

  Future<Order> getOrder(String id) async {
    try {
      final response = await _dio.get<Map<String, dynamic>>('/orders/$id');
      return Order.fromJson(response.data ?? const {});
    } on DioException catch (e) {
      throw apiExceptionFromDio(e);
    }
  }
}
