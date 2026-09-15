import 'package:celtas_mobile/core/network/api_client.dart';
import 'package:celtas_mobile/features/auth/application/auth_providers.dart';
import 'package:celtas_mobile/features/rewards/data/models/reward_catalog_item.dart';
import 'package:celtas_mobile/features/rewards/data/models/reward_progress.dart';
import 'package:celtas_mobile/features/rewards/data/reward_repository.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Repositorio de Estrellas contra el backend real.
final rewardRepositoryProvider = Provider<RewardRepository>(
  (ref) => RewardRepository(ApiClient.instance.dio),
);

/// Progreso del programa de Estrellas (`GET /rewards/progress`). Sin
/// `.autoDispose`, mismo criterio que `coupon_providers.dart` — y, por el
/// mismo motivo, se invalida solo cuando cambia el `id` del user autenticado
/// (logout o login de otra cuenta en el mismo dispositivo), sin invertir la
/// dependencia auth→rewards desde `AuthController.logout()` (ver doc de
/// `profileProvider`).
final rewardProgressProvider = FutureProvider<RewardProgress>((ref) {
  ref.listen(authControllerProvider.select((s) => s.user?.id), (_, _) {
    ref.invalidateSelf();
  });
  return ref.read(rewardRepositoryProvider).getProgress();
});

/// Catálogo de productos canjeables (`GET /rewards/catalog`). `.family` por
/// `especial`: `false` pide el catálogo normal, `true` el del premio
/// especial — dos providers/consultas independientes, nunca la misma lista.
final rewardCatalogProvider =
    FutureProvider.family<List<RewardCatalogItem>, bool>(
      (ref, especial) =>
          ref.read(rewardRepositoryProvider).getCatalog(especial: especial),
    );
