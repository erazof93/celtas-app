import 'package:celtas_mobile/core/network/api_client.dart';
import 'package:celtas_mobile/features/rewards/data/models/reward_catalog_item.dart';
import 'package:celtas_mobile/features/rewards/data/models/reward_progress.dart';
import 'package:dio/dio.dart';

/// Repositorio del programa de "Estrellas" contra el backend real.
///
/// Endpoints (contrato verificado contra `backend-celtas/src/modules/
/// rewards/rewards.controller.ts` + `rewards.service.ts`):
///   - `GET /rewards/progress` (JWT) → progreso hacia el próximo premio,
///     premios disponibles sin usar/sin vencer, y la promoción de estrellas
///     dobles vigente hoy si hay alguna.
///   - `GET /rewards/catalog` (JWT) → sin `especial` (o `false`): productos
///     `redeemableWithStars: true`; con `especial=true`: productos
///     `specialReward: true` — dos listas EXCLUYENTES, nunca una unión.
///     Ambas ya filtradas por `available: true`, mismo criterio que el menú
///     público.
class RewardRepository {
  RewardRepository(this._dio);

  final Dio _dio;

  Future<RewardProgress> getProgress() async {
    try {
      final response = await _dio.get<Map<String, dynamic>>(
        '/rewards/progress',
      );
      return RewardProgress.fromJson(response.data ?? const {});
    } on DioException catch (e) {
      throw apiExceptionFromDio(e);
    }
  }

  /// `especial`: el controller compara `especial === 'true'` como string, no
  /// como bool — se manda `'true'` explícito y se omite el parámetro cuando
  /// es `false` (equivalente a mandar `'false'`, pero más limpio).
  Future<List<RewardCatalogItem>> getCatalog({bool especial = false}) async {
    try {
      final response = await _dio.get<List<dynamic>>(
        '/rewards/catalog',
        queryParameters: especial ? {'especial': 'true'} : null,
      );
      return (response.data ?? const [])
          .cast<Map<String, dynamic>>()
          .map(RewardCatalogItem.fromJson)
          .toList();
    } on DioException catch (e) {
      throw apiExceptionFromDio(e);
    }
  }
}
