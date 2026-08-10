import 'package:celtas_mobile/core/network/api_client.dart';
import 'package:celtas_mobile/features/home/data/models/banner.dart';
import 'package:celtas_mobile/features/home/data/models/public_menu_category.dart';
import 'package:dio/dio.dart';

/// Repositorio del Home contra el backend real.
///
/// Endpoints (contrato verificado contra `celtas-backend/src/modules/banners/
/// banners.controller.ts` y `menu/menu.service.ts`):
///   - `GET /banners/active` → `{ success, data: Banner[] }` (público, ya
///     filtrado por `active` + rango de fechas, ordenado por `order`).
///   - `GET /menu` → `{ success, data: PublicMenuCategory[] }` (público, solo
///     categorías activas con productos disponibles).
///
/// Ambos son públicos: no requieren sesión ni token.
class HomeRepository {
  HomeRepository(this._dio);

  final Dio _dio;

  /// Banners vigentes para el carrusel del Home.
  Future<List<Banner>> getActiveBanners() async {
    try {
      final response = await _dio.get<List<dynamic>>('/banners/active');
      return (response.data ?? const [])
          .map((json) => Banner.fromJson(json as Map<String, dynamic>))
          .toList();
    } on DioException catch (e) {
      throw apiExceptionFromDio(e);
    }
  }

  /// Menú público: categorías activas con sus productos disponibles.
  Future<List<PublicMenuCategory>> getMenu() async {
    try {
      final response = await _dio.get<List<dynamic>>('/menu');
      return (response.data ?? const [])
          .map((json) => PublicMenuCategory.fromJson(json as Map<String, dynamic>))
          .toList();
    } on DioException catch (e) {
      throw apiExceptionFromDio(e);
    }
  }
}