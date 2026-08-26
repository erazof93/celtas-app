import 'package:freezed_annotation/freezed_annotation.dart';

part 'reward_catalog_item.freezed.dart';
part 'reward_catalog_item.g.dart';

/// Producto canjeable con estrellas, tal como lo devuelve
/// `GET /rewards/catalog` (contrato verificado contra
/// `RewardsService.getCatalog`, `backend-celtas/src/modules/rewards/
/// rewards.service.ts`).
///
/// `id` acá es el `MenuItem.id` real (NO un id de premio/`RewardRedemption`)
/// — es el producto que el cliente elige canjear, distinto del `id` de
/// `RewardSlot` (que identifica el premio ganado, ver `reward_progress.dart`).
/// `description`/`image` pueden ser `null`, mismo criterio que
/// `PublicMenuItem`.
@freezed
abstract class RewardCatalogItem with _$RewardCatalogItem {
  const factory RewardCatalogItem({
    required String id,
    required String name,
    String? description,
    required double price,
    String? image,
  }) = _RewardCatalogItem;

  factory RewardCatalogItem.fromJson(Map<String, dynamic> json) =>
      _$RewardCatalogItemFromJson(json);
}
